//
//  VoiceCatalog.swift
//  TTS
//
//  Created by Doniel Tripura on 10/20/25.
//

import Foundation
import AVFoundation
import Combine

struct RemoteVoiceDTO: Codable {
    let id: Int
    let name: String
    let type: String
    let language: String
    let gender: String
    let description: String?
    let rating: Int?
    let useCount: Int?
    let priority: Int?
    let sampleInputText: String?
    let audioUrl: String?
    let imageUrl: String?
    let updatedAt: String?
}

struct RemoteLanguageDTO: Codable, Hashable {
    let code: String
    let name: String
}

private struct CachedRemoteVoiceCatalog: Codable {
    let voices: [Voice]
    let languages: [RemoteLanguageDTO]
    let cachedAt: Date
}

private enum VoiceCatalogCacheStore {
    private static let fileName = "remote_voice_catalog.json"

    private static var fileURL: URL {
        let baseDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return baseDirectory.appendingPathComponent(fileName)
    }

    static func load() -> CachedRemoteVoiceCatalog? {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(CachedRemoteVoiceCatalog.self, from: data)
        } catch {
            return nil
        }
    }

    static func save(_ snapshot: CachedRemoteVoiceCatalog) {
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Logger.log("⚠️ Failed to cache remote voice catalog: \(error.localizedDescription)")
        }
    }
}

/// A shared singleton catalog managing all available voices, including backend and system voices.
final class VoiceCatalog: ObservableObject {
    static let shared = VoiceCatalog()

    @Published private(set) var voices: [Voice] = []
    @Published private(set) var languages: [String] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastErrorMessage: String?

    private var reloadTask: Task<Void, Never>?

    // MARK: - Asset Cache (images + audio preview)
    private let imageCache = NSCache<NSString, NSData>()
    private let audioCache = NSCache<NSString, NSData>()

