//
//  PlainTextHighlighter.swift
//  TTS
//
//  Created by Assistant on 11/11/25.
//

import Foundation
import SwiftUI

final class PlainTextHighlighter: TextSurfaceHighlighter {
    private let fullText: String

    init(fullText: String) {
        self.fullText = fullText
    }

    func sentenceRects(sentence: SentenceSpan, containerSize: CGSize) -> [CGRect] {
        guard !sentence.text.isEmpty else { return [] }
        let textStorage = NSTextStorage(string: sentence.text, attributes: [.font: UIFont.systemFont(ofSize: 18)])
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: containerSize)
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = 0
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        var rects: [CGRect] = []
        let glyphRange = layoutManager.glyphRange(forBoundingRect: CGRect(origin: .zero, size: containerSize), in: textContainer)
        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, usedRect, _, range, _ in
            // Use usedRect to represent the line area
            if range.length > 0 {
                rects.append(usedRect)
            }
        }
        return rects
    }

    func wordRect(word: WordSpan, containerSize: CGSize) -> CGRect? {
        let textStorage = NSTextStorage(string: "", attributes: [.font: UIFont.systemFont(ofSize: 18)])
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: containerSize)
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = 0
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        // This highlighter expects to be used per-sentence; the caller should provide
        // a sentence-local NSRange. We just query the rect for that range.
        let rect = layoutManager.boundingRect(forGlyphRange: word.nsRange, in: textContainer)
        return rect.isEmpty ? nil : rect
    }
}

