//
//  TTSPlayer.swift
//  TTS
//
//  Created by Doniel Tripura on 10/5/25.
//

import Foundation
import AVFoundation
import Combine


// MARK: - TTSPlayer

// Reminder: UI should call `openFile(text:url:title:)` upon navigation/opening a new file to enforce immediate playback start and reset voice & highlight state.

struct TTSPosition {
    var sentenceIndex: Int
    var wordNSRange: NSRange?
    var wordIndex: Int?
}

@MainActor
final class TTSPlayer: NSObject, ObservableObject {
    
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
    @Published var selectedVoiceSampleId: String = "com.apple.voice.super-compact.en-US.Samantha"
    @Published var selectedVoiceName: String = "Samantha"
    
    // MARK: - Timeline Properties
    @Published var currentTime: TimeInterval = 0.0
    @Published var totalDuration: TimeInterval = 0.0
    @Published var timeToComplete: TimeInterval = 0.0
    @Published var isSeekable: Bool = false
    @Published var estimatedSentenceDurations: [TimeInterval] = []
    
    // Tracks identity of the currently prepared content and the last content that actually started playback
    @Published var preparedContentId: String? = nil
    @Published var lastPlayedContentId: String? = nil
    
    // MARK: - Word Tokenization
    var wordTokens: [[WordToken]] = []  // Pre-tokenized words per sentence
    
    // MARK: - Dependencies
    private let config: TTSConfiguration
    private let parser = TTSSentenceParser()
    public var synthesizer = AVSpeechSynthesizer()
    private let backendWorker = TTSBackendService()
    
    private var audioPlayer: AVAudioPlayer?
    
    // MARK: - Utterance Tracking
    private var currentUtterance: AVSpeechUtterance?
    
    // MARK: - Timeline Management
    private var progressTimer: Timer?
    private var sentenceStartTime: TimeInterval = 0.0
    private var playbackStartTime: Date?
    private var skipTask: Task<Void, Never>?
    
    // MARK: - Computed State
    var isSpeaking: Bool { state == .playing || state == .paused }
    var isPaused: Bool { state == .paused }
    var hasActiveItem: Bool { state != .idle && state != .finished }
    
    // MARK: - Init
    init(config: TTSConfiguration = .init()) {
        self.config = config
        super.init()
        synthesizer.delegate = self
        if let savedVoiceId = UserDefaults.standard.string(forKey: KeyString.selectedVoiceSampleId),
            let savedVoiceName = UserDefaults.standard.string(forKey: KeyString.selectedVoiceName) {
            self.selectedVoiceSampleId = savedVoiceId
            self.selectedVoiceName = savedVoiceName
        }
    }
}

extension TTSPlayer {

    // MARK: - Public API
    
    func prepare(text: String, url: URL?, title: String?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            resetSession()
            currentURL = url
            currentTitle = title
            preparedContentId = makeContentId(text: trimmed, url: url, title: title)
            return
        }
        
        sentences = parser.splitIntoSentencesPreservingHeadings(trimmed)
        // Pre-tokenize all sentences into words for accurate tracking
        wordTokens = WordTokenizer.tokenizeSentences(sentences)
        
