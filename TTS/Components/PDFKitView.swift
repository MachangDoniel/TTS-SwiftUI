//
//  PDFKitView.swift
//  TTS
//
//  Updated 2025-10-12: dual highlights (sentence + word) + page cache
//

import SwiftUI
import PDFKit
import Combine

struct PDFKitView: UIViewRepresentable {
    let url: URL
    @ObservedObject var tts: TTSPlayer

    // Coordinator keeps highlight references, a page cache, and Combine cancellables
    class Coordinator {
        var currentSentenceHighlight: PDFAnnotation?
        var currentWordHighlight: PDFAnnotation?
        var sentencePageCache: [Int: PDFPage] = [:]
        var cancellables = Set<AnyCancellable>()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.document = PDFDocument(url: url)

        // React to sentence changes → highlight sentence (and clear word highlight)
        tts.$currentIndex
            .sink { index in
                highlightSentence(in: pdfView, index: index, coordinator: context.coordinator)
                // Clear previous word highlight when sentence changes
                if let w = context.coordinator.currentWordHighlight {
                    w.page?.removeAnnotation(w)
                    context.coordinator.currentWordHighlight = nil
                }
            }
            .store(in: &context.coordinator.cancellables)

        // React to word changes within the current sentence → highlight word
        tts.$currentWordInSentence
            .sink { word in
                highlightWord(in: pdfView,
                              word: word,
                              sentence: tts.currentSentenceText,
                              coordinator: context.coordinator)
            }
            .store(in: &context.coordinator.cancellables)

        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        // no-op
    }

    // MARK: - Sentence highlight (yellow) with page caching
    private func highlightSentence(in pdfView: PDFView,
                                   index: Int,
                                   coordinator: Coordinator) {
        guard tts.sentences.indices.contains(index) else { return }
        let sentence = tts.sentences[index]

        // Remove previous sentence highlight
        if let prev = coordinator.currentSentenceHighlight {
            prev.page?.removeAnnotation(prev)
            coordinator.currentSentenceHighlight = nil
        }

        guard let doc = pdfView.document else { return }

        // Use cached page if known
        if let page = coordinator.sentencePageCache[index],
           let pageText = page.string,
           let range = pageText.range(of: sentence) {
            applySentenceHighlight(on: page,
                                   pageText: pageText,
                                   range: range,
                                   coordinator: coordinator,
                                   pdfView: pdfView)
            return
        }

        // Find sentence once and cache the page
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i), let pageText = page.string else { continue }
            if let range = pageText.range(of: sentence) {
                coordinator.sentencePageCache[index] = page
                applySentenceHighlight(on: page,
                                       pageText: pageText,
                                       range: range,
                                       coordinator: coordinator,
                                       pdfView: pdfView)
                break
            }
        }
    }

    private func applySentenceHighlight(on page: PDFPage,
                                        pageText: String,
                                        range: Range<String.Index>,
                                        coordinator: Coordinator,
                                        pdfView: PDFView) {
        let nsRange = NSRange(range, in: pageText)
        if let selection = page.selection(for: nsRange) {
            let bounds = selection.bounds(for: page)
            let highlight = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
            highlight.color = UIColor.yellow.withAlphaComponent(0.35)
            page.addAnnotation(highlight)
            coordinator.currentSentenceHighlight = highlight
            pdfView.go(to: selection)
        }
    }

    // MARK: - Word highlight (orange) within the current sentence/page
    private func highlightWord(in pdfView: PDFView,
                               word: String,
                               sentence: String,
                               coordinator: Coordinator) {
        guard !word.isEmpty else { return }
        guard let doc = pdfView.document else { return }

        // Remove previous word highlight (keep sentence highlight)
        if let prev = coordinator.currentWordHighlight {
            prev.page?.removeAnnotation(prev)
            coordinator.currentWordHighlight = nil
        }

        // Use cached page for the current sentence
        let idx = tts.currentIndex
        guard let page = coordinator.sentencePageCache[idx],
              let pageText = page.string else { return }

        // Find the word inside the sentence range, on this page
        guard let sentenceRange = pageText.range(of: sentence) else { return }

        // Determine which occurrence index of `word` we're speaking within the sentence.
        // We do this by counting occurrences up to the start of the currentWordRange inside the utterance string.
        let spokenIndex: Int = {
            guard let range = tts.currentWordRange else { return 0 }
            let utter = tts.currentSentenceText
            let start = utter.startIndex
            if let startIdx = Range(range, in: utter)?.lowerBound {
                let prefix = String(utter[start..<startIdx])
                // Count case-insensitive occurrences of `word` in the prefix
                var count = 0
                var searchRange: Range<String.Index>? = prefix.startIndex..<prefix.endIndex
                while let r = prefix.range(of: word, options: [.caseInsensitive], range: searchRange) {
                    count += 1
                    searchRange = r.upperBound..<prefix.endIndex
                }
                return count
            }
            return 0
        }()

        // Now find the same occurrence of `word` within the sentence range on the page
        var foundRange: Range<String.Index>? = nil
        var occurrence = 0
        var searchRange: Range<String.Index>? = sentenceRange
        while let r = pageText.range(of: word, options: [.caseInsensitive], range: searchRange) {
            if occurrence == spokenIndex {
                foundRange = r
                break
            }
            occurrence += 1
            searchRange = r.upperBound..<sentenceRange.upperBound
        }

        if let wordRange = foundRange {
            let nsWordRange = NSRange(wordRange, in: pageText)
            if let selection = page.selection(for: nsWordRange) {
                let bounds = selection.bounds(for: page)
                let highlight = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
                highlight.color = UIColor.orange.withAlphaComponent(0.45)
                page.addAnnotation(highlight)
                coordinator.currentWordHighlight = highlight
            }
        }
    }
}
