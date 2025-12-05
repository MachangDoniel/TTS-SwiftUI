//
//  TextHighlightView.swift
//  TTS
//
//  Created by Doniel Tripura on 11/15/25.
//
import SwiftUI

// MARK: - Read-only Accurate Highlight (Word + Sentence)

struct ReadOnlyAccurateHighlight: View {
    let fullText: String
    @ObservedObject var tts: TTSPlayer
    
    var body: some View {
        ScrollView {
            Text(makeHighlightedAttributedString())
                .font(.system(size: 18))
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func makeHighlightedAttributedString() -> AttributedString {
        var attr = AttributedString(fullText)
        
        // Only highlight when actively playing, not when paused or idle
        guard tts.state == .playing,
              tts.currentIndex < tts.sentences.count,
              tts.currentIndex < tts.wordTokens.count else {
            return attr
        }
        
        let currentSentence = tts.sentences[tts.currentIndex]
        let sentenceTokens = tts.wordTokens[tts.currentIndex]
        
        // Find sentence range in full text
        guard let sentenceRange = findSentenceRangeInFullText(
            sentence: currentSentence,
            fullText: fullText,
            sentenceIndex: tts.currentIndex
        ) else {
            return attr
        }
        
        // Highlight current sentence with subtle background
        if let sentenceCharRange = nsRangeToAttributedStringRange(sentenceRange, in: attr) {
            attr[sentenceCharRange].backgroundColor = Color.myPrimaryColor.opacity(0.15)
        }
        
        // Highlight current word with prominent style - only if we have valid word info
        if let wordIndex = tts.currentWordIndexInSentence,
           wordIndex >= 0,
           wordIndex < sentenceTokens.count,
           !tts.currentWordInSentence.isEmpty {
            
            // Use the token from currentWordToken if available, otherwise from array
            let wordToken: WordToken
            if let currentToken = tts.currentWordToken,
               currentToken.index == wordIndex {
                wordToken = currentToken
            } else {
                wordToken = sentenceTokens[wordIndex]
            }
            
            // Validate word token range is within sentence
            guard wordToken.range.location >= 0,
                  wordToken.range.location + wordToken.range.length <= currentSentence.count else {
                return attr
            }
            
            // Calculate absolute word range in full text
            let absoluteWordLocation = sentenceRange.location + wordToken.range.location
            let absoluteWordRange = NSRange(
                location: absoluteWordLocation,
                length: wordToken.range.length
            )
            
            // Ensure range is within bounds of full text
            guard absoluteWordLocation >= 0,
                  absoluteWordLocation + wordToken.range.length <= (fullText as NSString).length,
                  let wordCharRange = nsRangeToAttributedStringRange(absoluteWordRange, in: attr) else {
                return attr
            }
            
            // Apply prominent word highlighting
            attr[wordCharRange].backgroundColor = Color.myPrimaryColor.opacity(0.5)
            attr[wordCharRange].font = .system(size: 18, weight: .regular)
        }
        
        return attr
    }
    
    private func findSentenceRangeInFullText(sentence: String, fullText: String, sentenceIndex: Int) -> NSRange? {
        let fullTextNSString = fullText as NSString
        let normalizedFullText = fullText.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let normalizedFullTextNSString = normalizedFullText as NSString
        
        // Build up to the current sentence by finding all previous sentences sequentially
        var currentOffset = 0
        
        for i in 0...sentenceIndex {
            guard i < tts.sentences.count else { break }
            
            let currentSentence = tts.sentences[i].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !currentSentence.isEmpty else { continue }
            
            let normalizedSentence = currentSentence.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            
            let remainingLength = normalizedFullTextNSString.length - currentOffset
            guard remainingLength > 0 else { break }
            
            let searchRange = NSRange(location: currentOffset, length: remainingLength)
            let range = normalizedFullTextNSString.range(
                of: normalizedSentence,
                options: [],
                range: searchRange
            )
            
            if range.location == NSNotFound {
                if i == sentenceIndex {
                    return nil
                }
                continue
            }
            
            if i == sentenceIndex {
                // Map normalized range back to original text
                let normalizedStart = range.location
                let estimatedOriginalOffset = min(normalizedStart, fullTextNSString.length - 1)
                let originalSearchRange = NSRange(
                    location: estimatedOriginalOffset,
                    length: fullTextNSString.length - estimatedOriginalOffset
                )
                
                let originalRange = fullTextNSString.range(
                    of: currentSentence,
                    options: [],
                    range: originalSearchRange
                )
                
                if originalRange.location != NSNotFound {
                    return originalRange
                }
                
                // Fallback
                if normalizedStart < fullTextNSString.length {
                    let mappedLength = min(range.length, fullTextNSString.length - normalizedStart)
                    return NSRange(location: normalizedStart, length: mappedLength)
                }
                
                return nil
            }
            
            currentOffset = range.location + range.length
        }
        
        return nil
    }
    
    private func nsRangeToAttributedStringRange(_ nsRange: NSRange, in attr: AttributedString) -> Range<AttributedString.Index>? {
        guard nsRange.location != NSNotFound,
              nsRange.location < attr.characters.count,
              nsRange.location + nsRange.length <= attr.characters.count else {
            return nil
        }
        
        let startIndex = attr.characters.index(attr.characters.startIndex, offsetBy: nsRange.location)
        let endIndex = attr.characters.index(startIndex, offsetBy: nsRange.length)
        return startIndex..<endIndex
    }
}

// MARK: - Editable Sentence Highlight (Sentence Only)

struct EditableSentenceHighlight: View {
    let fullText: String
    @ObservedObject var tts: TTSPlayer
    
    @State private var sentenceFrame: CGRect? = nil
    
    private var positionToken: String {
        "\(tts.currentIndex)"
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Color.clear
                
                if let frame = sentenceFrame {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.myPrimaryColor.opacity(0.2))
                        .frame(width: frame.width, height: frame.height)
                        .offset(x: frame.minX, y: frame.minY)
                        .animation(.easeInOut(duration: 0.15), value: frame)
                }
            }
            .onChange(of: positionToken) { _ in
                DispatchQueue.main.async {
                    sentenceFrame = calculateSentenceFrame(in: geometry.size)
                }
            }
            .onAppear {
                sentenceFrame = calculateSentenceFrame(in: geometry.size)
            }
        }
    }
    
    private func calculateSentenceFrame(in size: CGSize) -> CGRect? {
        // Only highlight when actively playing, not when paused or idle
        guard tts.state == .playing,
              !fullText.isEmpty,
              tts.currentIndex < tts.sentences.count else {
            return nil
        }
        
        let currentSentence = tts.sentences[tts.currentIndex]
        
        // Find the sentence's position in the full text
        guard let sentenceRange = findSentenceRangeInFullText(
            sentence: currentSentence,
            fullText: fullText,
            sentenceIndex: tts.currentIndex
        ) else {
            return nil
        }
        
        // Use NSLayoutManager to calculate the sentence's frame
        let font = UIFont.systemFont(ofSize: 18)
        let textStorage = NSTextStorage(string: fullText, attributes: [.font: font])
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: size)
        textContainer.lineFragmentPadding = 10  // Match TextEditor horizontal padding
        textContainer.maximumNumberOfLines = 0
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        
        // Get the glyph range for the sentence
        let glyphRange = layoutManager.glyphRange(forCharacterRange: sentenceRange, actualCharacterRange: nil)
        guard glyphRange.location != NSNotFound else {
            return nil
        }
        
        // Get the bounding rect for the sentence (may span multiple lines)
        var sentenceRect = CGRect.zero
        var effectiveRange = NSRange()
        var currentRange = glyphRange
        
        while currentRange.location < NSMaxRange(glyphRange) {
            let lineRect = layoutManager.boundingRect(forGlyphRange: currentRange, in: textContainer)
            if sentenceRect == .zero {
                sentenceRect = lineRect
            } else {
                sentenceRect = sentenceRect.union(lineRect)
            }
            let remainingRange = NSRange(location: NSMaxRange(currentRange), length: NSMaxRange(glyphRange) - NSMaxRange(currentRange))
            if remainingRange.length > 0 {
                layoutManager.lineFragmentRect(forGlyphAt: NSMaxRange(currentRange), effectiveRange: &effectiveRange)
                currentRange = NSRange(location: NSMaxRange(currentRange), length: min(effectiveRange.length, remainingRange.length))
            } else {
                break
            }
        }
        
        return sentenceRect.isEmpty ? nil : sentenceRect
    }
    
    private func findSentenceRangeInFullText(sentence: String, fullText: String, sentenceIndex: Int) -> NSRange? {
        let fullTextNSString = fullText as NSString
        let normalizedFullText = fullText.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        let normalizedFullTextNSString = normalizedFullText as NSString
        
        var currentOffset = 0
        
        for i in 0...sentenceIndex {
            guard i < tts.sentences.count else { break }
            
            let currentSentence = tts.sentences[i].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !currentSentence.isEmpty else { continue }
            
            let normalizedSentence = currentSentence.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            
            let remainingLength = normalizedFullTextNSString.length - currentOffset
            guard remainingLength > 0 else { break }
            
            let searchRange = NSRange(location: currentOffset, length: remainingLength)
            let range = normalizedFullTextNSString.range(
                of: normalizedSentence,
                options: [],
                range: searchRange
            )
            
            if range.location == NSNotFound {
                if i == sentenceIndex {
                    return nil
                }
                continue
            }
            
            if i == sentenceIndex {
                let normalizedStart = range.location
                let estimatedOriginalOffset = min(normalizedStart, fullTextNSString.length - 1)
                let originalSearchRange = NSRange(
                    location: estimatedOriginalOffset,
                    length: fullTextNSString.length - estimatedOriginalOffset
                )
                
                let originalRange = fullTextNSString.range(
                    of: currentSentence,
                    options: [],
                    range: originalSearchRange
                )
                
                if originalRange.location != NSNotFound {
                    return originalRange
                }
                
                if normalizedStart < fullTextNSString.length {
                    let mappedLength = min(range.length, fullTextNSString.length - normalizedStart)
                    return NSRange(location: normalizedStart, length: mappedLength)
                }
                
                return nil
            }
            
            currentOffset = range.location + range.length
        }
        
        return nil
    }
}

