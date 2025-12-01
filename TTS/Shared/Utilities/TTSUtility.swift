//
//  TTSUtility.swift
//  TTS
//
//  Created by Doniel Tripura on 12/1/25.
//

import Foundation

public struct TTSUtility {
    public static func determineFileType(from url: URL) -> FileType {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf":
            return .pdf
        case "png", "jpg", "jpeg", "heic":
            return .image
        default:
            return .text
        }
    }
    
    public static func isTextFile(url: URL) -> Bool {
        return determineFileType(from: url) == .text
    }
}