        // Estimate total duration for timeline
        estimateTotalDuration()
        
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
        currentTime = 0.0
        timeToComplete = 0.0
        state = .idle
        preparedContentId = makeContentId(text: trimmed, url: url, title: title)
    }
    
    /// Prepare a new file for playback (reset voice + highlight) but do NOT start speaking.
    /// Use this when a bottom sheet opens or when you only want to prepare the current file.
    func prepareNewFileOnly(text: String, url: URL?, title: String?) {
        // Stop any ongoing playback from the previous file
        synthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        audioPlayer = nil
        backendWorker.cancel()
        
        // Prepare fresh state for the new content
        prepare(text: text, url: url, title: title)
        preparedContentId = makeContentId(text: text, url: url, title: title)
        lastPlayedContentId = nil
        
        // Reset indices/highlighting to beginning
        currentIndex = 0
        currentSentenceText = sentences.first ?? ""
        currentWordInSentence = ""
        currentWordRange = nil
        currentWordIndexInSentence = nil
        currentWordToken = nil
        position = .init(sentenceIndex: 0, wordNSRange: nil, wordIndex: nil)
        progress = 0.0
        state = .paused
    }
    
    /// Auto-starts playback from the beginning.
    /// Open a new file and immediately start speaking it from the beginning (voice + highlight reset).
    /// Call this directly when the user opens/navigates to a different file.
    /// Note: Unlike `prepareNewFileOnly(...)`, this method auto-starts playback.
    func openFile(text: String, url: URL?, title: String?) {
        // Forget/stop anything from the previous file
        synthesizer.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        audioPlayer = nil
        backendWorker.cancel()
        
        // Prepare and start fresh
        prepare(text: text, url: url, title: title)
        preparedContentId = makeContentId(text: text, url: url, title: title)
        lastPlayedContentId = nil
        
        currentIndex = 0
        currentSentenceText = sentences.first ?? ""
        currentWordInSentence = ""
        currentWordRange = nil
        currentWordIndexInSentence = nil
        currentWordToken = nil
        position = .init(sentenceIndex: 0, wordNSRange: nil, wordIndex: nil)
        progress = 0.0
        state = .idle
        
        // Auto-start without waiting for Continue
        playFromCurrent()
    }
}

extension TTSPlayer {
    
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
        lastPlayedContentId = preparedContentId
        
        // Start timeline tracking
        playbackStartTime = Date()
        sentenceStartTime = getSentenceStartTime(currentIndex)
        startProgressTimer()
        
