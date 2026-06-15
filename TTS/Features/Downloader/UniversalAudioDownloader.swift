//
//  UniversalAudioDownloader.swift
//  TTS
//
//  Created by Assistant on 11/23/25.
//

import Foundation
import AVFoundation
import Combine

public struct AudioFile: Identifiable, Codable {
    public let id: String
    let originalFileURL: URL
    let audioURL: URL
    let fileType: FileType
    let voiceMode: AppVoiceMode
    let voiceId: String
    let createdAt: Date
    let duration: TimeInterval
    let fileSize: Int64
    let title: String
}

enum DownloadState: Equatable {
    case notStarted
    case queued
    case downloading(progress: Double)
    case completed
    case failed(error: String)
    
    var progress: Double {
        switch self {
        case .downloading(let progress): return progress
        case .completed: return 1.0
        default: return 0.0
        }
    }
    
    var isActive: Bool {
        switch self {
        case .queued, .downloading: return true
        default: return false
        }
    }
}

struct FileContent {
    let url: URL
    let text: String
    let type: FileType
    let title: String
    
    var id: String {
        return "\(title)\n\(url.absoluteString)\n\(text)".hashValue.description
    }
}

struct DownloadRequest {
    let content: FileContent
    let voiceMode: AppVoiceMode
    let voiceId: String
}

@MainActor
final class UniversalAudioDownloader: ObservableObject {
    @Published var isDownloading: Bool = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadedFiles: [AudioFile] = []
    @Published var downloadQueue: [DownloadRequest] = []
    @Published var downloadStates: [String: DownloadState] = [:]
    @Published var errorMessage: String?
    
    private let maxConcurrentDownloads = 2
    private let maxCacheSize: Int64 = 500_000_000 // 500MB
    
    private var activeDownloads: [String: Task<Void, Never>] = [:]
    private let downloadDispatchQueue = DispatchQueue(label: "audio.download.queue", attributes: .concurrent)
    private let fileManager = FileManager.default
    private let chunkStore = BackendChunkStore.shared
    
    // Dependencies
    private let jobService = PublicTTSJobService()
    private let systemVoiceGenerator = SystemVoiceAudioGenerator()
    
    init() {
        loadDownloadedFiles()
    }
    
    // MARK: - Public Methods
    
    func downloadAudio(for content: FileContent, voiceMode: AppVoiceMode, voiceId: String) async {
        let downloadId = content.id
        
        guard downloadStates[downloadId]?.isActive != true else {
            Logger.log("⚠️ Download already in progress for \(content.title)")
            return
        }
        
        downloadStates[downloadId] = .queued
        let request = DownloadRequest(content: content, voiceMode: voiceMode, voiceId: voiceId)
        downloadQueue.append(request)
        
        await processDownloadQueue()
    }
    
    func cancelDownload(for contentId: String) {
        activeDownloads[contentId]?.cancel()
        activeDownloads.removeValue(forKey: contentId)
        downloadStates[contentId] = .notStarted
        downloadQueue.removeAll { $0.content.id == contentId }
    }
    
    func deleteAudioFile(_ audioFile: AudioFile) {
        do {
            try fileManager.removeItem(at: audioFile.audioURL)
            downloadedFiles.removeAll { $0.id == audioFile.id }
            downloadStates.removeValue(forKey: audioFile.id)
            saveDownloadedFiles()
            Logger.log("✅ Deleted audio file: \(audioFile.title)")
        } catch {
            Logger.log("❌ Failed to delete audio file: \(error.localizedDescription)")
        }
    }
    
    func cleanupOldCache() async {
        let sortedFiles = downloadedFiles.sorted { $0.createdAt < $1.createdAt }
        let totalSize = sortedFiles.reduce(0) { $0 + $1.fileSize }
        
        if totalSize > maxCacheSize {
            let excessSize = totalSize - maxCacheSize
            var deletedSize: Int64 = 0
            
            for file in sortedFiles {
                if deletedSize >= excessSize { break }
                deleteAudioFile(file)
                deletedSize += file.fileSize
            }
            
            Logger.log("🧹 Cleaned up \(deletedSize) bytes of cache")
        }
    }
    
    // MARK: - Private Methods
    
