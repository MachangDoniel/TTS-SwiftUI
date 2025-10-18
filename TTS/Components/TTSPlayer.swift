//
//  TTSPlayer.swift
//  TTS
//
//  Created by Doniel Tripura on 10/5/25.
//  Updated for sentence + word tracking on 10/12/25.
//

import Foundation
import AVFoundation
import Combine

/// A text-to-speech player that reads text sentence-by-sentence,
/// and also tracks the currently spoken word within the sentence.
class TTSPlayer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {

    // MARK: - Published Properties

    /// All sentences extracted from the input text
    @Published var sentences: [String] = []

    /// Current sentence index being spoken
    @Published var currentIndex: Int = 0

    /// Indicates whether the synthesizer is currently speaking
    @Published var isSpeaking: Bool = false

    /// Indicates whether speech is currently paused
    @Published var isPaused: Bool = false

    @Published var hasActiveItem: Bool = false
    @Published var progress: Double = 0.0
    @Published var currentTitle: String? = nil

    /// The URL of the current source being read (PDF, TXT, etc.)
    @Published var currentURL: URL? = nil

    /// The full sentence currently being read
    @Published var currentSentenceText: String = ""

    /// The current word being spoken (within the current sentence)
    @Published var currentWordInSentence: String = ""

    /// The range of the current word in the current sentence
    @Published var currentWordRange: NSRange? = nil

    // MARK: - Properties
    var synthesizer = AVSpeechSynthesizer()

    // MARK: - Init
    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Public Methods

    /// Starts reading the full text from the beginning.
    func startReading(_ text: String) {
        stop()
        hasActiveItem = true
        progress = 0.0
        sentences = splitIntoSentences(text)
        currentIndex = 0
        speakCurrentSentence()
    }

    /// Pauses or resumes speech depending on current state.
    func togglePlayPause() {
        if isSpeaking {
            if isPaused {
                synthesizer.continueSpeaking()
                isPaused = false
            } else {
                synthesizer.pauseSpeaking(at: .immediate)
                isPaused = true
            }
        } else {
            speakCurrentSentence()
        }
    }

    func pause() {
        synthesizer.pauseSpeaking(at: .immediate)
        isPaused = true
    }

    func resume() {
        synthesizer.continueSpeaking()
        isPaused = false
    }