        playCurrentSentence(resumeAt: currentIndex)
    }
    
    func togglePlayPause() {
        // If nothing prepared, nothing to do
        guard !sentences.isEmpty else { return }
        
        let contentChanged = (preparedContentId != nil && preparedContentId != lastPlayedContentId)
        
        switch appVoice {
        case .system:
            Task { @MainActor in
                if contentChanged {
                    // Force a full restart from beginning with fresh voice + highlight
                    synthesizer.stopSpeaking(at: .immediate)
                    currentIndex = 0
                    currentSentenceText = sentences.first ?? ""
                    currentWordInSentence = ""
                    currentWordRange = nil
                    currentWordIndexInSentence = nil
                    currentWordToken = nil
                    position = .init(sentenceIndex: 0, wordNSRange: nil, wordIndex: nil)
                    progress = 0.0
                    playFromCurrent()
                    return
                }
                
                // Special case: if at end (index == sentences.count), restart from beginning
                if currentIndex == sentences.count {
                    currentIndex = 0
                    currentSentenceText = sentences.first ?? ""
                    currentWordInSentence = ""
                    currentWordRange = nil
                    currentWordIndexInSentence = nil
                    currentWordToken = nil
                    position = .init(sentenceIndex: 0, wordNSRange: nil, wordIndex: nil)
                    progress = 0.0
                    playFromCurrent()
                    return
                }
                
                switch state {
                case .playing:
                    let frozenTime = getCurrentElapsedTime()
                    stopProgressTimer()
                    currentTime = frozenTime
                    synthesizer.pauseSpeaking(at: .immediate)
                    state = .paused
                case .paused:
                    let start = getSentenceStartTime(currentIndex)
                    sentenceStartTime = start
                    playbackStartTime = Date().addingTimeInterval(-(currentTime - start))
                    synthesizer.continueSpeaking()
                    state = .playing
                    startProgressTimer()
                case .idle, .finished:
                    currentIndex = 0
                    currentSentenceText = sentences.first ?? ""
                    currentWordInSentence = ""
                    currentWordRange = nil
                    currentWordIndexInSentence = nil
                    currentWordToken = nil
                    position = .init(sentenceIndex: 0, wordNSRange: nil, wordIndex: nil)
                    progress = 0.0
                    playFromCurrent()
                case .loading:
                    break
                }
            }
        case .backend:
            if contentChanged {
                backendWorker.cancel()
                currentIndex = 0
                currentSentenceText = sentences.first ?? ""
                currentWordInSentence = ""
                currentWordRange = nil
                currentWordIndexInSentence = nil
                currentWordToken = nil
                position = .init(sentenceIndex: 0, wordNSRange: nil, wordIndex: nil)
                progress = 0.0
                startBackendFlow(resumeAt: currentIndex)
                return
            }
            
            // Special case: if at end (index == sentences.count), restart from beginning
            if currentIndex == sentences.count {
                currentIndex = 0
                currentSentenceText = sentences.first ?? ""
                currentWordInSentence = ""
                currentWordRange = nil
                currentWordIndexInSentence = nil
                currentWordToken = nil
                position = .init(sentenceIndex: 0, wordNSRange: nil, wordIndex: nil)
                progress = 0.0
                startBackendFlow(resumeAt: currentIndex)
                return
            }
            
            switch state {
            case .playing:
                backendWorker.pause()
                let frozenTime = getCurrentElapsedTime()
                stopProgressTimer()
                currentTime = frozenTime
                state = .paused
            case .paused:
                startProgressTimer()
                backendWorker.resume()
                state = .playing
            case .idle, .finished:
                currentIndex = 0
                currentSentenceText = sentences.first ?? ""
                currentWordInSentence = ""
                currentWordRange = nil
                currentWordIndexInSentence = nil
                currentWordToken = nil
                position = .init(sentenceIndex: 0, wordNSRange: nil, wordIndex: nil)
                progress = 0.0
                startBackendFlow(resumeAt: currentIndex)
            case .loading:
                break
            }
        }
    }
    
    func stop() {
        // Cancel any pending skip operations
        skipTask?.cancel()
        skipTask = nil
        
        synthesizer.stopSpeaking(at: .immediate)
        currentUtterance = nil
        audioPlayer?.stop()
        audioPlayer = nil
        backendWorker.stopCurrent(player: self)
        backendWorker.cancelGenerationOnly(keepingAudio: true)
        
        stopProgressTimer()
        
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
        // Cancel any pending skip operations
        skipTask?.cancel()
        skipTask = nil
        
        synthesizer.stopSpeaking(at: .immediate)
        currentUtterance = nil
        synthesizer.delegate = nil
        synthesizer = AVSpeechSynthesizer()
        synthesizer.delegate = self
        
        audioPlayer?.stop()
        audioPlayer = nil
        backendWorker.cancel()
        
        stopProgressTimer()
        
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
        currentTime = 0.0
        timeToComplete = 0.0
        state = .idle
        currentTitle = nil
        currentURL = nil
        preparedContentId = nil
        lastPlayedContentId = nil
    }
    
    func nextSentence() {
        guard !sentences.isEmpty else { return }
        // If at end (index == sentences.count), do nothing
        guard currentIndex < sentences.count - 1 else { return }
        switch appVoice {
        case .system:
            // Cancel any existing skip operation to prevent race conditions
            skipTask?.cancel()
            
            // Ensured MainActor for smooth UI updates (free mode)
            skipTask = Task { @MainActor in
                // Capture currentIndex at the start before any delay to prevent race conditions
                let nextIndex = min(currentIndex + 1, sentences.count - 1)
                
                // Check if task was cancelled before proceeding
                guard !Task.isCancelled else { return }
                
                // Step 1: Pause first (button shows pause, highlight syncs)
                state = .paused
                
                // Step 2: Stop current speech and clear utterance tracking
                synthesizer.stopSpeaking(at: .immediate)
                currentUtterance = nil
                
                // Step 3: Wait briefly for stop to complete (prevents race condition)
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms delay
                
                // Check again if task was cancelled during sleep
                guard !Task.isCancelled else { return }
                
                // Step 4: Update to next sentence using captured index
                currentIndex = nextIndex
                currentSentenceText = sentences[currentIndex]
                currentWordInSentence = ""
                currentWordRange = nil
                currentWordIndexInSentence = nil
                currentWordToken = nil
                position = .init(sentenceIndex: currentIndex, wordNSRange: nil, wordIndex: nil)
                progress = Double(currentIndex) / Double(max(1, sentences.count))
                
                // Update timeline tracking for the new sentence
                playbackStartTime = Date()
                sentenceStartTime = getSentenceStartTime(currentIndex)
                currentTime = sentenceStartTime
                startProgressTimer()
                
                // Update time to complete after moving to next sentence
                updateTimeToComplete()
                
                // Step 5: Resume playing (button shows play, voice active, highlight active)
                state = .playing
                speakCurrentSentence_Apple()
                
                // Clear the task reference when done
                skipTask = nil
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
            // Update time to complete after moving to next sentence
            updateTimeToComplete()
            backendWorker.playNext(from: currentIndex, sentences: sentences, player: self)
        }
    }
    
    func previousSentence() {
        guard !sentences.isEmpty else { return }
        
        // Special case: if at end (index == sentences.count), go to last sentence
        if currentIndex == sentences.count {
            currentIndex = sentences.count - 1
            currentSentenceText = sentences[currentIndex]
            currentWordInSentence = ""
            currentWordRange = nil
            currentWordIndexInSentence = nil
            currentWordToken = nil
            position = .init(sentenceIndex: currentIndex, wordNSRange: nil, wordIndex: nil)
            progress = Double(currentIndex) / Double(max(1, sentences.count))
            
            // Update timeline tracking
            playbackStartTime = Date()
            sentenceStartTime = getSentenceStartTime(currentIndex)
            currentTime = sentenceStartTime
            startProgressTimer()
            
            // Update time to complete after moving to previous sentence
            updateTimeToComplete()
            
            state = .playing
            playCurrentSentence(resumeAt: currentIndex)
            return
        }
        
        guard currentIndex > 0 else { return }
        switch appVoice {
        case .system:
            // Cancel any existing skip operation to prevent race conditions
            skipTask?.cancel()
            
            // Ensured MainActor for smooth UI updates (free mode)
            skipTask = Task { @MainActor in
                // Capture currentIndex at the start before any delay to prevent race conditions
                let prevIndex = max(currentIndex - 1, 0)
                
                // Check if task was cancelled before proceeding
                guard !Task.isCancelled else { return }
                
                // Step 1: Pause first (button shows pause, highlight syncs)
                state = .paused
                
                // Step 2: Stop current speech and clear utterance tracking
                synthesizer.stopSpeaking(at: .immediate)
                currentUtterance = nil
                
                // Step 3: Wait briefly for stop to complete (prevents race condition)
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms delay
                
                // Check again if task was cancelled during sleep
                guard !Task.isCancelled else { return }
                
                // Step 4: Update to previous sentence using captured index
                currentIndex = prevIndex
                currentSentenceText = sentences[currentIndex]
                currentWordInSentence = ""
                currentWordRange = nil
                currentWordIndexInSentence = nil
                currentWordToken = nil
                position = .init(sentenceIndex: currentIndex, wordNSRange: nil, wordIndex: nil)
                progress = Double(currentIndex) / Double(max(1, sentences.count))
                
                // Update timeline tracking for the new sentence
                playbackStartTime = Date()
                sentenceStartTime = getSentenceStartTime(currentIndex)
                currentTime = sentenceStartTime
                startProgressTimer()
                
                // Update time to complete after moving to previous sentence
                updateTimeToComplete()
                
                // Step 5: Resume playing (button shows play, voice active, highlight active)
                state = .playing
                speakCurrentSentence_Apple()
                
                // Clear the task reference when done
                skipTask = nil
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
            // Update time to complete after moving to previous sentence
            updateTimeToComplete()
            backendWorker.playPrevious(from: currentIndex, sentences: sentences, player: self)
        }
    }
}

extension TTSPlayer {
    
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
        
        // Track this utterance as the current one for validation in delegate callbacks
        currentUtterance = utterance
        
        synthesizer.speak(utterance)
        Logger.log("🔊 [Apple] Reading sentence \(currentIndex + 1)/\(sentences.count)")
    }
    
    private func toggleApplePlayPause() {
        switch state {
        case .playing:
            let frozenTime = getCurrentElapsedTime()
            stopProgressTimer()
            currentTime = frozenTime
            synthesizer.pauseSpeaking(at: .immediate)
            state = .paused
        case .paused:
            let start = getSentenceStartTime(currentIndex)
            sentenceStartTime = start
            playbackStartTime = Date().addingTimeInterval(-(currentTime - start))
            synthesizer.continueSpeaking()
            state = .playing
            startProgressTimer()
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
        case .loading:
            break
        }
    }
}

