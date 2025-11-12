//
//  HighlightCoordinator.swift
//  TTS
//
//  Created by Assistant on 11/11/25.
//

import Foundation
import SwiftUI
import PDFKit
import Combine

@MainActor
final class HighlightCoordinator: ObservableObject {
    enum SurfaceDocument {
        case plainText(text: String)
        case pdf(document: PDFDocument)
        case ocr(words: [OCRWordBox])
    }

    @Published var sentenceRects: [Int: [CGRect]] = [:]
    @Published var wordRect: CGRect? = nil

    private var highlighter: TextSurfaceHighlighter?
    private var cancellableTask: Task<Void, Never>?

    func setDocument(_ doc: SurfaceDocument) {
        switch doc {
        case .plainText(let text):
            highlighter = PlainTextHighlighter(fullText: text)
        case .pdf(let document):
            highlighter = PDFHighlighter(document: document)
        case .ocr(let words):
            highlighter = OCRHighlighter(words: words)
        }
    }

    func updateHighlight(sentence: SentenceSpan, word: WordSpan?, containerSize: CGSize) {
        cancellableTask?.cancel()
        // Throttle/coalesce updates lightly
        cancellableTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 12_000_000) // ~12ms
            guard let self, let highlighter else { return }
            let rects = highlighter.sentenceRects(sentence: sentence, containerSize: containerSize)
            let wrect = word.flatMap { highlighter.wordRect(word: $0, containerSize: containerSize) }
            await MainActor.run {
                self.sentenceRects[sentence.index] = rects
                self.wordRect = wrect
            }
        }
    }
}

struct SentenceSpan {
    let index: Int
    let text: String
    let nsRange: NSRange? // for PDF/plain mapping if known
}

struct WordSpan {
    let nsRange: NSRange
    let tokenIndex: Int?
}

protocol TextSurfaceHighlighter {
    func sentenceRects(sentence: SentenceSpan, containerSize: CGSize) -> [CGRect]
    func wordRect(word: WordSpan, containerSize: CGSize) -> CGRect?
}