    private lazy var cacheDirectoryURL: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("voice_assets", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private init() {
        let systemVoices = buildSystemVoices()
        if let cached = VoiceCatalogCacheStore.load() {
            applyCatalog(remoteVoices: cached.voices, remoteLanguages: cached.languages, systemVoices: systemVoices)
        } else {
            applyCatalog(remoteVoices: [], remoteLanguages: [], systemVoices: systemVoices)
        }
        reloadVoices()
    }

    /// Reloads the list of voices by combining backend custom voices and system voices while avoiding duplicates.
    func reloadVoices() {
        reloadTask?.cancel()
        reloadTask = Task { [weak self] in
            guard let self else { return }
            await self.refreshRemoteCatalog()
        }
    }

    private func refreshRemoteCatalog() async {
        await MainActor.run {
            isLoading = true
            lastErrorMessage = nil
        }

        let systemVoices = buildSystemVoices()

        do {
            async let voicesEnvelope: APIEnvelope<[RemoteVoiceDTO]> = APIClient.shared.send(APIEndpoints.fetchPublicVoices())
            async let languagesEnvelope: APIEnvelope<[RemoteLanguageDTO]> = APIClient.shared.send(APIEndpoints.fetchPublicLanguages())

            let remoteVoicesResponse = try await voicesEnvelope
            let remoteLanguagesResponse = try await languagesEnvelope

            let remoteLanguages = remoteLanguagesResponse.data
            let remoteVoices = mapRemoteVoices(remoteVoicesResponse.data, languages: remoteLanguages)

            VoiceCatalogCacheStore.save(
                CachedRemoteVoiceCatalog(
                    voices: remoteVoices,
                    languages: remoteLanguages,
                    cachedAt: Date()
                )
            )

            await MainActor.run {
                self.applyCatalog(remoteVoices: remoteVoices, remoteLanguages: remoteLanguages, systemVoices: systemVoices)
                self.isLoading = false
            }
            // Prefetch assets in background (images + audio previews for premium voices)
            Task.detached { [weak self] in
                guard let self else { return }
                await self.prefetchAssets(for: remoteVoices)
            }
        } catch {
            let message = error.localizedDescription
            Logger.log("⚠️ Remote voice catalog fetch failed: \(message)")
            await MainActor.run {
                self.applyCatalog(
                    remoteVoices: VoiceCatalogCacheStore.load()?.voices ?? [],
                    remoteLanguages: VoiceCatalogCacheStore.load()?.languages ?? [],
                    systemVoices: systemVoices
                )
                self.lastErrorMessage = message
                self.isLoading = false
            }
        }
    }

    @MainActor
    private func applyCatalog(remoteVoices: [Voice], remoteLanguages: [RemoteLanguageDTO], systemVoices: [Voice]) {
        let dedupedSystem = systemVoices.filter { systemVoice in
            !remoteVoices.contains(where: { $0.voiceSampleId == systemVoice.voiceSampleId })
        }

        let mergedVoices = sortVoices(remoteVoices + dedupedSystem)
        voices = mergedVoices

        let remoteLanguageNames = remoteLanguages.map(\.name)
        let allLanguageNames = Set(remoteLanguageNames)
            .union(mergedVoices.map(\.language))
        languages = Array(allLanguageNames).sorted()
    }

    private func sortVoices(_ voices: [Voice]) -> [Voice] {
        voices.sorted { lhs, rhs in
            if lhs.source != rhs.source {
                return lhs.source == .remote
            }
            if lhs.priority != rhs.priority {
                return (lhs.priority ?? Int.min) > (rhs.priority ?? Int.min)
            }
            if lhs.language != rhs.language {
                return lhs.language.localizedCaseInsensitiveCompare(rhs.language) == .orderedAscending
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func buildSystemVoices() -> [Voice] {
        AVSpeechSynthesisVoice.speechVoices().map { avVoice in
            Voice(
                name: avVoice.name,
                language: Locale.current.localizedString(forIdentifier: avVoice.language) ?? avVoice.language,
                accent: regionName(from: avVoice.language),
                type: VoiceType.Free.rawValue,
                voiceSampleId: avVoice.identifier,
                source: .system,
                languageCode: avVoice.language
            )
        }
    }

    private func mapRemoteVoices(_ remoteVoices: [RemoteVoiceDTO], languages: [RemoteLanguageDTO]) -> [Voice] {
        let languageCodeByName = Dictionary(uniqueKeysWithValues: languages.map {
            ($0.name.lowercased(), $0.code)
        })

        return remoteVoices.map { remote in
            let normalizedLanguageCode = languageCodeByName[remote.language.lowercased()]
            return Voice(
                name: remote.name,
                language: remote.language,
                accent: "",
                mood: nil,
                type: VoiceType.Premium.rawValue,
                voiceSampleId: String(remote.id),
                source: .remote,
                languageCode: normalizedLanguageCode,
                genderHint: remote.gender,
                backendVoiceID: remote.id,
                backendCategory: remote.type,
                voiceDescription: remote.description,
                rating: remote.rating,
                useCount: remote.useCount,
                priority: remote.priority,
                sampleInputTextURL: URL(string: remote.sampleInputText ?? ""),
                audioPreviewURL: URL(string: remote.audioUrl ?? ""),
                imageURL: URL(string: remote.imageUrl ?? "")
            )
        }
    }

    // MARK: - Asset Prefetching
    private func prefetchAssets(for voices: [Voice]) async {
        await withTaskGroup(of: Void.self) { group in
            for voice in voices {
                // Prefetch image
                if let url = voice.imageURL {
                    group.addTask { [weak self] in
                        _ = await self?.fetchImageData(for: voice, url: url)
                    }
                }
                // Prefetch audio preview for premium voices only
                if voice.type == VoiceType.Premium.rawValue, let url = voice.audioPreviewURL {
                    group.addTask { [weak self] in
                        _ = await self?.fetchAudioData(for: voice, url: url)
                    }
                }
            }
        }
    }

    // MARK: - Public Accessors
    func imageData(for voice: Voice) async -> Data? {
        if let url = voice.imageURL {
            return await fetchImageData(for: voice, url: url)
        }
        return nil
    }

    func audioPreviewURLCached(for voice: Voice) async -> URL? {
        guard voice.type == VoiceType.Premium.rawValue, let url = voice.audioPreviewURL else { return nil }
        if let data = await fetchAudioData(for: voice, url: url) {
            return persistIfNeeded(data: data, fileName: cacheFileName(for: voice, ext: url.pathExtension))
        }
        return nil
    }

    // MARK: - Core Fetchers
    private func fetchImageData(for voice: Voice, url: URL) async -> Data? {
        let key = NSString(string: cacheKey(for: voice, suffix: "image"))
        if let cached = imageCache.object(forKey: key) { return Data(referencing: cached) }
        if let disk = loadFromDisk(fileName: cacheFileName(for: voice, ext: url.pathExtension.isEmpty ? "img" : url.pathExtension)) {
            imageCache.setObject(disk as NSData, forKey: key)
            return disk
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            imageCache.setObject(data as NSData, forKey: key)
            _ = persistIfNeeded(data: data, fileName: cacheFileName(for: voice, ext: url.pathExtension.isEmpty ? "img" : url.pathExtension))
            return data
        } catch {
            Logger.log("⚠️ Image prefetch failed for voice=\(voice.name): \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchAudioData(for voice: Voice, url: URL) async -> Data? {
        let key = NSString(string: cacheKey(for: voice, suffix: "audio"))
        if let cached = audioCache.object(forKey: key) { return Data(referencing: cached) }
        if let disk = loadFromDisk(fileName: cacheFileName(for: voice, ext: url.pathExtension.isEmpty ? "mp3" : url.pathExtension)) {
            audioCache.setObject(disk as NSData, forKey: key)
            return disk
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            audioCache.setObject(data as NSData, forKey: key)
            _ = persistIfNeeded(data: data, fileName: cacheFileName(for: voice, ext: url.pathExtension.isEmpty ? "mp3" : url.pathExtension))
            return data
        } catch {
            Logger.log("⚠️ Audio preview prefetch failed for voice=\(voice.name): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Disk Helpers
    private func cacheKey(for voice: Voice, suffix: String) -> String {
        return "\(voice.voiceSampleId)_\(suffix)"
    }

    private func cacheFileName(for voice: Voice, ext: String) -> String {
        let safeExt = ext.isEmpty ? "bin" : ext
        return "\(voice.voiceSampleId).\(safeExt)"
    }

    private func loadFromDisk(fileName: String) -> Data? {
        let url = cacheDirectoryURL.appendingPathComponent(fileName)
        return try? Data(contentsOf: url)
    }

    private func persistIfNeeded(data: Data, fileName: String) -> URL? {
        let url = cacheDirectoryURL.appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            Logger.log("⚠️ Failed to persist asset \(fileName): \(error.localizedDescription)")
            return nil
        }
    }

    private func regionName(from languageCode: String) -> String {
        let locale = Locale(identifier: languageCode)
        if let regionCode = locale.region?.identifier,
           let regionName = Locale.current.localizedString(forRegionCode: regionCode) {
            return regionName
        }
        return languageCode.components(separatedBy: "-").dropFirst().first ?? ""
    }

    // Normalize a BCP-47 code to its base language (e.g., "es-MX" -> "es")
    private func baseLanguageCode(from code: String) -> String {
        code.split(separator: "-").first.map(String.init) ?? code
    }

    /// Finds a voice that matches the given language code.
    func findVoiceForLanguage(_ languageCode: String, preferSystem: Bool = true) -> Voice? {
        let requestedCode = languageCode
        let requestedBase = baseLanguageCode(from: requestedCode)

        var matchingVoices = voices.filter { voice in
            guard let code = voice.languageCode else { return false }
            return code.caseInsensitiveCompare(requestedCode) == .orderedSame
        }

        if matchingVoices.isEmpty {
            matchingVoices = voices.filter { voice in
                guard let code = voice.languageCode else { return false }
                return baseLanguageCode(from: code).caseInsensitiveCompare(requestedBase) == .orderedSame
            }
        }

        if matchingVoices.isEmpty {
            guard let detectedLanguageName = LanguageDetection.mapLanguageCodeToName(requestedCode) else {
                Logger.log("⚠️ Could not map language code '\(requestedCode)' to language name")
                return nil
            }
            let baseDetectedName = LanguageDetection.extractBaseLanguageName(detectedLanguageName)

            matchingVoices = voices.filter { voice in
                if voice.language == detectedLanguageName { return true }
                let baseVoiceName = LanguageDetection.extractBaseLanguageName(voice.language)
                return baseVoiceName.localizedCaseInsensitiveCompare(baseDetectedName) == .orderedSame
            }

            if matchingVoices.isEmpty {
                Logger.log("⚠️ No voices found for language '\(detectedLanguageName)' (code: \(requestedCode), base: \(baseDetectedName))")
                return nil
            }
        }

        if preferSystem {
            if let systemVoice = matchingVoices.first(where: \.isSystemVoice) {
                Logger.log("✅ Found system voice '\(systemVoice.name)' for code '\(requestedCode)'")
                return systemVoice
            }
        }

        if let any = matchingVoices.first {
            Logger.log("✅ Found voice '\(any.name)' for code '\(requestedCode)'")
            return any
        }

        return nil
    }
}
