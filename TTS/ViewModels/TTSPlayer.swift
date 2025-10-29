//
//  TTSPlayer.swift
//  TTS
//
//  Created by Doniel Tripura on 10/5/25.
//

import Foundation
import AVFoundation
import Combine

// MARK: - Configuration + State

struct TTSConfiguration {
    var language: String = "en-US"
    var rate: Float = AVSpeechUtteranceDefaultSpeechRate
}

enum TTSPlayerState {
    case idle
    case playing
    case paused
    case finished
}

enum AppVoiceMode: String, Codable {
    case `default`
    case backend
}

/// A text-to-speech player that reads text sentence-by-sentence,
/// and also tracks the currently spoken word within the sentence.
/// Supports Apple on-device voice ("default") and backend voice ("backend").
@MainActor
class TTSPlayer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {

    // MARK: - Published Properties (UI)

    /// All sentences extracted from the input text
    @Published var sentences: [String] = []

    /// Current sentence index being spoken
    @Published var currentIndex: Int = 0

    /// Indicates current high-level state
    @Published var state: TTSPlayerState = .idle {
        didSet {
            switch state {
            case .idle, .finished:
                isSpeaking = false
                isPaused = false
            case .playing:
                isSpeaking = true
                isPaused = false
            case .paused:
                isSpeaking = true
                isPaused = true
            }
        }
    }

    /// Mirror booleans used in existing UI
    @Published var isSpeaking: Bool = false
    @Published var isPaused: Bool = false

    /// Indicates whether any item is currently active
    @Published var hasActiveItem: Bool = false

    /// Normalized progress (0.0...1.0) across sentences
    @Published var progress: Double = 0.0

    /// Optional metadata
    @Published var currentTitle: String? = nil

    /// The URL of the current source being read (PDF, TXT, etc.)
    @Published var currentURL: URL? = nil

    /// The full sentence currently being read
    @Published var currentSentenceText: String = ""

    /// The current word being spoken (within the current sentence) – Apple flow only
    @Published var currentWordInSentence: String = ""

    /// The range of the current word in the current sentence – Apple flow only
    @Published var currentWordRange: NSRange? = nil

    /// Switchable voice pipeline
    @Published var appVoice: AppVoiceMode = .default

    /// Backend voice sample selection (defaults to "1")
    @Published var selectedVoiceSampleId: String = "1"

    // MARK: - Properties
    private let config: TTSConfiguration
    private let parser = TTSSentenceParser()
    var synthesizer = AVSpeechSynthesizer()

    // Backend playback
    private var audioPlayer: AVAudioPlayer?
    private var audioCache: [Int: URL] = [:]        // order -> local file URL
    private var backendTaskId: String?
    private var backendRequestId: String?           // first response provides this; reuse after
    private var backendWorkerTask: Task<Void, Never>?
    private let downloadQueue = DispatchQueue(label: "tts.backend.download")

    // Backend API VMs (reuse your implementations)
    private let taskViewModel = TaskViewModel()
    private let speechViewModel = SpeechViewModel()

    // MARK: - Init
    init(config: TTSConfiguration = .init()) {
        self.config = config
        super.init()
        synthesizer.delegate = self
    }

    deinit {
        backendWorkerTask?.cancel()
    }

    // MARK: - Public Methods

    /// Starts reading the full text from the beginning.
    @MainActor
    func startReading(_ text: String) {
        stop()
        hasActiveItem = true
        state = .playing
        progress = 0.0
        sentences = splitIntoSentences(text)
        currentIndex = 0
        currentSentenceText = sentences.first ?? ""

        switch appVoice {
        case .default:
            speakCurrentSentence_Apple()
        case .backend:
            startBackendFlow()
        }
    }

    /// Pauses or resumes speech depending on current state.
    @MainActor
    func togglePlayPause() {
        switch appVoice {
        case .default:
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
        case .backend:
            switch state {
            case .playing:
                audioPlayer?.pause()
                state = .paused
            case .paused:
                audioPlayer?.play()
                state = .playing
            case .idle, .finished:
                // If we have cache for current index, resume that
                let order = currentIndex + 1
                if let url = audioCache[order] {
                    playBackendAudio(from: url, order: order)
                } else {
                    // If nothing cached yet, (re)start backend flow
                    startBackendFlow(resumeAt: currentIndex)
                }
                state = .playing
            }
        }
    }

