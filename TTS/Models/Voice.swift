//
//  Voice.swift
//  TTS
//
//  Created by Doniel Tripura on 10/20/25.
//

import Foundation

struct Voice: Identifiable, Codable {
    let id = UUID()
    let name: String
    let language: String
    let accent: String
    let mood: String
    let type: String
    let voiceSampleId: String
}

enum VoiceType: String {
    case Free = "Free"
    case Premium = "Premium"
}
