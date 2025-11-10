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
    @Published var currentTitle: String? = nil
    @Published var currentURL: URL? = nil
    @Published var appVoice: AppVoiceMode = .system {
        didSet {
            // On voice mode change, stop current playback and reset currentSentenceText to keep highlight in sync.
            stop()
            if sentences.indices.contains(currentIndex) {
                currentSentenceText = sentences[currentIndex]
            } else {
                currentSentenceText = ""
            }
        }
    }
    @Published var selectedVoiceSampleId: String = "1" {
        didSet {
            // On voice sample change, stop current playback and reset currentSentenceText to keep highlight in sync.
            stop()
            if sentences.indices.contains(currentIndex) {
                currentSentenceText = sentences[currentIndex]
            } else {
                currentSentenceText = ""
            }
        }
    }

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

    func startReading(_ text: String) {
        stop()
        sentences = parser.splitIntoSentencesPreservingHeadings(text)
        currentIndex = 0

        // Always update currentSentenceText to current sentence for highlight syncing
        if sentences.indices.contains(currentIndex) {
            currentSentenceText = sentences[currentIndex]
        } else {
            currentSentenceText = ""
        }

        state = .playing
        progress = 0.0

        switch appVoice {
        case .system: speakCurrentSentence_Apple()
        case .backend: startBackendFlow()
        }
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
        backendWorker.cancel()
        sentences.removeAll()
        currentIndex = 0
        currentSentenceText = ""
        currentWordInSentence = ""
        currentWordRange = nil
        progress = 0.0
        state = .idle
    }

    func nextSentence() {
        guard currentIndex < sentences.count - 1 else { return }
        switch appVoice {
        case .system:
            // Ensured MainActor for smooth UI updates (free mode)
            Task { @MainActor in
                currentIndex += 1
                // Sync highlight text to new sentence after index change
                if sentences.indices.contains(currentIndex) {
                    currentSentenceText = sentences[currentIndex]
                } else {
                    currentSentenceText = ""
                }
                speakCurrentSentence_Apple()
            }
        case .backend:
            currentIndex += 1
            backendWorker.playNext(from: currentIndex, sentences: sentences, player: self)
        }
    }

    func previousSentence() {
        guard currentIndex > 0 else { return }
        switch appVoice {
        case .system:
            // Ensured MainActor for smooth UI updates (free mode)
            Task { @MainActor in
                currentIndex -= 1
                // Sync highlight text to new sentence after index change
                if sentences.indices.contains(currentIndex) {
                    currentSentenceText = sentences[currentIndex]
                } else {
                    currentSentenceText = ""
                }
                speakCurrentSentence_Apple()
            }
        case .backend:
            currentIndex -= 1
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
            speakCurrentSentence_Apple()
            state = .playing
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           willSpeakRangeOfSpeechString range: NSRange,
                           utterance: AVSpeechUtterance) {
        currentWordRange = range
        let nsText = utterance.speechString as NSString
        currentWordInSentence = nsText.substring(with: range)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didFinish utterance: AVSpeechUtterance) {
        currentWordInSentence = ""
        progress = Double(currentIndex + 1) / Double(max(1, sentences.count))
        if currentIndex < sentences.count - 1 {
            currentIndex += 1
            // Sync highlight text when advancing sentence automatically
            if sentences.indices.contains(currentIndex) {
                currentSentenceText = sentences[currentIndex]
            } else {
                currentSentenceText = ""
            }
            speakCurrentSentence_Apple()
        } else {
            state = .finished
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didCancel utterance: AVSpeechUtterance) {
        currentWordInSentence = ""
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
            startBackendFlow(resumeAt: currentIndex)
        }
    }

    // MARK: - AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        backendWorker.handleAudioFinished(player: self)
    }
}

