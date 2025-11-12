//
//  TextNormalization.swift
//  TTS
//
//  Created by Assistant on 11/11/25.
//

import Foundation

struct NormalizedToken {
    let token: String
    let originalRange: NSRange
}

struct TokenMap {
    let original: String
    let normalized: String
    let tokens: [NormalizedToken]
}

enum TextNormalization {
    static func normalize(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let collapsed = trimmed.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let replacedQuotes = collapsed
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")
            .replacingOccurrences(of: "“", with: "\"")
            .replacingOccurrences(of: "”", with: "\"")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "–", with: "-")
        return replacedQuotes
    }

    static func tokenize(_ s: String) -> TokenMap {
        let normalized = normalize(s)
        var tokens: [NormalizedToken] = []
        let ns = normalized as NSString
        let scanner = Scanner(string: normalized)
        scanner.charactersToBeSkipped = nil
        while !scanner.isAtEnd {
            var word: NSString?
            // Scan up to whitespace
            if scanner.scanUpToCharacters(from: .whitespacesAndNewlines, into: &word), let word = word {
                let location = scanner.currentIndex.utf16Offset(in: normalized) - word.length
                let range = NSRange(location: max(0, location), length: word.length)
                tokens.append(NormalizedToken(token: word as String, originalRange: range))
            }
            _ = scanner.scanCharacters(from: .whitespacesAndNewlines, into: nil)
        }
        return TokenMap(original: s, normalized: normalized, tokens: tokens)
    }
}