    private func processDownloadQueue() async {
        let activeCount = activeDownloads.count
        guard activeCount < maxConcurrentDownloads, let nextRequest = downloadQueue.first else {
            return
        }
        
        downloadQueue.removeFirst()
        
        let downloadTask = Task {
            await performDownload(for: nextRequest.content, voiceMode: nextRequest.voiceMode, voiceId: nextRequest.voiceId)
            activeDownloads.removeValue(forKey: nextRequest.content.id)
            
            // Process next item in queue
            await processDownloadQueue()
        }
        
        activeDownloads[nextRequest.content.id] = downloadTask
        updateDownloadingState()
    }
    
    private func performDownload(for content: FileContent, voiceMode: AppVoiceMode = .backend, voiceId: String = "1") async {
        let downloadId = content.id
        downloadStates[downloadId] = .downloading(progress: 0.0)
        
        do {
            let audioFile: AudioFile
            
            switch voiceMode {
            case .system:
                audioFile = try await downloadSystemVoiceAudio(for: content, voiceId: voiceId)
            case .backend:
                audioFile = try await downloadWithBackend(content: content, voiceId: voiceId)
            }
            
            downloadedFiles.append(audioFile)
            downloadStates[downloadId] = .completed
            saveDownloadedFiles()
            
            Logger.log("✅ Successfully downloaded \(voiceMode.rawValue) audio for \(content.title)")
            
        } catch {
            downloadStates[downloadId] = .failed(error: error.localizedDescription)
            Logger.log("❌ Failed to download audio for \(content.title): \(error)")
        }
        
        updateDownloadingState()
    }
    
    private func downloadWithBackend(content: FileContent, voiceId: String) async throws -> AudioFile {
        let voice = resolveBackendVoice(for: voiceId)
        var localChunkURLs: [URL] = []
        let seedRequestId = UUID().uuidString
        let initialUpload = try jobService.prepareInitialUpload(
            originalFileURL: content.url,
            fallbackText: content.text,
            requestId: seedRequestId,
            title: content.title
        )
        let initialUploadData = try await jobService.createUploadURL(
            UploadJobURLRequest(
                userId: nil,
                visitorId: "iOS Visitor",
                characterCount: content.text.count,
                voiceSampleId: voice.backendVoiceID ?? Int(voice.voiceSampleId) ?? 1,
                languageCode: resolvedLanguageCode(for: content.text, voice: voice),
                platform: "IOS",
                scanner: true,
                fileExtension: initialUpload.fileExtension
            )
        )
        try await jobService.uploadFile(fileURL: initialUpload.fileURL, to: initialUploadData.uploadUrl)
        _ = try await jobService.triggerSpeechGeneration(
            requestId: initialUploadData.requestId,
            userId: nil,
            visitorId: "iOS Visitor"
        )
        chunkStore.clearDocument(documentRequestId: initialUploadData.requestId)

        let initialStatus = try await jobService.waitForJobCompletion(
            requestId: initialUploadData.requestId,
            userId: nil,
            visitorId: "iOS Visitor"
        )

        guard let initialDownloadURL = initialStatus.downloadUrl,
              let firstRemoteURL = URL(string: initialDownloadURL),
              !initialDownloadURL.isEmpty else {
            throw DownloadError.downloadURLNotFound
        }
        let firstLocalURL = try await downloadChunkToLocal(remote: firstRemoteURL, contentId: content.id, order: 1)
        localChunkURLs.append(firstLocalURL)
        chunkStore.saveChunk(
            documentRequestId: initialUploadData.requestId,
            chunkIndex: 1,
            remoteAudioURL: initialDownloadURL,
            localAudioPath: firstLocalURL.path
        )
        downloadStates[content.id] = .downloading(progress: 0.25)

        let chunkTextURLs = initialStatus.chunkTextUrls ?? []

        for (index, sourceURL) in chunkTextURLs.enumerated() {
            let item = try await jobService.downloadChunkText(from: sourceURL, index: index)
            let order = item.index + 1
            chunkStore.saveChunk(
                documentRequestId: initialUploadData.requestId,
                chunkIndex: order,
                text: item.text,
                remoteTextURL: item.sourceURL
            )
            guard index > 0 else { continue }
            let uploadFileURL = try jobService.makeUploadFile(
                text: item.text,
                requestId: initialUploadData.requestId,
                chunkIndex: order,
                fileExtension: "txt"
            )
            let uploadData = try await jobService.createUploadURL(
                UploadJobURLRequest(
                    userId: nil,
                    visitorId: "iOS Visitor",
                    characterCount: item.text.count,
                    voiceSampleId: voice.backendVoiceID ?? Int(voice.voiceSampleId) ?? 1,
                    languageCode: resolvedLanguageCode(for: item.text, voice: voice),
                    platform: "IOS",
                    scanner: false,
                    fileExtension: "txt"
                )
            )
            try await jobService.uploadFile(fileURL: uploadFileURL, to: uploadData.uploadUrl)
            _ = try await jobService.triggerSpeechGeneration(
                requestId: uploadData.requestId,
                userId: nil,
                visitorId: "iOS Visitor"
            )
            let status = try await jobService.waitForJobCompletion(
                requestId: uploadData.requestId,
                userId: nil,
                visitorId: "iOS Visitor"
            )
            guard let remoteAudioURL = status.downloadUrl,
                  let remoteURL = URL(string: remoteAudioURL),
                  !remoteAudioURL.isEmpty else {
                throw DownloadError.downloadURLNotFound
            }
            let localURL = try await downloadChunkToLocal(remote: remoteURL, contentId: content.id, order: order)
            localChunkURLs.append(localURL)
            chunkStore.saveChunk(
                documentRequestId: initialUploadData.requestId,
                chunkIndex: order,
                remoteAudioURL: remoteAudioURL,
                localAudioPath: localURL.path
            )

            let progress = 0.25 + (0.70 * Double(order - 1) / Double(max(1, chunkTextURLs.count)))
            downloadStates[content.id] = .downloading(progress: min(progress, 0.95))
        }

        let finalAudioURL = try await mergeAudioFiles(localChunkURLs, contentId: content.id)
        
        // Get file properties
        let attributes = try fileManager.attributesOfItem(atPath: finalAudioURL.path)
        let fileSize = attributes[FileAttributeKey.size] as? Int64 ?? 0
        
        // Get duration if possible
        let duration = try? await getAudioDuration(url: finalAudioURL)
        
        downloadStates[content.id] = .downloading(progress: 1.0)
        
        return AudioFile(
            id: content.id,
            originalFileURL: content.url,
            audioURL: finalAudioURL,
            fileType: content.type,
            voiceMode: .backend,
            voiceId: voiceId,
            createdAt: Date(),
            duration: duration ?? 0.0,
            fileSize: fileSize,
            title: content.title
        )
    }
    
