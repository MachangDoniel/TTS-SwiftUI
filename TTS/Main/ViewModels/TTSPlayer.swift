//
//  TTSPlayer.swift
//  TTS
//
//  Created by Doniel Tripura on 10/5/25.
//

import Foundation
import AVFoundation
import Combine

// MARK: - Supporting Types

struct TTSConfiguration {
    var language: String = "en-US"
    var rate: Float = AVSpeechUtteranceDefaultSpeechRate
}

enum TTSPlayerState {
    case idle, playing, paused, finished
}

enum AppVoiceMode: String, Codable {
    case system   // Apple AVSpeechSynthesizer
    case backend  // API-based voice
}

// MARK: - TTSPlayer

@MainActor
final class TTSPlayer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {

    // MARK: - Published Properties
    @Published var sentences: [String] = []
    @Published var currentIndex: Int = 0
    @Published var state: TTSPlayerState = .idle
    @Published var progress: Double = 0.0
    @Published var currentSentenceText: String = ""
    @Published var currentWordInSentence: String = ""
    @Published var currentWordRange: NSRange? = nil
    @Published var currentWordIndexInSentence: Int? = nil
    @Published var currentWordToken: WordToken? = nil
    @Published var position: TTSPosition = .init(sentenceIndex: 0, wordNSRange: nil, wordIndex: nil)
    @Published var currentTitle: String? = nil
    @Published var currentURL: URL? = nil
    @Published var appVoice: AppVoiceMode = .system
    @Published var selectedVoiceSampleId: String = "1"
    
    // MARK: - Word Tokenization
    var wordTokens: [[WordToken]] = []  // Pre-tokenized words per sentence

    // MARK: - Dependencies
    private let config: TTSConfiguration
    private let parser = TTSSentenceParser()
    public var synthesizer = AVSpeechSynthesizer()
    private let backendWorker = TTSBackendWorker()

    private var audioPlayer: AVAudioPlayer?

    // MARK: - Computed State
    var isSpeaking: Bool { state == .playing || state == .paused }
    var isPaused: Bool { state == .paused }
    var hasActiveItem: Bool { state != .idle && state != .finished }

    // MARK: - Init
    init(config: TTSConfiguration = .init()) {
        self.config = config
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Public API

    func prepare(text: String, url: URL?, title: String?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            resetSession()
            currentURL = url
            currentTitle = title
            return
        }

        sentences = parser.splitIntoSentencesPreservingHeadings(trimmed)
        // Pre-tokenize all sentences into words for accurate tracking
        wordTokens = WordTokenizer.tokenizeSentences(sentences)
        currentIndex = 0
        currentSentenceText = sentences.first ?? ""
        currentWordInSentence = ""
        currentWordRange = nil
        currentWordIndexInSentence = nil
        currentWordToken = nil
        position = .init(sentenceIndex: currentIndex, wordNSRange: nil, wordIndex: nil)
        currentURL = url
        currentTitle = title
        progress = 0.0
        state = .idle
    }
    
    func startReading(_ text: String, url: URL? = nil, title: String? = nil) {
        // Prepare and immediately start from the beginning
        prepare(text: text, url: url ?? currentURL, title: title ?? currentTitle)
        playFromCurrent()
    }

    func playFromCurrent() {
        guard !sentences.isEmpty else { return }
        // Ensure currentIndex is valid
        if currentIndex >= sentences.count {
            currentIndex = 0
        }
        guard sentences.indices.contains(currentIndex) else { return }
        state = .playing
        progress = Double(currentIndex) / Double(max(1, sentences.count))
        // Update currentSentenceText before playing
        currentSentenceText = sentences[currentIndex]
        playCurrentSentence(resumeAt: currentIndex)
    }
    
