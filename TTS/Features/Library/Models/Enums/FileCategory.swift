//
//  FileCategory.swift
//  TTS
//
//  Created by Doniel Tripura on 10/19/25.
//


// MARK: - Filter Enum
enum FileCategory: String, CaseIterable, Codable, Equatable {
    case all = "All Files"
    case pdf = "PDF"
    case text = "Text"
    case image = "Image"
}
