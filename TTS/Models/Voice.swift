//
//  Voice.swift
//  TTS
//
//  Created by Doniel Tripura on 10/20/25.
//

import Foundation

struct Voice: Identifiable {
    let id = UUID()
    let name: String
    let language: String
    let accent: String
    let mood: String
    let type: String // "Free" or "Premium"
}
