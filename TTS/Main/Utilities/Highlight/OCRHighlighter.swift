//
//  OCRHighlighter.swift
//  TTS
//
//  Created by Assistant on 11/11/25.
//

import Foundation
import CoreGraphics

final class OCRHighlighter: TextSurfaceHighlighter {
    private let words: [OCRWordBox]
    private let normalizedLookup: [String: [OCRWordBox]]

    init(words: [OCRWordBox]) {
        self.words = words
        var map: [String: [OCRWordBox]] = [:]
        for w in words {
            let k = TextNormalization.normalize(w.text.lowercased())
            map[k, default: []].append(w)
        }
        self.normalizedLookup = map
    }

    func sentenceRects(sentence: SentenceSpan, containerSize: CGSize) -> [CGRect] {
        // Approximate: return union lines for tokens found
        let tokens = TextNormalization.tokenize(sentence.text).tokens.map { $0.token.lowercased() }
        var rects: [CGRect] = []
        for t in tokens {
            if let w = normalizedLookup[t]?.first {
                rects.append(w.rect)
            }
        }
        return rects
    }

    func wordRect(word: WordSpan, containerSize: CGSize) -> CGRect? {
        // Unknown mapping from NSRange to OCR; rely on sentenceRects for now
        return nil
    }
}