extension TTSPlayer {
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
        UserDefaults.standard.set(selectedVoiceSampleId, forKey: KeyString.selectedVoiceSampleId)
        UserDefaults.standard.set(selectedVoiceName, forKey: KeyString.selectedVoiceName)
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
        if oldId != voiceId || state == .playing || state == .paused {
            synthesizer.stopSpeaking(at: .immediate)
            currentWordInSentence = ""
            currentWordRange = nil
            currentWordToken = nil
            speakCurrentSentence_Apple()
            if state == .playing {
                state = .playing
            } else if state == .paused {
                // Pause immediately after starting utterance to keep paused state
                synthesizer.pauseSpeaking(at: .immediate)
                state = .paused
            }
        }
    }
}

extension TTSPlayer: AVSpeechSynthesizerDelegate {
    
    // MARK: - AVSpeechSynthesizerDelegate
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           willSpeakRangeOfSpeechString range: NSRange,
                           utterance: AVSpeechUtterance) {
        // Ensure we're processing the correct utterance for the current sentence
        // This prevents stale delegate callbacks from old utterances after skipping
        guard currentIndex < sentences.count else { return }
        let currentSentence = sentences[currentIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        guard utterance.speechString == currentSentence else {
            // This is a callback for an old utterance that's being cancelled
            return
        }
        
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
        // Two-layer validation to prevent stale callbacks from causing desync
        // Layer 1: Identity check - is this the utterance we're currently tracking?
        guard utterance === currentUtterance else {
            // This is a callback from an old utterance that was cancelled
            return
        }
        
        // Layer 2: Content validation - does the utterance match current sentence?
        guard currentIndex < sentences.count else { return }
        let currentSentence = sentences[currentIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        guard utterance.speechString == currentSentence else {
            // Utterance doesn't match current sentence, ignore it
            return
        }
        
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
            lastPlayedContentId = preparedContentId
            state = .playing
            // Update time to complete after sentence completion
            updateTimeToComplete()
            playCurrentSentence(resumeAt: currentIndex)
        } else {
            // Finished last sentence - pause at end (not restart)
            stopProgressTimer()
            currentIndex = sentences.count // Set to invalid index to represent "at end"
            currentTime = totalDuration // Complete the slider
            state = .paused
            position = .init(sentenceIndex: currentIndex, wordNSRange: nil, wordIndex: nil)
            currentUtterance = nil
            // Update time to complete (should be 0 when finished)
            updateTimeToComplete()
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didCancel utterance: AVSpeechUtterance) {
        stopProgressTimer()
        currentWordInSentence = ""
        currentWordIndexInSentence = nil
        currentWordToken = nil
        position = .init(sentenceIndex: currentIndex, wordNSRange: nil, wordIndex: nil)
    }
}

extension TTSPlayer {
    
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
            let frozenTime = getCurrentElapsedTime()
            stopProgressTimer()
            currentTime = frozenTime
            state = .paused
        case .paused:
            startProgressTimer()
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
        case .loading:
            break
        }
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
}