    func downloadSystemVoiceAudio(
        for content: FileContent,
        voiceId: String
    ) async throws -> AudioFile {
        let downloadId = content.id
        downloadStates[downloadId] = .downloading(progress: 0.0)
        
        do {
            // Create output URL
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioDirectory = documentsURL.appendingPathComponent("DownloadedAudio", isDirectory: true)
            
            // Create directory if needed
            if !fileManager.fileExists(atPath: audioDirectory.path) {
                try fileManager.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
            }
            
            let filename = "\(downloadId)_system.m4a"
            let outputURL = audioDirectory.appendingPathComponent(filename)
            
            downloadStates[downloadId] = .downloading(progress: 0.5)
            
            // Generate audio file
            let audioURL = try await systemVoiceGenerator.generateAudioFile(
                text: content.text,
                voiceId: voiceId,
                outputURL: outputURL
            )
            
            // Get file properties
            let attributes = try fileManager.attributesOfItem(atPath: audioURL.path)
            let fileSize = attributes[FileAttributeKey.size] as? Int64 ?? 0
            let duration = try? await getAudioDuration(url: audioURL)
            
            downloadStates[downloadId] = .downloading(progress: 1.0)
            
            return AudioFile(
                id: downloadId,
                originalFileURL: content.url,
                audioURL: audioURL,
                fileType: content.type,
                voiceMode: .system,
                voiceId: voiceId,
                createdAt: Date(),
                duration: duration ?? 0.0,
                fileSize: fileSize,
                title: content.title
            )
            
        } catch {
            downloadStates[downloadId] = .failed(error: error.localizedDescription)
            throw error
        }
    }
    
