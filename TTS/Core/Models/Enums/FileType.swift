//
//  FileType.swift
//  TTS
//
//  Created by Doniel Tripura on 12/2/25.
//


public enum FileType: String, CaseIterable, Codable {
    case pdf, image, text
    
    var displayName: String {
        switch self {
        case .pdf: return "PDF"
        case .image: return "Image"
        case .text: return "Text"
        }
    }
    
    var icon: String {
        switch self {
        case .pdf: return "doc.fill"
        case .image: return "photo.fill"
        case .text: return "text.alignleft"
        }
    }
}