extension TTSPlayer: AVAudioPlayerDelegate {
    // MARK: - AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stopProgressTimer()
        backendWorker.handleAudioFinished(player: self)
    }
}

// MARK: - Timeline Controls
extension TTSPlayer {
    
    /// Skip forward by specified seconds (default 10 seconds)
    func skipForward(_ seconds: TimeInterval = 10.0) {
        guard !sentences.isEmpty else { return }
        
        switch appVoice {
        case .system:
            skipForwardSystem(seconds)
        case .backend:
            skipForwardBackend(seconds)
        }
    }
    
    /// Skip backward by specified seconds (default 10 seconds)
    func skipBackward(_ seconds: TimeInterval = 10.0) {
        guard !sentences.isEmpty else { return }
        
        switch appVoice {
        case .system:
            skipBackwardSystem(seconds)
        case .backend:
            skipBackwardBackend(seconds)
        }
    }
    
    /// Seek to specific time position
    func seek(to time: TimeInterval) {
        guard !sentences.isEmpty, time >= 0 else { return }
        
        // Find the sentence index for the target time
        let targetIndex = findSentenceIndex(for: time)
        guard targetIndex < sentences.count else { return }
        
        switch appVoice {
        case .system:
            seekSystemVoice(to: time, sentenceIndex: targetIndex)
        case .backend:
            seekBackendVoice(to: time, sentenceIndex: targetIndex)
        }
    }
    
