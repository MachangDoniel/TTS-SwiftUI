//
//  PDFHighlighter.swift
//  TTS
//
//  Created by Assistant on 11/11/25.
//

import Foundation
import PDFKit
import CoreGraphics

final class PDFHighlighter: TextSurfaceHighlighter {
    private let document: PDFDocument

    init(document: PDFDocument) {
        self.document = document
    }

    func sentenceRects(sentence: SentenceSpan, containerSize: CGSize) -> [CGRect] {
        // Delegate to PDFKit selection per line if we can map the range
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i), let pageText = page.string else { continue }
            if let range = pageText.range(of: sentence.text) {
                let nsRange = NSRange(range, in: pageText)
                if let sel = page.selection(for: nsRange) {
                    return sel.selectionsByLine().map { $0.bounds(for: page) }.filter { !$0.isEmpty }
                }
            }
        }
        return []
    }

    func wordRect(word: WordSpan, containerSize: CGSize) -> CGRect? {
        // Word rect will be handled by caller at sentence scope for PDF
        return nil
    }
}

