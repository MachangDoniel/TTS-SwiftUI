//
//  RecentActivity.swift
//  TTS
//
//  Created by Doniel Tripura on 10/5/25.
//

import Foundation
import SwiftUI
import PDFKit
import UIKit

// MARK: - RecentActivity Model
struct RecentActivity: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var sourcePath: String?
    var kind: InputSource
    var createdAt: Date
    var thumbnailData: Data?
    var bookmarkData: Data?

    // Derived properties
    var fileExtension: FileExtension {
        if let sp = sourcePath, !sp.isEmpty {
            if let url = URL(string: sp), url.scheme != nil {
                return FileExtension(from: url.pathExtension)
            } else if let ext = sp.split(separator: ".").last {
                return FileExtension(from: String(ext))
            }
        }
        if let ext = title.split(separator: ".").last {
            return FileExtension(from: String(ext))
        }
        return .unknown
    }

    var fileCategory: FileCategory {
        switch kind {
        case .text:
            return .text
        case .photos:
            return .image
        default:
            switch fileExtension {
            case .pdf: return .pdf
            case .txt: return .text
            case .png, .jpg, .jpeg, .heic: return .image
            default: return .all
            }
        }
    }

    init(id: UUID = UUID(),
         title: String,
         sourcePath: String? = nil,
         kind: InputSource,
         createdAt: Date = Date(),
         thumbnailData: Data? = nil,
         bookmarkData: Data? = nil) {
        self.id = id
        self.title = title
        self.sourcePath = sourcePath
        self.kind = kind
        self.createdAt = createdAt
        self.thumbnailData = thumbnailData
        self.bookmarkData = bookmarkData
    }

    // Resolve usable URL
    var resolvedURL: URL? {
        if let bookmarkData {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmarkData,
                                  options: [.withoutUI],
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &isStale) {
                return url
            }
        }

        guard let sp = sourcePath, !sp.isEmpty else { return nil }

        if let url = URL(string: sp), url.scheme != nil {
            return url
        }

        return URL(fileURLWithPath: sp)
    }

    var fileExistsOnDisk: Bool {
        guard let url = resolvedURL, url.isFileURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }
}

extension RecentActivity {
    // MARK: - Text Persistence Helpers
    static func makeTextActivity(title: String, text: String) throws -> RecentActivity {
        let sanitizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = sanitizedTitle.isEmpty ? "Text" : sanitizedTitle
        let uniqueName = "\(base) - \(UUID().uuidString.prefix(8)).\(FileExtension.txt.rawValue)"
        Logger.log("[RecentActivity] Creating .txt file: \(uniqueName)")

        let fm = FileManager.default
        let docsURL = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let fileURL = docsURL.appendingPathComponent(uniqueName)
        Logger.log("[RecentActivity] Target path: \(fileURL.path)")

        let data = text.data(using: .utf8) ?? Data()
        Logger.log("[RecentActivity] Byte count: \(data.count)")

        do {
            try data.write(to: fileURL, options: .atomic)
            Logger.log("[RecentActivity] Wrote file successfully")
        } catch {
            Logger.log("[RecentActivity][Error] Failed to write file: \(error.localizedDescription)")
            throw error
        }

        return RecentActivity(title: uniqueName,
                              sourcePath: fileURL.path,
                              kind: .text,
                              createdAt: Date(),
                              thumbnailData: nil,
                              bookmarkData: nil)
    }
}
