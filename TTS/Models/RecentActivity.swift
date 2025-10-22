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
    var fileExtensionLowercased: String? {
        if let sp = sourcePath, !sp.isEmpty {
            if let url = URL(string: sp), url.scheme != nil {
                let ext = url.pathExtension
                if !ext.isEmpty { return ext.lowercased() }
            }
            if let ext = sp.split(separator: ".").last, sp.contains(".") {
                return String(ext).lowercased()
            }
        }
        if let ext = title.split(separator: ".").last, title.contains(".") {
            return String(ext).lowercased()
        }
        return nil
    }

    enum FileCategory {
        case pdf, text, image, other
    }

    var fileCategory: FileCategory {
        switch kind {
        case .text: return .text
        case .photos: return .image
        default:
            guard let ext = fileExtensionLowercased else { return .other }
            if ext == "pdf" { return .pdf }
            if ext == "txt" { return .text }
            if ["png", "jpg", "jpeg", "heic"].contains(ext) { return .image }
            return .other
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
