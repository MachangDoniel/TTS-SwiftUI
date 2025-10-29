//
//  VoiceCard.swift
//  TTS
//
//  Created by Doniel Tripura on 10/20/25.
//

// Holds all available voices (backend + system) and provides them as a shared singleton.

import Foundation
import AVFoundation
import Combine

/// A shared singleton catalog managing all available voices, including backend and system voices.
final class VoiceCatalog: ObservableObject {
    static let shared = VoiceCatalog()
    @Published private(set) var voices: [Voice] = []
    @Published private(set) var languages: [String] = []

    private init() {
        reloadVoices()
    }

    /// Reloads the list of voices by combining backend custom voices and system voices while avoiding duplicates.
    func reloadVoices() {
        // Backend (custom) voices with consistent voice type usage
        let backendVoices: [Voice] = [
//            Voice(name: "Siri",      language: "English", accent: "US", mood: "Calm",      type: VoiceType.Free.rawValue,    voiceSampleId: "0"),
            Voice(name: "Anastasia", language: "English", accent: "US", mood: "Calm",      type: VoiceType.Premium.rawValue, voiceSampleId: "1"),
            Voice(name: "Carlos",    language: "Español", accent: "ES", mood: "Lively",    type: VoiceType.Premium.rawValue, voiceSampleId: "2"),
            Voice(name: "Emma",      language: "English", accent: "UK", mood: "Friendly",  type: VoiceType.Premium.rawValue, voiceSampleId: "3"),
            Voice(name: "Nikolai",   language: "Russian", accent: "RU", mood: "Calm",      type: VoiceType.Premium.rawValue, voiceSampleId: "4"),
            Voice(name: "Sophia",    language: "German",  accent: "DE", mood: "Bright",    type: VoiceType.Premium.rawValue, voiceSampleId: "5"),
            Voice(name: "Mia",       language: "Danish",  accent: "DK", mood: "Energetic", type: VoiceType.Premium.rawValue, voiceSampleId: "6"),
            Voice(name: "Giovanni",  language: "Italian", accent: "IT", mood: "Smooth",    type: VoiceType.Premium.rawValue, voiceSampleId: "7"),
            Voice(name: "Lena",      language: "Greek",   accent: "GR", mood: "Warm",      type: VoiceType.Premium.rawValue, voiceSampleId: "8"),
            Voice(name: "Aarav",     language: "Hindi",   accent: "IN", mood: "Deep",      type: VoiceType.Premium.rawValue, voiceSampleId: "9"),
            Voice(name: "Maria",     language: "Español", accent: "MX", mood: "Soft",      type: VoiceType.Premium.rawValue, voiceSampleId: "10"),
        ]
        let backendIds = Set(backendVoices.map { $0.voiceSampleId })

        // System voices from AVSpeechSynthesisVoice, excluding duplicates
        let systemVoices: [Voice] = AVSpeechSynthesisVoice.speechVoices().map { avVoice in
            Voice(
                name: avVoice.name,
                language: Locale.current.localizedString(forIdentifier: avVoice.language) ?? avVoice.language,
                accent: avVoice.language.components(separatedBy: "-").last ?? "",
                mood: "Default",
                type: VoiceType.Free.rawValue,
                voiceSampleId: avVoice.identifier
            )
        }
        let filteredSystem = systemVoices.filter { !backendIds.contains($0.voiceSampleId) }

        self.voices = backendVoices + filteredSystem
        self.languages = Array(Set(self.voices.map { $0.language })).sorted()
    }
}

