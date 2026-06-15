//
//  OnlineLibraryItem.swift
//  TTS
//
//  Created by Assistant on 6/15/26.
//

import Foundation

struct OnlineLibraryItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var sourcePath: String?
    var kind: InputSource
    var thumbnailData: Data?
    var bookmarkData: Data?
    var wordCount: Int?
    let requestId: String
    var projectKey: String
    var projectTitle: String
    var originalSourceURL: String
    var originalSourceExtension: String
    var generatedTextFilePath: String
    var remoteTextURLs: [String]
    var remoteAudioURLs: [String]
    var localAudioPaths: [String]
    var voiceSampleId: String
    var voiceName: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        sourcePath: String? = nil,
        kind: InputSource = .text,
        thumbnailData: Data? = nil,
        bookmarkData: Data? = nil,
        wordCount: Int? = nil,
        requestId: String,
        projectKey: String,
        projectTitle: String,
        originalSourceURL: String,
        originalSourceExtension: String,
        generatedTextFilePath: String,
        remoteTextURLs: [String],
        remoteAudioURLs: [String],
        localAudioPaths: [String],
        voiceSampleId: String,
        voiceName: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.sourcePath = sourcePath
        self.kind = kind
        self.thumbnailData = thumbnailData
        self.bookmarkData = bookmarkData
        self.wordCount = wordCount
        self.requestId = requestId
        self.projectKey = projectKey
        self.projectTitle = projectTitle
        self.originalSourceURL = originalSourceURL
        self.originalSourceExtension = originalSourceExtension
        self.generatedTextFilePath = generatedTextFilePath
        self.remoteTextURLs = remoteTextURLs
        self.remoteAudioURLs = remoteAudioURLs
        self.localAudioPaths = localAudioPaths
        self.voiceSampleId = voiceSampleId
        self.voiceName = voiceName
        self.createdAt = createdAt
    }

    var generatedTextURL: URL {
        resolvedManagedFileURL(
            storedPath: generatedTextFilePath,
            directory: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        )
    }

    var originalURL: URL? {
        if let remote = URL(string: originalSourceURL), remote.scheme != nil {
            return remote
        }
        return URL(fileURLWithPath: originalSourceURL)
    }

    var generatedFileName: String {
        generatedTextURL.lastPathComponent
    }

    var resolvedLocalAudioURLs: [URL] {
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return localAudioPaths
            .filter { !$0.isEmpty }
            .map { resolvedManagedFileURL(storedPath: $0, directory: cacheDirectory) }
    }

    var primaryLocalAudioURL: URL? {
        resolvedLocalAudioURLs.first
    }

    var primaryRemoteAudioURL: URL? {
        guard let value = remoteAudioURLs.first, !value.isEmpty else { return nil }
        return URL(string: value)
    }

    private func resolvedManagedFileURL(storedPath: String, directory: URL) -> URL {
        let fm = FileManager.default
        let directURL = URL(fileURLWithPath: storedPath)
        if fm.fileExists(atPath: directURL.path) {
            return directURL
        }

        let fileName = directURL.lastPathComponent
        let reboundURL = directory.appendingPathComponent(fileName)
        return reboundURL
    }

    func normalizedForPersistence(fileManager: FileManager = .default) -> OnlineLibraryItem {
        var normalized = self

        if isManagedFilePath(generatedTextFilePath, existingAt: generatedTextURL, fileManager: fileManager) {
            normalized.generatedTextFilePath = generatedTextURL.lastPathComponent
        }

        normalized.localAudioPaths = resolvedLocalAudioURLs.map { url in
            if isManagedFilePath(url.path, existingAt: url, fileManager: fileManager) {
                return url.lastPathComponent
            }
            return url.path
        }

        return normalized
    }

    private func isManagedFilePath(_ storedPath: String, existingAt url: URL, fileManager: FileManager) -> Bool {
        guard fileManager.fileExists(atPath: url.path) else {
            return false
        }

        let rawURL = URL(fileURLWithPath: storedPath)
        let path = rawURL.path
        return path.contains("/Documents/") || path.contains("/Library/Caches/") || !storedPath.contains("/")
    }
}

struct OnlineLibraryProject: Identifiable {
    let projectKey: String
    let projectTitle: String
    let originalSourceURL: String
    let originalSourceExtension: String
    let items: [OnlineLibraryItem]

    var id: String { projectKey }
}
