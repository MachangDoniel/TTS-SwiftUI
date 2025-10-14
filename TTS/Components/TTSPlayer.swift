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

    /// The full sentence currently being read
    @Published var currentSentenceText: String = ""

    /// The current word being spoken (within the current sentence)
    @Published var currentWordInSentence: String = ""

    /// The range of the current word in the current sentence
    @Published var currentWordRange: NSRange? = nil

    // MARK: - Private Properties
    private var synthesizer = AVSpeechSynthesizer()

    // MARK: - Init
    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Public Methods

    /// Starts reading the full text from the beginning.
    func startReading(_ text: String) {
        stop()
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

    /// Stops all speech immediately.
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        isPaused = false
        currentWordInSentence = ""
        currentSentenceText = ""
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
        // 2) Split by lines first so single-line headings are preserved as units
        let lines = normalized.components(separatedBy: "\n")
        var results: [String] = []

        let sentenceDelimiters = CharacterSet(charactersIn: ".!?")

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            // If the line already looks like a heading (no terminal punctuation), keep as-is
            if let last = line.unicodeScalars.last, !sentenceDelimiters.contains(last) {
                results.append(line)
                continue
            }

            // Otherwise, split the line further by sentence punctuation to get multiple sentences
            var buffer = ""
            for ch in line {
                buffer.append(ch)
                if ".!?".contains(ch) {
                    let sentence = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !sentence.isEmpty { results.append(sentence) }
                    buffer.removeAll(keepingCapacity: true)
                }
            }
            // Any trailing content without punctuation becomes a heading-like sentence
            let tail = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !tail.isEmpty { results.append(tail) }
        }

        // Collapse multiple spaces and filter empties
        return results.map { $0.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression) }
                      .filter { !$0.isEmpty }
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

            // Move to next sentence automatically
            if self.currentIndex < self.sentences.count - 1 {
                self.currentIndex += 1
                self.speakCurrentSentence()
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