    @MainActor
    func pause() {
        switch appVoice {
        case .default:
            guard state == .playing else { return }
            synthesizer.pauseSpeaking(at: .immediate)
            state = .paused
        case .backend:
            guard state == .playing else { return }
            audioPlayer?.pause()
            state = .paused
        }
    }

    @MainActor
    func resume() {
        switch appVoice {
        case .default:
            guard state == .paused else { return }
            synthesizer.continueSpeaking()
            state = .playing
        case .backend:
            guard state == .paused else { return }
            audioPlayer?.play()
            state = .playing
        }
    }

    /// Stops all speech immediately.
    @MainActor
    func stop() {
        // Shared resets
        hasActiveItem = false
        progress = 0.0
        currentWordInSentence = ""
        currentSentenceText = ""
        currentWordRange = nil

        switch appVoice {
        case .default:
            synthesizer.stopSpeaking(at: .immediate)
        case .backend:
            audioPlayer?.stop()
            audioPlayer = nil
            backendWorkerTask?.cancel()
            backendWorkerTask = nil
            backendTaskId = nil
            backendRequestId = nil
            audioCache.removeAll()
        }

        state = .idle
        sentences = []
        currentIndex = 0
    }

    /// Moves to the next sentence (if available).
    @MainActor
    func nextSentence() {
        guard currentIndex < sentences.count - 1 else { return }
        switch appVoice {
        case .default:
            synthesizer.stopSpeaking(at: .immediate) // immediate cut to next
            currentIndex += 1
            state = .playing
            speakCurrentSentence_Apple()
        case .backend:
            audioPlayer?.stop()
            let nextOrder = currentIndex + 2
            currentIndex = nextOrder - 1
            state = .playing
            if let url = audioCache[nextOrder] {
                playBackendAudio(from: url, order: nextOrder)
            } else {
                // ensure backend worker is running & will fetch this
                startBackendFlow(resumeAt: currentIndex)
            }
        }
    }

    /// Moves to the previous sentence (if available).
    @MainActor
    func previousSentence() {
        guard currentIndex > 0 else { return }
        switch appVoice {
        case .default:
            synthesizer.stopSpeaking(at: .immediate)
            currentIndex -= 1
            state = .playing
            speakCurrentSentence_Apple()
        case .backend:
            audioPlayer?.stop()
            let prevOrder = currentIndex // since order is index+1
            currentIndex = prevOrder - 1
            state = .playing
            if let url = audioCache[prevOrder] {
                playBackendAudio(from: url, order: prevOrder)
            } else {
                startBackendFlow(resumeAt: currentIndex)
            }
        }
    }

    // MARK: - Private Helpers (Common)

    /// Splits text into sentences but also preserves headings and lists
    private func splitIntoSentences(_ text: String) -> [String] {
        parser.splitIntoSentencesPreservingHeadings(text)
    }

    private func updateProgressForSentence() {
        progress = sentences.isEmpty ? 0.0 : Double(currentIndex) / Double(max(1, sentences.count))
    }

    // MARK: - Apple Voice Flow

