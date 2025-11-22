//
//  AppVoiceMode.swift
//  TTS
//
//  Created by Doniel Tripura on 11/20/25.
//


enum AppVoiceMode: String, Codable, CaseIterable {
    case system   // Apple AVSpeechSynthesizer
    case backend  // API-based voice
    
    var displayName: String {
        switch self {
        case .system:
            return "System Voice"
        case .backend:
            return "Backend Voice"
        }
    }
}
