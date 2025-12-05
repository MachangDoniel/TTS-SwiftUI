//
//  WordTokenizer.swift
//  TTS
//
//  Created by Assistant on 11/11/25.
//

import Foundation

/// Represents a single word token with its position and range information
struct WordToken {
    let text: String
    let range: NSRange  // Range within the sentence
    let index: Int      // Word index within the sentence (0-based)
    var absoluteRange: NSRange? = nil  // Range in full text (computed later if needed)
}

/// Utility class for tokenizing text into words with accurate position tracking
final class WordTokenizer {
    
    /// Tokenizes a sentence into word tokens with exact ranges and indices
    /// - Parameter sentence: The sentence string to tokenize
    /// - Returns: Array of WordToken structs with accurate position information
    static func tokenize(_ sentence: String) -> [WordToken] {
        guard !sentence.isEmpty else { return [] }
        
        var tokens: [WordToken] = []
        let nsString = sentence as NSString
        let length = nsString.length
        
        // Use NSLinguisticTagger for accurate word tokenization
        let tagger = NSLinguisticTagger(tagSchemes: [.tokenType], options: 0)
        tagger.string = sentence
        
        var wordIndex = 0
        let range = NSRange(location: 0, length: length)
        
        tagger.enumerateTags(in: range, unit: .word, scheme: .tokenType, options: [.omitWhitespace, .omitPunctuation]) { tag, tokenRange, stop in
            guard tag == .word else { return }
            
            let wordText = nsString.substring(with: tokenRange)
            // Only include non-empty words
            if !wordText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                tokens.append(WordToken(
                    text: wordText,
                    range: tokenRange,
                    index: wordIndex
                ))
                wordIndex += 1
            }
        }
        
        // Fallback: if linguistic tagger didn't find words, use simple whitespace splitting
        if tokens.isEmpty {
            let words = sentence.components(separatedBy: .whitespacesAndNewlines)
            var currentLocation = 0
            for (index, word) in words.enumerated() {
                let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    // Find the word in the original string
                    let searchRange = NSRange(location: currentLocation, length: length - currentLocation)
                    let foundRange = nsString.range(of: trimmed, options: [], range: searchRange)
                    if foundRange.location != NSNotFound {
                        tokens.append(WordToken(
                            text: trimmed,
                            range: foundRange,
                            index: index
                        ))
                        currentLocation = foundRange.location + foundRange.length
                    }
                }
            }
        }
        
        return tokens
    }
    
    /// Tokenizes multiple sentences into arrays of word tokens
    /// - Parameter sentences: Array of sentence strings
    /// - Returns: Array of arrays, where each inner array contains WordToken structs for that sentence
    static func tokenizeSentences(_ sentences: [String]) -> [[WordToken]] {
        return sentences.map { tokenize($0) }
    }
    
    /// Finds a word token that matches the given NSRange
    /// Uses word index as primary identifier, range as secondary validation
    /// - Parameters:
    ///   - range: The NSRange to match
    ///   - tokens: Array of WordToken structs to search
    /// - Returns: The matching WordToken, or nil if not found
    static func findWordToken(by range: NSRange, in tokens: [WordToken]) -> WordToken? {
        guard range.location != NSNotFound else { return nil }
        
        // First, try exact range match
        if let exactMatch = tokens.first(where: { $0.range.location == range.location && $0.range.length == range.length }) {
            return exactMatch
        }
        
        // Try range overlap (for cases where whitespace handling differs)
        if let overlapMatch = tokens.first(where: { tokenRange in
            let tokenStart = tokenRange.range.location
            let tokenEnd = tokenRange.range.location + tokenRange.range.length
            let searchStart = range.location
            let searchEnd = range.location + range.length
            
            // Check if ranges overlap significantly (at least 50% overlap)
            let overlapStart = max(tokenStart, searchStart)
            let overlapEnd = min(tokenEnd, searchEnd)
            let overlapLength = max(0, overlapEnd - overlapStart)
            let minLength = min(tokenRange.range.length, range.length)
            
            return overlapLength > 0 && Double(overlapLength) / Double(minLength) >= 0.5
        }) {
            return overlapMatch
        }
        
        // Try finding by location (range starts within token range)
        if let locationMatch = tokens.first(where: { tokenRange in
            let tokenStart = tokenRange.range.location
            let tokenEnd = tokenRange.range.location + tokenRange.range.length
            return range.location >= tokenStart && range.location < tokenEnd
        }) {
            return locationMatch
        }
        
        // Last resort: find closest token by location
        return tokens.min(by: { abs($0.range.location - range.location) < abs($1.range.location - range.location) })
    }
    
    /// Finds a word token by its index in the sentence
    /// - Parameters:
    ///   - index: The word index (0-based)
    ///   - tokens: Array of WordToken structs to search
    /// - Returns: The WordToken at the given index, or nil if index is out of bounds
    static func findWordToken(by index: Int, in tokens: [WordToken]) -> WordToken? {
        guard index >= 0 && index < tokens.count else { return nil }
        return tokens[index]
    }
    
    /// Computes absolute ranges for word tokens in the context of full text
    /// - Parameters:
    ///   - sentenceTokens: Array of WordToken structs for a sentence
    ///   - sentenceRange: The NSRange of the sentence within the full text
    /// - Returns: Array of WordToken structs with absoluteRange set
    static func computeAbsoluteRanges(_ sentenceTokens: [WordToken], sentenceRange: NSRange) -> [WordToken] {
        return sentenceTokens.map { token in
            var updatedToken = token
            updatedToken.absoluteRange = NSRange(
                location: sentenceRange.location + token.range.location,
                length: token.range.length
            )
            return updatedToken
        }
    }
}