    /// Speaks the current sentence aloud with AVSpeechSynthesizer.
    private func speakCurrentSentence_Apple() {
        guard sentences.indices.contains(currentIndex) else { return }

        let sentence = sentences[currentIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        currentSentenceText = sentence

        let utterance = AVSpeechUtterance(string: sentence)

        // For Free/system voices, choose exact AVSpeechSynthesisVoice by identifier.
        // For Premium/backend voices, this is handled in backend flow.
        let selectedId = selectedVoiceSampleId
        if let sysVoice = AVSpeechSynthesisVoice(identifier: selectedId) {
            utterance.voice = sysVoice
        } else {
            // fallback to language
            utterance.voice = AVSpeechSynthesisVoice(language: config.language)
        }

        utterance.rate = config.rate
        synthesizer.speak(utterance)

        state = .playing
        updateProgressForSentence()

        #if DEBUG
        Logger.log("🔊 [Apple] Reading sentence \(currentIndex + 1)/\(sentences.count): \(sentence)")
        #endif
    }

    // MARK: - AVSpeechSynthesizerDelegate (Apple mode only)

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
            self.currentWordInSentence = ""
            self.progress = self.sentences.isEmpty ? 1.0 : Double(self.currentIndex + 1) / Double(max(1, self.sentences.count))

            if self.currentIndex < self.sentences.count - 1 {
                self.currentIndex += 1
                self.speakCurrentSentence_Apple()
                self.state = .playing
            } else {
                self.state = .finished
                self.hasActiveItem = false
            }
        }
    }

    /// Called when speech is cancelled or stopped prematurely.
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.currentWordInSentence = ""
            // do not force .idle here; caller decides via stop()
        }
    }

    // MARK: - Backend Flow

    /// Start/Resume backend flow. If `resumeAt` is provided, ensure generation targets that index onward.
    @MainActor
    private func startBackendFlow(resumeAt: Int? = nil) {
        backendWorkerTask?.cancel()

        let resumeIndex = resumeAt ?? currentIndex
        if sentences.isEmpty || !sentences.indices.contains(resumeIndex) {
            state = .finished
            return
        }

        // Reset for fresh run (if new content)
        if backendTaskId == nil {
            audioCache.removeAll()
            backendRequestId = nil
        }

        backendWorkerTask = Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            do {
                // Snapshot values that won't change during this run
                let snapshot: (title: String, totalChunks: Int, selectedVoice: String, resumeIndex: Int, sentencesCopy: [String]) = await MainActor.run { [
                    currentTitle = self.currentTitle ?? "Untitled",
                    total = self.sentences.count,
                    voice = self.selectedVoiceSampleId.isEmpty ? "1" : self.selectedVoiceSampleId,
                    resume = resumeIndex,
                    sents = self.sentences
                ] in (title: currentTitle, totalChunks: total, selectedVoice: voice, resumeIndex: resume, sentencesCopy: sents) }

                // Ensure task exists (read & write main-actor properties via MainActor.run)
                var taskId: String? = await MainActor.run { self.backendTaskId }
                if taskId == nil {
                    await self.taskViewModel.createTask(
                        title: snapshot.title,
                        visitorId: "Test Visitor 1",
                        userId: nil,
                        voiceSampleId: snapshot.selectedVoice,
                        platform: "IOS",
                        totalChunks: snapshot.totalChunks
                    )
                    let newId = await self.taskViewModel.taskId
                    await MainActor.run { self.backendTaskId = newId }
                    taskId = newId
                    if taskId == nil { return }
                }

                guard let ensuredTaskId = taskId else { return }

                // Kick off generation for resumeIndex...end
                for order in (snapshot.resumeIndex + 1)...snapshot.totalChunks {
                    if Task.isCancelled { return }

                    // If already cached, skip (read on main actor)
                    let alreadyCached: Bool = await MainActor.run { self.audioCache[order] != nil }
                    if alreadyCached { continue }

                    let text = snapshot.sentencesCopy[order - 1]

                    // Request generation using current requestId (read on main actor)
                    let currentRequestId: String? = await MainActor.run { self.backendRequestId }
                    await self.speechViewModel.generateSpeech(
                        taskId: ensuredTaskId,
                        requestId: currentRequestId,
                        inputText: text,
                        order: order
                    )

                    // Update requestId if first time
                    if currentRequestId == nil {
                        let newReqId = await self.speechViewModel.speechData?.requestId
                        await MainActor.run { self.backendRequestId = newReqId }
                    }

                    // Poll for status until downloadUrl available
                    var downloadURL: String?
                    while downloadURL == nil {
                        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s
                        let reqId: String = await MainActor.run { self.backendRequestId ?? "" }
                        await self.speechViewModel.checkStatus(
                            taskId: ensuredTaskId,
                            requestId: reqId,
                            inputText: text,
                            order: order
                        )
                        downloadURL = await self.speechViewModel.speechData?.downloadUrl
                        if Task.isCancelled { return }
                    }

                    // Download and cache
                    if let urlStr = downloadURL, let remote = URL(string: urlStr) {
                        do {
                            let local = try await self.downloadToCache(remote: remote, order: order)
                            await MainActor.run {
                                self.audioCache[order] = local
                                // Autoplay if this is the current needed order and not paused
                                if order == self.currentIndex + 1, self.state != .paused {
                                    self.playBackendAudio(from: local, order: order)
                                }
                            }
                        } catch {
                            Logger.log("❌ Download error (order \(order)): \(error.localizedDescription)")
                        }
                    }
                }
            } catch {
                Logger.log("❌ Backend worker error: \(error.localizedDescription)")
            }
        }
    }

    /// Download remote audio to cache directory
    private func downloadToCache(remote: URL, order: Int) async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            downloadQueue.async {
                do {
                    let data = try Data(contentsOf: remote)
                    let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                    let fileURL = dir.appendingPathComponent("tts_chunk_\(order).mp3")
                    try data.write(to: fileURL, options: .atomic)
                    cont.resume(returning: fileURL)
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    /// Play a cached backend chunk (for given order = index+1)
    @MainActor
    private func playBackendAudio(from url: URL, order: Int) {
        do {
            audioPlayer?.stop()
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            currentIndex = order - 1
            currentSentenceText = sentences[currentIndex]
            updateProgressForSentence()
            audioPlayer?.play()
            state = .playing

            Logger.log("🔊 [Backend] Playing order \(order)/\(sentences.count): \(sentences[currentIndex])")
        } catch {
            Logger.log("❌ Playback error: \(error.localizedDescription)")
        }
    }

    // MARK: - AVAudioPlayerDelegate (Backend mode)

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            let justPlayedOrder = currentIndex + 1
            let nextOrder = justPlayedOrder + 1
            progress = sentences.isEmpty ? 1.0 : Double(justPlayedOrder) / Double(max(1, sentences.count))

            if nextOrder <= sentences.count {
                if let nextURL = audioCache[nextOrder] {
                    playBackendAudio(from: nextURL, order: nextOrder)
                } else {
                    // Wait until backend worker generates it; remain in playing state
                    // Ensure worker is running
                    startBackendFlow(resumeAt: currentIndex + 1)
                }
            } else {
                state = .finished
                hasActiveItem = false
            }
        }
    }
}

