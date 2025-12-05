//
//  LanguageDetection.swift
//  TTS
//
//  Created by Doniel Tripura on 12/XX/25.
//

import Foundation
import NaturalLanguage

/// Service for detecting language from text using NaturalLanguage framework
struct LanguageDetection {
    
    /// Minimum confidence threshold for language detection (0.0 to 1.0)
    /// Detections below this threshold will be considered unreliable
    static let minimumConfidence: Double = 0.3
    
    /// Minimum text length to attempt language detection
    /// Very short text may not provide reliable detection
    static let minimumTextLength: Int = 10
    
    /// Detects the language of the given text
    /// - Parameter text: The text to analyze
    /// - Returns: The detected language code (e.g., "en", "es", "hi", "bn") or nil if detection fails or confidence is too low
    static func detectLanguage(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Skip detection for empty or very short text
        guard trimmed.count >= minimumTextLength else {
            Logger.log("⚠️ Language detection skipped: text too short (\(trimmed.count) chars)")
            return nil
        }
        
        // Use NLLanguageRecognizer for language detection
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        
        // Get the dominant language
        guard let dominantLanguage = recognizer.dominantLanguage else {
            Logger.log("⚠️ Language detection failed: no dominant language found")
            return nil
        }
        
        // Get confidence for the dominant language
        let hypotheses = recognizer.languageHypotheses(withMaximum: 1)
        let confidence = hypotheses[dominantLanguage] ?? 0.0
        
        // Check if confidence meets minimum threshold
        guard confidence >= minimumConfidence else {
            Logger.log("⚠️ Language detection confidence too low: \(confidence) for language \(dominantLanguage.rawValue)")
            return nil
        }
        
        Logger.log("✅ Language detected: \(dominantLanguage.rawValue) (confidence: \(String(format: "%.2f", confidence)))")
        
        // Return the language code (e.g., "en", "es", "hi")
        return dominantLanguage.rawValue
    }
    
    /// Maps ISO language code to VoiceCatalog language name
    /// Uses Locale.current.localizedString(forIdentifier:) to match how VoiceCatalog stores language names
    /// VoiceCatalog uses: Locale.current.localizedString(forIdentifier: avVoice.language)
    /// which returns formats like "Arabic (world)", "Bangla (India)", "Bulgarian (Bulgaria)", etc.
    /// - Parameter languageCode: ISO language code (e.g., "en", "es", "hi", "bn")
    /// - Returns: Localized language name matching VoiceCatalog format (e.g., "Arabic (world)", "Bangla (India)") or nil if mapping fails
    static func mapLanguageCodeToName(_ languageCode: String) -> String? {
        // VoiceCatalog uses Locale.current.localizedString(forIdentifier: avVoice.language)
        // where avVoice.language is typically a full locale identifier like "ar-SA", "bn-IN", "en-US"
        // We need to construct similar identifiers to get matching format
        
        // If already a full locale identifier, use it directly
        if languageCode.contains("-") {
            if let name = Locale.current.localizedString(forIdentifier: languageCode), !name.isEmpty {
                return name
            }
        }
        
        // Extract base language code
        let baseCode = languageCode.components(separatedBy: "-").first?.lowercased() ?? languageCode.lowercased()
        
        // Common region mappings that match AVSpeechSynthesisVoice locale identifiers
        // These are the most common formats used by iOS system voices
        let regionMappings: [String: String] = [
            "ar": "ar-SA",      // Arabic (Saudi Arabia) -> "Arabic (world)" or similar
            "bn": "bn-IN",      // Bangla (India) -> "Bangla (India)"
            "bg": "bg-BG",      // Bulgarian (Bulgaria) -> "Bulgarian (Bulgaria)"
            "ca": "ca-ES",      // Catalan (Spain) -> "Catalan (Spain)"
            "cs": "cs-CZ",      // Czech (Czech Republic)
            "da": "da-DK",      // Danish (Denmark)
            "de": "de-DE",      // German (Germany)
            "el": "el-GR",      // Greek (Greece)
            "en": "en-US",      // English (United States)
            "es": "es-ES",      // Spanish (Spain)
            "fi": "fi-FI",      // Finnish (Finland)
            "fr": "fr-FR",      // French (France)
            "he": "he-IL",      // Hebrew (Israel)
            "hi": "hi-IN",      // Hindi (India)
            "hr": "hr-HR",      // Croatian (Croatia)
            "hu": "hu-HU",      // Hungarian (Hungary)
            "id": "id-ID",      // Indonesian (Indonesia)
            "it": "it-IT",      // Italian (Italy)
            "ja": "ja-JP",      // Japanese (Japan)
            "ko": "ko-KR",      // Korean (Korea)
            "ms": "ms-MY",      // Malay (Malaysia)
            "nl": "nl-NL",      // Dutch (Netherlands)
            "no": "no-NO",      // Norwegian (Norway)
            "pl": "pl-PL",      // Polish (Poland)
            "pt": "pt-BR",      // Portuguese (Brazil)
            "ro": "ro-RO",      // Romanian (Romania)
            "ru": "ru-RU",      // Russian (Russia)
            "sk": "sk-SK",      // Slovak (Slovakia)
            "sv": "sv-SE",      // Swedish (Sweden)
            "th": "th-TH",      // Thai (Thailand)
            "tr": "tr-TR",      // Turkish (Turkey)
            "uk": "uk-UA",      // Ukrainian (Ukraine)
            "vi": "vi-VN",      // Vietnamese (Vietnam)
            "zh": "zh-CN"       // Chinese (China)
        ]
        
        // Try with mapped region code first (most likely to match AVSpeechSynthesisVoice format)
        if let regionCode = regionMappings[baseCode] {
            if let name = Locale.current.localizedString(forIdentifier: regionCode), !name.isEmpty {
                return name
            }
        }
        
        // Fallback: try with base code (might work for some languages)
        if let name = Locale.current.localizedString(forIdentifier: baseCode), !name.isEmpty {
            return name
        }
        
        Logger.log("⚠️ Could not map language code '\(languageCode)' to name")
        return nil
    }
    
    /// Extracts the base language name from a language string that may include region
    /// e.g., "Arabic (world)" -> "Arabic", "Bangla (India)" -> "Bangla"
    /// - Parameter languageString: Language string that may include region in parentheses
    /// - Returns: Base language name without region
    static func extractBaseLanguageName(_ languageString: String) -> String {
        // Remove region in parentheses: "Arabic (world)" -> "Arabic"
        if let parenIndex = languageString.firstIndex(of: "(") {
            return String(languageString[..<parenIndex]).trimmingCharacters(in: .whitespaces)
        }
        return languageString.trimmingCharacters(in: .whitespaces)
    }
}