    func togglePlayPause() {
        switch appVoice {
        case .system:
            // Ensured MainActor for smooth UI updates (free mode)
            Task { @MainActor in
                toggleApplePlayPause()
            }
        case .backend: toggleBackendPlayPause()
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        audioPlayer = nil
        backendWorker.stopCurrent(player: self)
        backendWorker.cancelGenerationOnly(keepingAudio: true)
        // Preserve sentences and index so highlight and position remain
        currentWordInSentence = ""
        currentWordRange = nil
        currentWordIndexInSentence = nil
        currentWordToken = nil
        position = .init(sentenceIndex: currentIndex, wordNSRange: nil, wordIndex: nil)
        progress = Double(currentIndex) / Double(max(1, sentences.count))
        state = .idle
    }
    
    func resetSession() {
        // Fully clear all state (use when switching files)
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.delegate = nil
        synthesizer = AVSpeechSynthesizer()
        synthesizer.delegate = self

        audioPlayer?.stop()
        audioPlayer = nil
        backendWorker.cancel()
        sentences.removeAll()
        wordTokens.removeAll()
        currentIndex = 0
        currentSentenceText = ""
        currentWordInSentence = ""
        currentWordRange = nil
        currentWordIndexInSentence = nil
        currentWordToken = nil
        position = .init(sentenceIndex: 0, wordNSRange: nil, wordIndex: nil)
        progress = 0.0
        state = .idle
        currentTitle = nil
        currentURL = nil
    }

    func nextSentence() {
        guard !sentences.isEmpty, currentIndex < sentences.count - 1 else { return }
        switch appVoice {
        case .system:
            // Ensured MainActor for smooth UI updates (free mode)
            Task { @MainActor in
                synthesizer.stopSpeaking(at: .immediate)
                let nextIndex = min(currentIndex + 1, sentences.count - 1)
                currentIndex = nextIndex
                // Sync highlight text to new sentence after index change
                currentSentenceText = sentences[currentIndex]
                currentWordInSentence = ""
                currentWordRange = nil
                currentWordIndexInSentence = nil
                currentWordToken = nil
                position = .init(sentenceIndex: currentIndex, wordNSRange: nil, wordIndex: nil)
                state = .playing
                progress = Double(currentIndex) / Double(max(1, sentences.count))
                speakCurrentSentence_Apple()
            }
        case .backend:
            backendWorker.stopCurrent(player: self)
            let nextIndex = min(currentIndex + 1, sentences.count - 1)
            currentIndex = nextIndex
            currentSentenceText = sentences[currentIndex]
            currentWordInSentence = ""
            currentWordRange = nil
            currentWordIndexInSentence = nil
            currentWordToken = nil
            position = .init(sentenceIndex: currentIndex, wordNSRange: nil, wordIndex: nil)
            state = .playing
            progress = Double(currentIndex) / Double(max(1, sentences.count))
            backendWorker.playNext(from: currentIndex, sentences: sentences, player: self)
        }
    }

    func previousSentence() {
        guard !sentences.isEmpty, currentIndex > 0 else { return }
        switch appVoice {
        case .system:
            // Ensured MainActor for smooth UI updates (free mode)
            Task { @MainActor in
                synthesizer.stopSpeaking(at: .immediate)
                let prevIndex = max(currentIndex - 1, 0)
                currentIndex = prevIndex
                // Sync highlight text to new sentence after index change
                currentSentenceText = sentences[currentIndex]
                currentWordInSentence = ""
                currentWordRange = nil
                currentWordIndexInSentence = nil
                currentWordToken = nil
                position = .init(sentenceIndex: currentIndex, wordNSRange: nil, wordIndex: nil)
                state = .playing
                progress = Double(currentIndex) / Double(max(1, sentences.count))
                speakCurrentSentence_Apple()
            }
        case .backend:
            backendWorker.stopCurrent(player: self)
            let prevIndex = max(currentIndex - 1, 0)
            currentIndex = prevIndex
            currentSentenceText = sentences[currentIndex]
            currentWordInSentence = ""
            currentWordRange = nil
            currentWordIndexInSentence = nil
            currentWordToken = nil
            position = .init(sentenceIndex: currentIndex, wordNSRange: nil, wordIndex: nil)
            state = .playing
            progress = Double(currentIndex) / Double(max(1, sentences.count))
            backendWorker.playPrevious(from: currentIndex, sentences: sentences, player: self)
        }
    }

    // MARK: - Apple Flow
    private func speakCurrentSentence_Apple() {
        guard sentences.indices.contains(currentIndex) else { return }
        let sentence = sentences[currentIndex].trimmingCharacters(in: .whitespacesAndNewlines)

        // Always update currentSentenceText when starting playback to sync highlight
        currentSentenceText = sentence

        let utterance = AVSpeechUtterance(string: sentence)
        if let sysVoice = AVSpeechSynthesisVoice(identifier: selectedVoiceSampleId) {
            utterance.voice = sysVoice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: config.language)
        }
        utterance.rate = config.rate
        synthesizer.speak(utterance)
        Logger.log("🔊 [Apple] Reading sentence \(currentIndex + 1)/\(sentences.count)")
    }