final class TTSSentenceParser {

    /// Splits text into sentences but also preserves headings (lines without trailing punctuation)
    func splitIntoSentencesPreservingHeadings(_ text: String) -> [String] {
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
            if let re = numberedRegex,
               re.firstMatch(in: s, options: [], range: NSRange(location: 0, length: (s as NSString).length)) != nil {
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
                    return String(first).uppercased() == String(first)
                        && token.dropFirst().allSatisfy { $0.isLowercase || !$0.isLetter }
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
                flushPara()
                continue
            }
            if isBulletOrNumbered(line) || isLikelyHeading(line) {
                flushPara()
                paragraphs.append(line)
                continue
            }
            currentPara.append(line)
        }
        flushPara()

        // 4) Split paragraphs into sentences (headings/bullets will be single-item paragraphs)
        var results: [String] = []
        for para in paragraphs {
            if isBulletOrNumbered(para) || isLikelyHeading(para) {
                results.append(para)
                continue
            }

            if let re = sentenceRegex {
                let ns = para as NSString
                let range = NSRange(location: 0, length: ns.length)
                var lastIndex = 0
                re.enumerateMatches(in: para, options: [], range: range) { match, _, _ in
                    guard let match = match else { return }
                    let end = match.range.location + match.range.length
                    let sentence = ns.substring(with: NSRange(location: lastIndex, length: end - lastIndex))
                        .trimmingCharacters(in: .whitespaces)
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
}