    // MARK: - System Voice Timeline Methods
    private func skipForwardSystem(_ seconds: TimeInterval) {
        guard !sentences.isEmpty else { return }
        if currentIndex < sentences.count - 1 {
            nextSentence()
        } else {
            // At the last sentence; finish reading and pause at end
            synthesizer.stopSpeaking(at: .immediate)
            currentUtterance = nil
            stopProgressTimer()
            currentIndex = sentences.count // Set to invalid index to represent "at end"
            currentTime = totalDuration // Complete the slider
            state = .paused
            currentWordInSentence = ""
            currentWordRange = nil
            currentWordIndexInSentence = nil
            currentWordToken = nil
            position = .init(sentenceIndex: currentIndex, wordNSRange: nil, wordIndex: nil)
        }
    }
    
    private func skipBackwardSystem(_ seconds: TimeInterval) {
        guard !sentences.isEmpty else { return }
        // Elapsed time within the current sentence
        let elapsedInSentence = getCurrentElapsedTime() - getSentenceStartTime(currentIndex)
        let restartThreshold: TimeInterval = 2.0
        if elapsedInSentence > restartThreshold {
            // Restart current sentence
            let startTime = getSentenceStartTime(currentIndex)
            seek(to: startTime)
        } else {
            // Go to previous sentence if possible
            previousSentence()
        }
    }
    
    private func seekSystemVoice(to time: TimeInterval, sentenceIndex: Int) {
        Task { @MainActor in
            synthesizer.stopSpeaking(at: .immediate)
            currentIndex = sentenceIndex
            currentSentenceText = sentences[currentIndex]
            currentWordInSentence = ""
            currentWordRange = nil
            currentWordIndexInSentence = nil
            currentWordToken = nil
            position = .init(sentenceIndex: currentIndex, wordNSRange: nil, wordIndex: nil)
            
            // Calculate progress within the sentence
            let sentenceStartTime = getSentenceStartTime(sentenceIndex)
            currentTime = sentenceStartTime
            playbackStartTime = Date()
            self.sentenceStartTime = sentenceStartTime
            
            progress = Double(currentIndex) / Double(max(1, sentences.count))
            // Update time to complete after seeking
            updateTimeToComplete()
            state = .playing
            speakCurrentSentence_Apple()
            startProgressTimer()
        }
    }
    
    // MARK: - Backend Voice Timeline Methods
    private func skipForwardBackend(_ seconds: TimeInterval) {
        guard let player = audioPlayer else { return }
        let targetTime = player.currentTime + seconds
        if targetTime < player.duration {
            player.currentTime = targetTime
            currentTime = getSentenceStartTime(currentIndex) + targetTime
        } else {
            // Skip to next sentence
            nextSentence()
        }
    }
    
    private func skipBackwardBackend(_ seconds: TimeInterval) {
        guard let player = audioPlayer else { return }
        let targetTime = max(0, player.currentTime - seconds)
        player.currentTime = targetTime
        currentTime = getSentenceStartTime(currentIndex) + targetTime
    }
    
    private func seekBackendVoice(to time: TimeInterval, sentenceIndex: Int) {
        // For backend mode, switch to correct audio file
        currentIndex = sentenceIndex
        currentSentenceText = sentences[currentIndex]
        currentWordInSentence = ""
        currentWordRange = nil
        currentWordIndexInSentence = nil
        currentWordToken = nil
        position = .init(sentenceIndex: currentIndex, wordNSRange: nil, wordIndex: nil)
        state = .playing
        progress = Double(currentIndex) / Double(max(1, sentences.count))
        // Update time to complete after seeking
        updateTimeToComplete()
        
        // Start playing the sentence
        playFromCurrent()
    }
    
    // MARK: - Timeline Utilities
    private func findSentenceIndex(for time: TimeInterval) -> Int {
        guard !estimatedSentenceDurations.isEmpty else {
            // Fallback: estimate based on equal distribution
            let avgDuration = totalDuration / Double(sentences.count)
            return min(Int(time / avgDuration), sentences.count - 1)
        }
        
        var accumulatedTime: TimeInterval = 0
        for (index, duration) in estimatedSentenceDurations.enumerated() {
            if time <= accumulatedTime + duration {
                return index
            }
            accumulatedTime += duration
        }
        return sentences.count - 1
    }
    