    private func toggleApplePlayPause() {
        switch state {
        case .playing:
            synthesizer.pauseSpeaking(at: .immediate)
            state = .paused
        case .paused:
            synthesizer.continueSpeaking()
            state = .playing
        case .idle, .finished:
            // Reset to beginning when restarting from finished state
            if state == .finished {
                currentIndex = 0
                currentSentenceText = sentences.first ?? ""
                currentWordInSentence = ""
                currentWordRange = nil
                currentWordIndexInSentence = nil
                currentWordToken = nil
                position = .init(sentenceIndex: 0, wordNSRange: nil, wordIndex: nil)
                progress = 0.0
            }
            playFromCurrent()
        }
    }
    
    // MARK: - Seamless Voice Switching
    func updateVoiceMode(_ mode: AppVoiceMode) {
        guard appVoice != mode else { return }
        let previousMode = appVoice
        appVoice = mode

        switch (previousMode, mode) {
        case (.system, .backend):
            // Let current Apple sentence finish; backend flow will start on next sentence
            backendWorker.cancelGenerationOnly(keepingAudio: true)
        case (.backend, .system):
            backendWorker.cancel()
            if state == .playing {
                // Resume Apple speech from current sentence
                synthesizer.stopSpeaking(at: .immediate)
                currentWordInSentence = ""
                currentWordRange = nil
                currentWordToken = nil
                speakCurrentSentence_Apple()
                state = .playing
            }
        default:
            break
        }
    }
    
