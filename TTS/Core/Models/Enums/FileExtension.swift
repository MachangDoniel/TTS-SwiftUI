//
//  FileExtension.swift
//  TTS
//
//  Created by Doniel Tripura on 11/2/25.
//

import Foundation

/// Strongly-typed file extensions used across TTS.
enum FileExtension: String, CaseIterable, Codable, Equatable {
    // Common types
    case pdf
    case txt
    case png
    case jpg
    case jpeg
    case heic

    // Catch-all
    case unknown

    /// Initialize from string (case-insensitive)
    init(from string: String?) {
        guard let ext = string?.lowercased() else {
            self = .unknown
            return
        }
        self = FileExtension(rawValue: ext) ?? .unknown
    }

    /// Indicates if this extension is an image type
    var isImage: Bool {
        switch self {
        case .png, .jpg, .jpeg, .heic:
            return true
        default:
            return false
        }
    }

    /// Indicates if this extension is a text file
    var isText: Bool { self == .txt }

    /// Indicates if this extension is a PDF file
    var isPDF: Bool { self == .pdf }
}