    private func getSentenceStartTime(_ sentenceIndex: Int) -> TimeInterval {
        guard !estimatedSentenceDurations.isEmpty, sentenceIndex < estimatedSentenceDurations.count else {
            let avgDuration = totalDuration / Double(sentences.count)
            return Double(sentenceIndex) * avgDuration
        }
        
        return estimatedSentenceDurations.prefix(sentenceIndex).reduce(0, +)
    }
    
    private func getCurrentElapsedTime() -> TimeInterval {
        if state == .paused { return currentTime }
        switch appVoice {
        case .system:
            guard let startTime = playbackStartTime else { return currentTime }
            return sentenceStartTime + Date().timeIntervalSince(startTime)
        case .backend:
            if let player = audioPlayer {
                return getSentenceStartTime(currentIndex) + player.currentTime
            }
            return currentTime
        }
    }
    
    func estimateTotalDuration() {
        // Calculate total duration based on word count: 0.4 seconds per word
        var totalWordCount = 0
        for sentence in sentences {
            let tokens = WordTokenizer.tokenize(sentence)
            totalWordCount += tokens.count
        }
        
        // Total duration = total words * 0.4 seconds
        totalDuration = 0.4 * Double(totalWordCount)
        
        // Estimate per-sentence durations for timeline
        let wordsPerMinute: Double = 150 // Average speaking rate for timeline estimation
        estimatedSentenceDurations = sentences.map { sentence in
            let words = sentence.split(separator: " ").count
            return (Double(words) / wordsPerMinute) * 60.0
        }
        
        isSeekable = true
        // Initialize timeToComplete at start (force update on initial load)
        updateTimeToComplete(forceUpdate: true)
    }
    
    func updateTimeToComplete(forceUpdate: Bool = false) {
        guard !sentences.isEmpty else {
            timeToComplete = 0.0
            totalDuration = 0.0
            return
        }
        
        // Count remaining words from currentIndex onwards
        var remainingWordCount = 0
        let startIndex = min(currentIndex, sentences.count)
        
        for i in startIndex..<sentences.count {
            let sentence = sentences[i]
            let tokens = WordTokenizer.tokenize(sentence)
            remainingWordCount += tokens.count
        }
        
        // Calculate new time to complete: 0.4 seconds per remaining word
        let newTimeToComplete = 0.4 * Double(remainingWordCount)
        
        // Update timeToComplete if forced (initial load) or if the difference is greater than 5 seconds
        if forceUpdate || abs(newTimeToComplete - timeToComplete) > 5.0 {
            timeToComplete = newTimeToComplete
        }
        
        // Also update the overall totalDuration so the slider end reflects the latest estimate.
        // New total estimate = elapsed time so far + remaining time.
        let proposedTotalDuration = currentTime + newTimeToComplete
        if forceUpdate || abs(proposedTotalDuration - totalDuration) > 5.0 {
            totalDuration = proposedTotalDuration
        }
    }
    
    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateCurrentTime()
            }
        }
    }
    
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    private func updateCurrentTime() {
        switch appVoice {
        case .system:
            if let startTime = playbackStartTime {
                currentTime = sentenceStartTime + Date().timeIntervalSince(startTime)
            }
        case .backend:
            if let player = audioPlayer {
                currentTime = getSentenceStartTime(currentIndex) + player.currentTime
            }
        }
    }
}

extension TTSPlayer {

    private func estimateWordIndex(in sentence: String, range: NSRange) -> Int? {
        guard let r = Range(range, in: sentence) else { return nil }
        let prefix = sentence[sentence.startIndex..<r.lowerBound]
        // Split by whitespace; basic tokenization (normalizer can replace)
        let tokens = prefix.split { $0.isWhitespace }.count
        return tokens
    }
    
    private func makeContentId(text: String, url: URL?, title: String?) -> String {
        let u = url?.absoluteString ?? ""
        let t = title ?? ""
        let key = "\(t)\n\(u)\n\(text)"
        return String(key.hashValue)
    }
}