    func updateSelectedVoiceSampleId(_ voiceId: String) {
        let oldId = selectedVoiceSampleId
        selectedVoiceSampleId = voiceId
        guard appVoice == .system else {
            // Backend picks up new voice for future chunks
            backendWorker.refreshVoice(
                with: voiceId,
                currentIndex: currentIndex,
                sentences: sentences,
                player: self
            )
            return
        }
        guard state == .playing else { return }
        guard oldId != voiceId else { return }
        // For Apple engine: restart the remaining text of the current sentence with new voice
        // Compute remaining substring based on currentWordRange
        let sentence = currentSentenceText
        let remaining: String = {
            if let range = currentWordRange,
               let swiftRange = Range(range, in: sentence) {
                return String(sentence[swiftRange.lowerBound...])
            }
            return sentence
        }()
        synthesizer.stopSpeaking(at: .immediate)
        currentWordInSentence = ""
        currentWordRange = nil
        currentWordToken = nil
        if !remaining.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let utterance = AVSpeechUtterance(string: remaining)
            if let sysVoice = AVSpeechSynthesisVoice(identifier: selectedVoiceSampleId) {
                utterance.voice = sysVoice
            } else {
                utterance.voice = AVSpeechSynthesisVoice(language: config.language)
            }
            utterance.rate = config.rate
            synthesizer.speak(utterance)
            state = .playing
        } else {
            // Nothing remaining → move to next sentence
            speechSynthesizer(synthesizer, didFinish: AVSpeechUtterance(string: sentence))
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           willSpeakRangeOfSpeechString range: NSRange,
                           utterance: AVSpeechUtterance) {
        // Use pre-tokenized word tokens for accurate word matching
        guard currentIndex < wordTokens.count else {
            // Fallback to old method if tokens not available
            currentWordRange = range
            let nsText = utterance.speechString as NSString
            currentWordInSentence = nsText.substring(with: range)
            currentWordIndexInSentence = estimateWordIndex(in: utterance.speechString, range: range)
            position = .init(sentenceIndex: currentIndex, wordNSRange: currentWordRange, wordIndex: currentWordIndexInSentence)
            return
        }
        
        let sentenceTokens = wordTokens[currentIndex]
        // Find the matching word token using accurate matching algorithm
        if let matchedToken = WordTokenizer.findWordToken(by: range, in: sentenceTokens) {
            currentWordToken = matchedToken
            currentWordRange = matchedToken.range
            currentWordInSentence = matchedToken.text
            currentWordIndexInSentence = matchedToken.index
            position = .init(sentenceIndex: currentIndex, wordNSRange: matchedToken.range, wordIndex: matchedToken.index)
        } else {
            // Fallback if no match found
            currentWordRange = range
            let nsText = utterance.speechString as NSString
            currentWordInSentence = nsText.substring(with: range)
            currentWordIndexInSentence = estimateWordIndex(in: utterance.speechString, range: range)
            position = .init(sentenceIndex: currentIndex, wordNSRange: currentWordRange, wordIndex: currentWordIndexInSentence)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didFinish utterance: AVSpeechUtterance) {
        currentWordInSentence = ""
        currentWordIndexInSentence = nil
        currentWordToken = nil
        progress = Double(currentIndex + 1) / Double(max(1, sentences.count))
        if currentIndex < sentences.count - 1 {
            currentIndex += 1
            // Sync highlight text when advancing sentence automatically
            if sentences.indices.contains(currentIndex) {
                currentSentenceText = sentences[currentIndex]
            } else {
                currentSentenceText = ""
            }
            currentWordInSentence = ""
            currentWordRange = nil
            currentWordIndexInSentence = nil
            currentWordToken = nil
            position = .init(sentenceIndex: currentIndex, wordNSRange: nil, wordIndex: nil)
            state = .playing
            playCurrentSentence(resumeAt: currentIndex)
        } else {
            state = .finished
            position = .init(sentenceIndex: currentIndex, wordNSRange: nil, wordIndex: nil)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didCancel utterance: AVSpeechUtterance) {
        currentWordInSentence = ""
        currentWordIndexInSentence = nil
        currentWordToken = nil
        position = .init(sentenceIndex: currentIndex, wordNSRange: nil, wordIndex: nil)
    }

    // MARK: - Backend Flow
    private func startBackendFlow(resumeAt: Int? = nil) {
        backendWorker.startFlow(
            sentences: sentences,
            currentIndex: currentIndex,
            selectedVoiceSampleId: selectedVoiceSampleId,
            player: self,
            resumeAt: resumeAt
        )
    }

    private func toggleBackendPlayPause() {
        switch state {
        case .playing:
            backendWorker.pause()
            state = .paused
        case .paused:
            backendWorker.resume()
            state = .playing
        case .idle, .finished:
            // Reset to beginning when restarting from finished state
            if state == .finished {
                currentIndex = 0
                currentSentenceText = sentences.first ?? ""
                currentWordInSentence = ""
                currentWordRange = nil
                currentWordIndexInSentence = nil
                currentWordToken = nil
                position = .init(sentenceIndex: 0, wordNSRange: nil, wordIndex: nil)
                progress = 0.0
            }
            startBackendFlow(resumeAt: currentIndex)
        }
    }

    // MARK: - AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        backendWorker.handleAudioFinished(player: self)
    }

    private func playCurrentSentence(resumeAt: Int) {
        switch appVoice {
        case .system:
            speakCurrentSentence_Apple()
        case .backend:
            backendWorker.startFlow(
                sentences: sentences,
                currentIndex: currentIndex,
                selectedVoiceSampleId: selectedVoiceSampleId,
                player: self,
                resumeAt: resumeAt
            )
        }
    }

    // MARK: - Position helpers
    struct TTSPosition {
        var sentenceIndex: Int
        var wordNSRange: NSRange?
        var wordIndex: Int?
    }

    private func estimateWordIndex(in sentence: String, range: NSRange) -> Int? {
        guard let r = Range(range, in: sentence) else { return nil }
        let prefix = sentence[sentence.startIndex..<r.lowerBound]
        // Split by whitespace; basic tokenization (normalizer can replace)
        let tokens = prefix.split { $0.isWhitespace }.count
        return tokens
    }
}

