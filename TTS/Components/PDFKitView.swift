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
        var currentSentenceAnnotations: [PDFAnnotation] = []
        var stopTTS: (() -> Void)?

        struct SentenceLocation {
            let page: PDFPage
            let rangeInPageText: Range<String.Index>
        }
        var sentencePageCache: [Int: SentenceLocation] = [:]

        var highlightVersion: Int = 0
        var cancellables = Set<AnyCancellable>()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.document = PDFDocument(url: url)

        // React to source URL changes → clear caches/highlights and re-highlight current sentence
        tts.$currentURL
            .receive(on: DispatchQueue.main)
            .sink { _ in
                clearAllHighlights(in: pdfView, coordinator: context.coordinator)
                // Re-apply sentence highlight for the current index if available
                highlightSentence(in: pdfView, index: tts.currentIndex, coordinator: context.coordinator)
            }
            .store(in: &context.coordinator.cancellables)

        // React to sentence changes → highlight sentence (and clear word highlight)
        tts.$currentIndex
            .receive(on: DispatchQueue.main)
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
            .receive(on: DispatchQueue.main)
            .sink { word in
                highlightWord(in: pdfView,
                              word: word,
                              sentence: tts.currentSentenceText,
                              coordinator: context.coordinator)
            }
            .store(in: &context.coordinator.cancellables)

        // Initial highlight when view is created
        highlightSentence(in: pdfView, index: tts.currentIndex, coordinator: context.coordinator)

        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        // no-op
    }

    static func dismantleUIView(_ uiView: PDFView, coordinator: Coordinator) {
        // Clear any outstanding annotations
        if let doc = uiView.document {
            for i in 0..<doc.pageCount {
                guard let page = doc.page(at: i) else { continue }
                for ann in page.annotations where ann.userName == "tts_sentence" || ann.userName == "tts_word" {
                    page.removeAnnotation(ann)
                }
            }
        }
        // Cancel any observers
        coordinator.cancellables.removeAll()
    }

    private func clearAnnotations(in doc: PDFDocument, userName: String) {
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            for annotation in page.annotations where annotation.userName == userName {
                page.removeAnnotation(annotation)
            }
        }
    }

    private func clearAllHighlights(in pdfView: PDFView, coordinator: Coordinator) {
        if let doc = pdfView.document {
            clearAnnotations(in: doc, userName: "tts_sentence")
            clearAnnotations(in: doc, userName: "tts_word")
        }
        coordinator.currentSentenceHighlight = nil
        coordinator.currentWordHighlight = nil
        coordinator.currentSentenceAnnotations.removeAll()
        coordinator.sentencePageCache.removeAll()
        coordinator.highlightVersion &+= 1
    }

    // MARK: - Sentence highlight (yellow) with page caching
    private func highlightSentence(in pdfView: PDFView,
                                   index: Int,
                                   coordinator: Coordinator) {
        guard let doc = pdfView.document else { return }

        // Ensure only current sentence is highlighted: clear all previous sentence highlights
        clearAnnotations(in: doc, userName: "tts_sentence")
        // Also clear any lingering word highlights when sentence changes
        clearAnnotations(in: doc, userName: "tts_word")

        coordinator.currentSentenceHighlight = nil
        coordinator.currentWordHighlight = nil
        coordinator.currentSentenceAnnotations = []

        coordinator.highlightVersion &+= 1
        let version = coordinator.highlightVersion

        guard tts.sentences.indices.contains(index) else { return }
        let sentence = tts.sentences[index]

        // Remove previous sentence highlight
        if let prev = coordinator.currentSentenceHighlight {
            prev.page?.removeAnnotation(prev)
            coordinator.currentSentenceHighlight = nil
        }

        // Use cached location if available
        if let loc = coordinator.sentencePageCache[index], let pageText = loc.page.string {
            guard coordinator.highlightVersion == version else { return }
            applySentenceHighlight(on: loc.page,
                                   pageText: pageText,
                                   range: loc.rangeInPageText,
                                   coordinator: coordinator,
                                   pdfView: pdfView)
            return
        }

        // Find sentence once and cache the page + original range
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i), let pageText = page.string else { continue }

            // Try normalized search mapped back to original indices
            if let range = normalizedRangeInOriginal(haystack: pageText, needle: sentence) {
                let tight = shrinkRangeToSentence(in: pageText, candidate: range, sentence: sentence)
                coordinator.sentencePageCache[index] = Coordinator.SentenceLocation(page: page, rangeInPageText: tight)
                guard coordinator.highlightVersion == version else { return }
                applySentenceHighlight(on: page,
                                       pageText: pageText,
                                       range: tight,
                                       coordinator: coordinator,
                                       pdfView: pdfView)
                break
            }

            // Fallback token-span matching (already returns original-text range)
            if let fallbackRange = fallbackTokenSpanRange(sentence: sentence, text: pageText) {
                #if DEBUG
                print("[PDF] Fallback token span used for sentence index \(index)")
                #endif
                // Try to refine the fallback span using normalized search limited to the span
                let refined = normalizedRangeInOriginal(haystack: pageText, needle: sentence, searchRange: fallbackRange) ?? fallbackRange
                let tight = shrinkRangeToSentence(in: pageText, candidate: refined, sentence: sentence)
                coordinator.sentencePageCache[index] = Coordinator.SentenceLocation(page: page, rangeInPageText: tight)
                guard coordinator.highlightVersion == version else { return }
                applySentenceHighlight(on: page,
                                       pageText: pageText,
                                       range: tight,
                                       coordinator: coordinator,
                                       pdfView: pdfView)
                break
            }

            // Literal range search as last resort
            if let range = pageText.range(of: sentence) {
                let tight = shrinkRangeToSentence(in: pageText, candidate: range, sentence: sentence)
                coordinator.sentencePageCache[index] = Coordinator.SentenceLocation(page: page, rangeInPageText: tight)
                guard coordinator.highlightVersion == version else { return }
                applySentenceHighlight(on: page,
                                       pageText: pageText,
                                       range: tight,
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
        guard range.lowerBound >= pageText.startIndex, range.upperBound <= pageText.endIndex, range.lowerBound < range.upperBound else { return }
        let nsRange = NSRange(range, in: pageText)
        guard let selection = page.selection(for: nsRange) else { return }

        // Remove previously tracked sentence annotations explicitly
        for ann in coordinator.currentSentenceAnnotations {
            ann.page?.removeAnnotation(ann)
        }
        coordinator.currentSentenceAnnotations.removeAll()

        // Also remove any leftover sentence annotations on this page (defensive)
        for annotation in page.annotations where annotation.userName == "tts_sentence" {
            page.removeAnnotation(annotation)
        }

        // Create per-line highlights for better fidelity on wrapped text
        let lineSelections = selection.selectionsByLine()
        var created: [PDFAnnotation] = []
        for lineSel in lineSelections {
            let lineBounds = lineSel.bounds(for: page)
            guard !lineBounds.isEmpty else { continue }
            let ann = PDFAnnotation(bounds: lineBounds, forType: PDFAnnotationSubtype.highlight, withProperties: nil)
            ann.color = UIColor.darkGray.withAlphaComponent(0.18)
            ann.userName = "tts_sentence"
            page.addAnnotation(ann)
            created.append(ann)
        }

        // Track the created annotations
        coordinator.currentSentenceAnnotations = created
        coordinator.currentSentenceHighlight = created.first

        pdfView.go(to: selection)
    }

    // MARK: - Word highlight (orange) within the current sentence/page
    private func highlightWord(in pdfView: PDFView,
                               word: String,
                               sentence: String,
                               coordinator: Coordinator) {
        guard !word.isEmpty else { return }
        guard let doc = pdfView.document else { return }
        let version = coordinator.highlightVersion

        // Remove previous word highlight (keep sentence highlight)
        if let prev = coordinator.currentWordHighlight {
            prev.page?.removeAnnotation(prev)
            coordinator.currentWordHighlight = nil
        }

        let idx = tts.currentIndex
        guard let loc = coordinator.sentencePageCache[idx],
              let pageText = loc.page.string else { return }
        let page = loc.page

        let sentenceRange = loc.rangeInPageText

        // Normalize word and utterance for occurrence counting
        let normWord = normalizeForMatching(word)
        guard !normWord.isEmpty else { return }
        guard !normWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let wordRegex = buildWordRegex(word)

        // Build normalized sentence text
        let sentenceTextOnPage = String(pageText[sentenceRange])
        let normSentenceTextOnPage = normalizeForMatching(sentenceTextOnPage)

        // Build local map: original string indices to normalized string indices
        // We want to map normalized indices back to original indices later
        // We'll build an array mapping each normalized character index to original character index
        func indexMapOriginalToNormalized(original: String) -> [String.Index] {
            var map: [String.Index] = []
            var origIdx = original.startIndex
            for ch in normSentenceTextOnPage {
                while origIdx < original.endIndex {
                    let origChar = original[origIdx]
                    if shouldSkipChar(origChar) {
                        origIdx = original.index(after: origIdx)
                        continue
                    }
                    let normOrigChar = normalizeChar(origChar)
                    if normOrigChar == ch {
                        map.append(origIdx)
                        origIdx = original.index(after: origIdx)
                        break
                    } else {
                        origIdx = original.index(after: origIdx)
                    }
                }
            }
            return map
        }
        let localMap = indexMapOriginalToNormalized(original: sentenceTextOnPage)
        guard localMap.count == normSentenceTextOnPage.count else { return }
        // Defensive: if map length doesn't match normalized sentence length, fallback to empty map
        // But that should be rare

        // Compute spokenIndex from tts.currentWordRange in normalized utterance
        let normUtter = normalizeForMatching(tts.currentSentenceText)
        let spokenIndex: Int = {
            guard let range = tts.currentWordRange else { return 0 }
            let utter = normUtter
            let start = utter.startIndex
            if let startIdx = Range(range, in: utter)?.lowerBound {
                let prefix = String(utter[start..<startIdx])
                // Count case-insensitive occurrences of normWord in the prefix
                var count = 0
                var searchRange: Range<String.Index>? = prefix.startIndex..<prefix.endIndex
                while let r = prefix.range(of: normWord, options: [.caseInsensitive], range: searchRange) {
                    count += 1
                    searchRange = r.upperBound..<prefix.endIndex
                }
                return count
            }
            return 0
        }()

        // Find all match ranges (in normalized coordinates) using wordRegex if available
        var matches: [Range<String.Index>] = []
        if let regex = wordRegex {
            let nsNormSentence = normSentenceTextOnPage as NSString
            let fullRange = NSRange(location: 0, length: nsNormSentence.length)
            regex.enumerateMatches(in: normSentenceTextOnPage, options: [], range: fullRange) { result, _, _ in
                if let r = result?.range, r.location != NSNotFound, r.length > 0 {
                    let start = String.Index(utf16Offset: r.location, in: normSentenceTextOnPage)
                    let end = String.Index(utf16Offset: r.location + r.length, in: normSentenceTextOnPage)
                    matches.append(start..<end)
                }
            }
        } else {
            // fallback to .range(of:) loop on normSentenceTextOnPage
            var searchRange: Range<String.Index>? = normSentenceTextOnPage.startIndex..<normSentenceTextOnPage.endIndex
            while let r = normSentenceTextOnPage.range(of: normWord, options: [.caseInsensitive], range: searchRange) {
                matches.append(r)
                searchRange = r.upperBound..<normSentenceTextOnPage.endIndex
            }
        }

        // Select match to use: spokenIndex-th occurrence if exists, otherwise nearest plausible match
        var chosenRange: Range<String.Index>?
        if spokenIndex < matches.count {
            chosenRange = matches[spokenIndex]
        } else if !matches.isEmpty {
            // spokenIndex beyond last occurrence, pick last match
            chosenRange = matches.last
        } else {
            // no matches, no highlight
            chosenRange = nil
        }

        guard let chosen = chosenRange else { return }

        // Map chosen normalized range back to original sentenceTextOnPage indices using localMap
        // Defensive: check localMap length and UTF16 offsets
        let normStartOffset = chosen.lowerBound.utf16Offset(in: normSentenceTextOnPage)
        let normEndOffset = chosen.upperBound.utf16Offset(in: normSentenceTextOnPage)
        guard normStartOffset < localMap.count, normEndOffset <= localMap.count, normStartOffset < normEndOffset else {
            return
        }
        let origStartIdx = localMap[normStartOffset]
        let origEndIdx = localMap[normEndOffset - 1]

        // Create range in sentenceTextOnPage for original highlight
        let origRangeEnd = sentenceTextOnPage.index(after: origEndIdx)
        let origRange = origStartIdx..<origRangeEnd

        // Map original sentenceTextOnPage range to full pageText range
        let absRangeStart = pageText.index(sentenceRange.lowerBound, offsetBy: sentenceTextOnPage.distance(from: sentenceTextOnPage.startIndex, to: origRange.lowerBound))
        let absRangeEnd = pageText.index(sentenceRange.lowerBound, offsetBy: sentenceTextOnPage.distance(from: sentenceTextOnPage.startIndex, to: origRange.upperBound))
        guard absRangeStart < absRangeEnd, absRangeEnd <= pageText.endIndex else { return }

        // Create selection for word on page and add highlight
        let nsWordRange = NSRange(absRangeStart..<absRangeEnd, in: pageText)
        if let selection = page.selection(for: nsWordRange) {
            guard coordinator.highlightVersion == version else { return }
            let bounds = selection.bounds(for: page)
            let highlight = PDFAnnotation(bounds: bounds, forType: PDFAnnotationSubtype.highlight, withProperties: nil)
            highlight.color = UIColor.systemBlue.withAlphaComponent(0.30)
            highlight.userName = "tts_word"
            page.addAnnotation(highlight)
            coordinator.currentWordHighlight = highlight
        }
    }

    private func intersects(_ a: CGRect, _ b: CGRect) -> Bool {
        return a.intersects(b)
    }

    // MARK: - Normalization helpers

    private func normalizeForMatching(_ s: String) -> String {
        // Replace newlines with spaces, remove hyphen + newline splits, collapse spaces,
        // strip soft hyphen (U+00AD), zero-width chars, and normalize quotes and NBSP.
        var out = s
        out = out.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        out = out.replacingOccurrences(of: "-\n", with: "") // dehyphenate line-break hyphen
        out = out.replacingOccurrences(of: "\u{00AD}", with: "") // soft hyphen
        out = out.replacingOccurrences(of: "\u{200B}", with: "") // zero-width space
        out = out.replacingOccurrences(of: "\u{200C}", with: "") // zero-width non-joiner
        out = out.replacingOccurrences(of: "\u{200D}", with: "") // zero-width joiner
        out = out.replacingOccurrences(of: "\u{00A0}", with: " ") // NBSP to space
        // curly quotes to straight
        out = out.replacingOccurrences(of: "\u{2018}", with: "'")
        out = out.replacingOccurrences(of: "\u{2019}", with: "'")
        out = out.replacingOccurrences(of: "\u{201C}", with: "\"")
        out = out.replacingOccurrences(of: "\u{201D}", with: "\"")
        // newlines to spaces and collapse
        out = out.replacingOccurrences(of: "\n", with: " ")
        out = out.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Tokenize to alphanumerics for fallback matching
    private func tokenizeWords(_ s: String) -> [String] {
        let norm = normalizeForMatching(s)
        let comps = norm.components(separatedBy: CharacterSet.alphanumerics.inverted)
        return comps.filter { !$0.isEmpty }
    }

    // MARK: - Helpers for normalized searching and fallback token span matching

    private func normalizedRangeInOriginal(haystack: String, needle: String) -> Range<String.Index>? {
        let normHaystack = normalizeForMatching(haystack)
        let normNeedle = normalizeForMatching(needle)
        guard !normNeedle.isEmpty else { return nil }

        // Build map from normalized indices -> original indices
        var normToOrig: [String.Index] = []
        normToOrig.reserveCapacity(normHaystack.count)

        var origIdx = haystack.startIndex
        for ch in normHaystack {
            while origIdx < haystack.endIndex {
                let origChar = haystack[origIdx]
                if shouldSkipChar(origChar) {
                    origIdx = haystack.index(after: origIdx)
                    continue
                }
                if normalizeChar(origChar) == ch {
                    normToOrig.append(origIdx)
                    origIdx = haystack.index(after: origIdx)
                    break
                } else {
                    origIdx = haystack.index(after: origIdx)
                }
            }
        }

        guard let normRange = normHaystack.range(of: normNeedle) else { return nil }

        let startOffset = normRange.lowerBound.utf16Offset(in: normHaystack)
        let endOffset = normRange.upperBound.utf16Offset(in: normHaystack)
        guard startOffset < normToOrig.count, endOffset <= normToOrig.count, startOffset < endOffset else {
            return nil
        }

        let origStart = normToOrig[startOffset]
        let origEndInclusive = normToOrig[endOffset - 1]
        let origEnd = haystack.index(after: origEndInclusive)
        return origStart..<origEnd
    }

    private func normalizedRangeInOriginal(haystack: String, needle: String, searchRange: Range<String.Index>) -> Range<String.Index>? {
        let sub = String(haystack[searchRange])
        guard let subRange = normalizedRangeInOriginal(haystack: sub, needle: needle) else { return nil }
        let lower = haystack.index(searchRange.lowerBound, offsetBy: sub.distance(from: sub.startIndex, to: subRange.lowerBound))
        let upper = haystack.index(searchRange.lowerBound, offsetBy: sub.distance(from: sub.startIndex, to: subRange.upperBound))
        return lower..<upper
    }

    private func fallbackTokenSpanRange(sentence: String, text: String) -> Range<String.Index>? {
        let tokens = tokenizeWords(sentence)
        guard tokens.count >= 2 else { return nil }

        let normText = normalizeForMatching(text)
        let normTokens = tokens.map { normalizeForMatching($0) }

        guard let firstToken = normTokens.first, let lastToken = normTokens.last else { return nil }

        guard let firstRange = normText.range(of: firstToken) else { return nil }

        // Limit window to 500 chars after first token start
        let searchLimitIndex = normText.index(firstRange.lowerBound, offsetBy: 500, limitedBy: normText.endIndex) ?? normText.endIndex
        let searchRange = firstRange.upperBound..<searchLimitIndex

        guard let lastRange = normText.range(of: lastToken, options: [], range: searchRange) else { return nil }

        // Check span length reasonable <= 5000 chars
        let spanLength = normText.distance(from: firstRange.lowerBound, to: lastRange.upperBound)
        guard spanLength <= 5000 else { return nil }

        // Map normalized range back to original text
        // We'll find approximate mapping by searching original text for first and last tokens

        guard let origFirstRange = text.range(of: tokens.first!, options: [.caseInsensitive]) else { return nil }
        // Search last token starting after origFirstRange.lowerBound, within 5000 chars
        let origSearchLimitIndex = text.index(origFirstRange.lowerBound, offsetBy: 5000, limitedBy: text.endIndex) ?? text.endIndex
        let origSearchRange = origFirstRange.lowerBound..<origSearchLimitIndex
        guard let origLastRange = text.range(of: tokens.last!, options: [.caseInsensitive], range: origSearchRange) else { return nil }

        return origFirstRange.lowerBound..<origLastRange.upperBound
    }

    // Shrink an oversized match to the tightest span using multiple anchor tokens and a length cap
    private func shrinkRangeToSentence(in text: String, candidate: Range<String.Index>, sentence: String) -> Range<String.Index> {
        let normSentence = normalizeForMatching(sentence)
        let normLen = max(1, normSentence.count)
        let cap = max(20, Int((Double(normLen) * 1.5).rounded())) // 1.5x normalized sentence length, min 20

        let allTokens = tokenizeWords(sentence)
        if allTokens.isEmpty { return candidate }

        // Prefer longer tokens as anchors; if none, use all tokens
        let longTokens = allTokens.filter { $0.count >= 4 }
        let base = longTokens.isEmpty ? allTokens : longTokens

        // Pick up to 5 anchors spread across the sentence
        let total = base.count
        let desired = min(5, total)
        var anchors: [String] = []
        if desired == total {
            anchors = base
        } else {
            for i in 0..<desired {
                let idx = Int(Double(i) * Double(total - 1) / Double(max(1, desired - 1)))
                anchors.append(base[idx])
            }
        }

        // Search within candidate window for anchors in order
        let window = String(text[candidate])
        var currentStart = window.startIndex
        var firstLower: String.Index?
        var lastUpper: String.Index?
        for a in anchors {
            if let r = window.range(of: a, options: [.caseInsensitive], range: currentStart..<window.endIndex) {
                if firstLower == nil { firstLower = r.lowerBound }
                lastUpper = r.upperBound
                currentStart = r.upperBound
            } else {
                // Skip missing anchor; continue with the next one
                continue
            }
        }

        // If anchors failed, fallback to first/last token strategy
        if firstLower == nil || lastUpper == nil {
            guard let firstTok = allTokens.first else { return candidate }
            var lastTok: String = firstTok
            if let lt = allTokens.last { lastTok = lt }
            guard let f = window.range(of: firstTok, options: [.caseInsensitive]) else { return candidate }
            let tail = f.lowerBound..<window.endIndex
            guard let l = window.range(of: lastTok, options: [.caseInsensitive], range: tail) else { return candidate }
            firstLower = f.lowerBound
            lastUpper = l.upperBound
        }

        guard let fl = firstLower, let lu = lastUpper else { return candidate }

        // Map back to absolute indices
        let absLower = text.index(candidate.lowerBound, offsetBy: window.distance(from: window.startIndex, to: fl))
        var absUpper = text.index(candidate.lowerBound, offsetBy: window.distance(from: window.startIndex, to: lu))

        // Enforce cap and candidate bounds
        let span = text.distance(from: absLower, to: absUpper)
        if span > cap {
            if let limited = text.index(absLower, offsetBy: cap, limitedBy: candidate.upperBound) {
                absUpper = limited
            } else {
                absUpper = candidate.upperBound
            }
        }

        guard absLower >= candidate.lowerBound, absUpper <= candidate.upperBound, absLower < absUpper else { return candidate }
        return absLower..<absUpper
    }

    private func shouldSkipChar(_ c: Character) -> Bool {
        let scalars = c.unicodeScalars
        for scalar in scalars {
            switch scalar.value {
            case 0x00AD, // soft hyphen
                 0x200B, // zero-width space
                 0x200C, // zero-width non-joiner
                 0x200D: // zero-width joiner
                return true
            default:
                continue
            }
        }
        return false
    }

    private func normalizeChar(_ c: Character) -> Character {
        switch c {
        case "\u{2018}", "\u{2019}": return "'"
        case "\u{201C}", "\u{201D}": return "\""
        case "\u{00A0}": return " "
        case "\n", "\r": return " "
        default:
            return c
        }
    }

    // MARK: - Added helper for building word regex with boundaries
    private func buildWordRegex(_ word: String) -> NSRegularExpression? {
        let norm = normalizeForMatching(word)
        guard !norm.isEmpty else { return nil }
        // Escape regex special chars
        let escaped = NSRegularExpression.escapedPattern(for: norm)
        // Use word boundaries; fallback to simple pattern if boundaries unsupported
        let pattern = "\\b" + escaped + "\\b"
        return try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }
}