    /// Stops all speech immediately.
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        hasActiveItem = false
        progress = 0.0
        isSpeaking = false
        isPaused = false
        currentWordInSentence = ""
        currentSentenceText = ""
        sentences = []
        currentIndex = 0
    }

    /// Moves to the next sentence (if available).
    func nextSentence() {
        guard currentIndex < sentences.count - 1 else { return }
        stop()
        currentIndex += 1
        speakCurrentSentence()
    }

    /// Moves to the previous sentence (if available).
    func previousSentence() {
        guard currentIndex > 0 else { return }
        stop()
        currentIndex -= 1
        speakCurrentSentence()
    }

    // MARK: - Private Helpers

    /// Splits text into sentences but also preserves headings (lines without trailing punctuation)
    private func splitIntoSentencesPreservingHeadings(_ text: String) -> [String] {
        // 1) Normalize newlines
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
                             .replacingOccurrences(of: "\r", with: "\n")
        // 2) Break into raw lines
        let rawLines = normalized.components(separatedBy: "\n")

        // Heuristics
        let bulletPrefixes = ["- ", "• ", "* ", "– ", "— "]
        let numberedRegex = try? NSRegularExpression(pattern: "^\n?\\s*\\d+[\\.)]\\s+", options: [])
        let headingColonSuffix: Character = ":"
        let sentencePattern = "(?<!\\b(?:Mr|Mrs|Ms|Dr|Prof|Sr|Jr|St|vs|No|Fig|e|i)\\.)(?<=[.!?])\\s+"
        let sentenceRegex = try? NSRegularExpression(pattern: sentencePattern, options: [.caseInsensitive])

        func isBulletOrNumbered(_ s: String) -> Bool {
            if bulletPrefixes.first(where: { s.hasPrefix($0) }) != nil { return true }
            if let re = numberedRegex, re.firstMatch(in: s, options: [], range: NSRange(location: 0, length: (s as NSString).length)) != nil {
                return true
            }
            return false
        }

        func isLikelyHeading(_ s: String) -> Bool {
            let trimmed = s.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return false }
            if trimmed.last == headingColonSuffix { return true }
            let punctSet = CharacterSet(charactersIn: ".!?")
            if let last = trimmed.unicodeScalars.last, punctSet.contains(last) == false {
                let isShort = trimmed.count <= 80
                let words = trimmed.split(separator: " ")
                let titleCasedTokens = words.filter { token in
                    guard let first = token.first else { return false }
                    return String(first).uppercased() == String(first) && token.dropFirst().allSatisfy { $0.isLowercase || !$0.isLetter }
                }
                if isShort && titleCasedTokens.count >= max(1, words.count / 2) {
                    return true
                }
            }
            return false
        }

        // 3) Group consecutive non-heading, non-bullet lines into paragraphs (join with spaces)
        var paragraphs: [String] = []
        var currentPara: [String] = []

        func flushPara() {
            if !currentPara.isEmpty {
                let joined = currentPara.joined(separator: " ")
                paragraphs.append(joined)
                currentPara.removeAll()
            }
        }

        for raw in rawLines {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty {
                // Paragraph break
                flushPara()
                continue
            }
            if isBulletOrNumbered(line) || isLikelyHeading(line) {
                // Finish any running paragraph, then add this as standalone
                flushPara()
                paragraphs.append(line)
                continue
            }
            // Otherwise, part of the current paragraph (do not treat newline as sentence boundary)
            currentPara.append(line)
        }
        // Flush tail
        flushPara()

        // 4) Split paragraphs into sentences (headings/bullets will be single-item paragraphs)
        var results: [String] = []
        for para in paragraphs {
            // If paragraph looks like a heading/bullet, keep as-is
            if isBulletOrNumbered(para) || isLikelyHeading(para) {
                results.append(para)
                continue
            }

            // Use regex to split sentences while keeping punctuation
            if let re = sentenceRegex {
                let ns = para as NSString
                let range = NSRange(location: 0, length: ns.length)
                var lastIndex = 0
                re.enumerateMatches(in: para, options: [], range: range) { match, _, _ in
                    guard let match = match else { return }
                    let end = match.range.location + match.range.length
                    let sentence = ns.substring(with: NSRange(location: lastIndex, length: end - lastIndex)).trimmingCharacters(in: .whitespaces)
                    if !sentence.isEmpty { results.append(sentence) }
                    lastIndex = end
                }
                if lastIndex < ns.length {
                    let tail = ns.substring(from: lastIndex).trimmingCharacters(in: .whitespaces)
                    if !tail.isEmpty { results.append(tail) }
                }
            } else {
                // Fallback character-walk
                var buffer = ""
                for ch in para {
                    buffer.append(ch)
                    if ".!?".contains(ch) {
                        let sentence = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !sentence.isEmpty { results.append(sentence) }
                        buffer.removeAll(keepingCapacity: true)
                    }
                }
                let tail = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
                if !tail.isEmpty { results.append(tail) }
            }
        }

        // 5) Normalize whitespaces
        let collapsed = results.map { $0.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression) }
        return collapsed.filter { !$0.isEmpty }
    }

    /// Backwards-compatible name used by the rest of the class
    private func splitIntoSentences(_ text: String) -> [String] {
        return splitIntoSentencesPreservingHeadings(text)
    }

    /// Speaks the current sentence aloud.
    private func speakCurrentSentence() {
        guard sentences.indices.contains(currentIndex) else { return }

        let sentence = sentences[currentIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        currentSentenceText = sentence

        let utterance = AVSpeechUtterance(string: sentence)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)

        isSpeaking = true
        isPaused = false
        progress = sentences.isEmpty ? 0.0 : Double(currentIndex) / Double(max(1, sentences.count))

        print("🔊 Reading sentence \(currentIndex + 1)/\(sentences.count): \(sentence)")
    }

    // MARK: - AVSpeechSynthesizerDelegate

    /// Called continuously while a sentence is being read — tracks word progress.
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           willSpeakRangeOfSpeechString characterRange: NSRange,
                           utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.currentWordRange = characterRange
            let nsText = utterance.speechString as NSString
            self.currentWordInSentence = nsText.substring(with: characterRange)
        }
    }

    /// Called when the current sentence finishes.
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.isPaused = false
            self.currentWordInSentence = ""
            self.progress = self.sentences.isEmpty ? 1.0 : Double(self.currentIndex + 1) / Double(max(1, self.sentences.count))

            // Move to next sentence automatically
            if self.currentIndex < self.sentences.count - 1 {
                self.currentIndex += 1
                self.speakCurrentSentence()
            } else {
                self.isSpeaking = false
                self.isPaused = false
                self.hasActiveItem = false
            }
        }
    }

    /// Called when speech is cancelled or stopped prematurely.
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.isPaused = false
            self.currentWordInSentence = ""
        }
    }
}