    private func downloadChunkToLocal(remote: URL, contentId: String, order: Int) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            downloadDispatchQueue.async {
                do {
                    let data = try Data(contentsOf: remote)
                    
                    let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let audioDirectory = documentsURL.appendingPathComponent("DownloadedAudio", isDirectory: true)
                    
                    // Create directory if needed
                    if !FileManager.default.fileExists(atPath: audioDirectory.path) {
                        try FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
                    }
                    
                    let filename = "\(contentId)_chunk_\(order).mp3"
                    let localURL = audioDirectory.appendingPathComponent(filename)
                    
                    try data.write(to: localURL)
                    
                    continuation.resume(returning: localURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func mergeAudioFiles(_ urls: [URL], contentId: String) async throws -> URL {
        guard let first = urls.first else {
            throw DownloadError.fileNotFound
        }

        if urls.count == 1 {
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioDirectory = documentsURL.appendingPathComponent("DownloadedAudio", isDirectory: true)
            if !fileManager.fileExists(atPath: audioDirectory.path) {
                try fileManager.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
            }
            let destinationURL = audioDirectory.appendingPathComponent("\(contentId).mp3")
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: first, to: destinationURL)
            return destinationURL
        }

        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw DownloadError.mergeFailed
        }

        var cursor = CMTime.zero
        for url in urls {
            let asset = AVURLAsset(url: url)
            let assetTracks = try await asset.loadTracks(withMediaType: .audio)
            guard let assetTrack = assetTracks.first else { continue }
            let duration = try await asset.load(.duration)
            let timeRange = CMTimeRange(start: .zero, duration: duration)
            try track.insertTimeRange(timeRange, of: assetTrack, at: cursor)
            cursor = cursor + timeRange.duration
        }

        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioDirectory = documentsURL.appendingPathComponent("DownloadedAudio", isDirectory: true)
        if !fileManager.fileExists(atPath: audioDirectory.path) {
            try fileManager.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
        }

        let outputURL = audioDirectory.appendingPathComponent("\(contentId).m4a")
        if fileManager.fileExists(atPath: outputURL.path) {
            try fileManager.removeItem(at: outputURL)
        }

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw DownloadError.mergeFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            exportSession.exportAsynchronously {
                if let error = exportSession.error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }

        return outputURL
    }
    
    private func getAudioDuration(url: URL) async throws -> TimeInterval {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    let audioPlayer = try AVAudioPlayer(contentsOf: url)
                    continuation.resume(returning: audioPlayer.duration)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func updateDownloadingState() {
        isDownloading = !activeDownloads.isEmpty
        
        if isDownloading {
            let totalProgress = downloadStates.values.reduce(0.0) { sum, state in
                sum + state.progress
            }
            downloadProgress = totalProgress / Double(max(1, downloadStates.count))
        } else {
            downloadProgress = 0.0
        }
    }
    
    // MARK: - Persistence
    
    private func saveDownloadedFiles() {
        do {
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let metadataURL = documentsURL.appendingPathComponent("downloaded_audio_metadata.json")
            
            let data = try JSONEncoder().encode(downloadedFiles)
            try data.write(to: metadataURL)
        } catch {
            Logger.log("❌ Failed to save downloaded files metadata: \(error)")
        }
    }
    
    private func loadDownloadedFiles() {
        do {
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let metadataURL = documentsURL.appendingPathComponent("downloaded_audio_metadata.json")
            
            guard fileManager.fileExists(atPath: metadataURL.path) else { return }
            
            let data = try Data(contentsOf: metadataURL)
            downloadedFiles = try JSONDecoder().decode([AudioFile].self, from: data)
            
            // Verify files still exist
            downloadedFiles = downloadedFiles.filter { file in
                fileManager.fileExists(atPath: file.audioURL.path)
            }
            
            // Save cleaned up list
            saveDownloadedFiles()
            
        } catch {
            Logger.log("❌ Failed to load downloaded files metadata: \(error)")
            downloadedFiles = []
        }
    }

    private func resolveBackendVoice(for voiceId: String) -> Voice {
        if let match = VoiceCatalog.shared.voices.first(where: { $0.voiceSampleId == voiceId }) {
            return match
        }

        return Voice(
            name: "Backend Voice",
            language: "English",
            accent: "",
            type: VoiceType.Premium.rawValue,
            voiceSampleId: voiceId,
            source: .remote,
            languageCode: "en",
            backendVoiceID: Int(voiceId)
        )
    }

    private func resolvedLanguageCode(for text: String, voice: Voice) -> String {
        if let languageCode = voice.languageCode, !languageCode.isEmpty {
            return languageCode
        }
        return LanguageDetection.detectLanguage(from: text) ?? "en"
    }
}

enum DownloadError: LocalizedError {
    case taskCreationFailed
    case speechGenerationFailed
    case downloadURLNotFound
    case fileNotFound
    case mergeFailed
    
    var errorDescription: String? {
        switch self {
        case .taskCreationFailed:
            return "Failed to create download task"
        case .speechGenerationFailed:
            return "Failed to generate speech"
        case .downloadURLNotFound:
            return "Download URL not found"
        case .fileNotFound:
            return "Audio file not found"
        case .mergeFailed:
            return "Failed to merge audio chunks"
        }
    }
}
