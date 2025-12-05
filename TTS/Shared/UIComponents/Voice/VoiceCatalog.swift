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
    // Map system voice identifier -> BCP-47 language code (e.g., "es-MX")
    private var languageCodeByVoiceId: [String: String] = [:]
    
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
//            Voice(name: "Anastasia", language: "English", accent: "US", mood: "Calm",      type: VoiceType.Premium.rawValue, voiceSampleId: "1"),
//            Voice(name: "Carlos",    language: "Español", accent: "ES", mood: "Lively",    type: VoiceType.Premium.rawValue, voiceSampleId: "2"),
//            Voice(name: "Emma",      language: "English", accent: "UK", mood: "Friendly",  type: VoiceType.Premium.rawValue, voiceSampleId: "3"),
//            Voice(name: "Nikolai",   language: "Russian", accent: "RU", mood: "Calm",      type: VoiceType.Premium.rawValue, voiceSampleId: "4"),
//            Voice(name: "Sophia",    language: "German",  accent: "DE", mood: "Bright",    type: VoiceType.Premium.rawValue, voiceSampleId: "5"),
//            Voice(name: "Mia",       language: "Danish",  accent: "DK", mood: "Energetic", type: VoiceType.Premium.rawValue, voiceSampleId: "6"),
//            Voice(name: "Giovanni",  language: "Italian", accent: "IT", mood: "Smooth",    type: VoiceType.Premium.rawValue, voiceSampleId: "7"),
//            Voice(name: "Lena",      language: "Greek",   accent: "GR", mood: "Warm",      type: VoiceType.Premium.rawValue, voiceSampleId: "8"),
//            Voice(name: "Aarav",     language: "Hindi",   accent: "IN", mood: "Deep",      type: VoiceType.Premium.rawValue, voiceSampleId: "9"),
//            Voice(name: "Maria",     language: "Español", accent: "MX", mood: "Soft",      type: VoiceType.Premium.rawValue, voiceSampleId: "10"),
        ]
        let backendIds = Set(backendVoices.map { $0.voiceSampleId })
        
        // Reset mapping on reload
        languageCodeByVoiceId = [:]

        // System voices from AVSpeechSynthesisVoice, excluding duplicates
        let systemVoices: [Voice] = AVSpeechSynthesisVoice.speechVoices().map { avVoice in
            // Record the exact BCP-47 code for precise matching later
            languageCodeByVoiceId[avVoice.identifier] = avVoice.language
            return Voice(
                name: avVoice.name,
                language: Locale.current.localizedString(forIdentifier: avVoice.language) ?? avVoice.language,
                accent: avVoice.language.components(separatedBy: "-").last ?? "",
                mood: nil,
                type: VoiceType.Free.rawValue,
                voiceSampleId: avVoice.identifier
            )
        }
        let filteredSystem = systemVoices.filter { !backendIds.contains($0.voiceSampleId) }

        self.voices = backendVoices + filteredSystem
        self.languages = Array(Set(self.voices.map { $0.language })).sorted()
    }
    
    // Normalize a BCP-47 code to its base language (e.g., "es-MX" -> "es")
    private func baseLanguageCode(from code: String) -> String {
        // Split on '-' and take the first segment as the base language
        return code.split(separator: "-").first.map(String.init) ?? code
    }

    // Returns the language code (BCP-47) for a given voice if known
    private func languageCodeOf(voice: Voice) -> String? {
        // We only have codes for system voices we built from AVSpeechSynthesisVoice
        return languageCodeByVoiceId[voice.voiceSampleId]
    }
    
    /// Finds a voice that matches the given language code
    /// Handles language names with regions like "Arabic (world)", "Bangla (India)", etc.
    /// - Parameters:
    ///   - languageCode: ISO language code (e.g., "en", "es", "hi", "bn")
    ///   - preferSystem: If true, prefers system (free) voices over backend voices
    /// - Returns: A matching Voice, or nil if no match is found
    func findVoiceForLanguage(_ languageCode: String, preferSystem: Bool = true) -> Voice? {
        // Normalize requested code and prepare base
        let requestedCode = languageCode
        let requestedBase = baseLanguageCode(from: requestedCode)

        // 1) Try exact BCP-47 code match (e.g., "es-MX")
        var matchingVoices = voices.filter { voice in
            guard let code = languageCodeOf(voice: voice) else { return false }
            return code.caseInsensitiveCompare(requestedCode) == .orderedSame
        }

        // 2) If none found, try base code match (e.g., "es-MX" -> "es")
        if matchingVoices.isEmpty {
            matchingVoices = voices.filter { voice in
                guard let code = languageCodeOf(voice: voice) else { return false }
                return baseLanguageCode(from: code).caseInsensitiveCompare(requestedBase) == .orderedSame
            }
        }

        // 3) If still none, fall back to existing name-based matching using LanguageDetection
        if matchingVoices.isEmpty {
            guard let detectedLanguageName = LanguageDetection.mapLanguageCodeToName(requestedCode) else {
                Logger.log("⚠️ Could not map language code '\(requestedCode)' to language name")
                return nil
            }
            let baseDetectedName = LanguageDetection.extractBaseLanguageName(detectedLanguageName)

            matchingVoices = voices.filter { voice in
                if voice.language == detectedLanguageName { return true }
                let baseVoiceName = LanguageDetection.extractBaseLanguageName(voice.language)
                return baseVoiceName.localizedCaseInsensitiveCompare(baseDetectedName) == .orderedSame
            }

            if matchingVoices.isEmpty {
                Logger.log("⚠️ No voices found for language '\(detectedLanguageName)' (code: \(requestedCode), base: \(baseDetectedName))")
                return nil
            }
        }

        // Prefer system (free) voices if requested
        if preferSystem {
            let system = matchingVoices.first { $0.type == VoiceType.Free.rawValue }
            if let systemVoice = system {
                Logger.log("✅ Found system voice '\(systemVoice.name)' for code '\(requestedCode)'")
                return systemVoice
            }
            if let any = matchingVoices.first {
                Logger.log("✅ Found backend voice '\(any.name)' for code '\(requestedCode)'")
                return any
            }
        } else {
            if let any = matchingVoices.first {
                Logger.log("✅ Found voice '\(any.name)' for code '\(requestedCode)'")
                return any
            }
        }

        return nil
    }
}

