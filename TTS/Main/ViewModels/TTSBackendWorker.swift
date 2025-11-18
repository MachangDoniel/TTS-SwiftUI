//
//  TTSBackendWorker.swift
//  TTS
//
//  Created by Doniel Tripura on 11/2/25.
//


import Foundation
import AVFoundation

@MainActor
final class TTSBackendWorker {
    private let taskViewModel = TaskViewModel()
    private let speechViewModel = SpeechViewModel()
    private var audioCache: [Int: URL] = [:]
    private var backendTaskId: String?
    private var backendRequestId: String?
    private var backendWorkerTask: Task<Void, Never>?
    private var audioPlayer: AVAudioPlayer?
    private let downloadQueue = DispatchQueue(label: "tts.backend.download")
    private var activeVoiceSampleId: String?

    // MARK: - Core Controls

    func startFlow(
        sentences: [String],
        currentIndex: Int,
        selectedVoiceSampleId: String,
        player: TTSPlayer,
        resumeAt: Int? = nil
    ) {
        guard !sentences.isEmpty else { return }
        let resumeIndexRaw = resumeAt ?? currentIndex
        let resumeIndex = max(0, min(resumeIndexRaw, sentences.count - 1))
        let requestedVoice = selectedVoiceSampleId

        if activeVoiceSampleId != requestedVoice {
            pruneCacheForNewVoice(resumingAt: resumeIndex)
            activeVoiceSampleId = requestedVoice
        }

        backendWorkerTask?.cancel()

        backendWorkerTask = Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            do {
                try await self.prepareAndGenerate(
                    sentences: sentences,
                    resumeIndex: resumeIndex,
                    voiceSampleId: requestedVoice,
                    player: player
                )
            } catch {
                Logger.error(error)
            }
        }
    }

    func cancel() {
        backendWorkerTask?.cancel()
        backendTaskId = nil
        backendRequestId = nil
        audioCache.removeAll()
        audioPlayer?.stop()
        audioPlayer = nil
        activeVoiceSampleId = nil
    }

    func pause() { audioPlayer?.pause() }
    func resume() { audioPlayer?.play() }

    func stopCurrent(player: TTSPlayer) {
        audioPlayer?.stop()
        audioPlayer = nil
        player.state = .idle
    }

    func cancelGenerationOnly(keepingAudio: Bool) {
        backendWorkerTask?.cancel()
        backendWorkerTask = nil
        backendRequestId = nil
        if !keepingAudio {
            audioCache.removeAll()
            backendTaskId = nil
            audioPlayer?.stop()
            audioPlayer = nil
        }
    }

    func refreshVoice(with voiceId: String, currentIndex: Int, sentences: [String], player: TTSPlayer) {
        guard appHasUpcomingSentence(currentIndex: currentIndex, sentences: sentences) else { return }

        // Keep audio up to the sentence currently playing; regenerate future chunks.
        let keepOrderUpperBound = currentIndex + 1
        audioCache = audioCache.filter { $0.key <= keepOrderUpperBound }

        backendWorkerTask?.cancel()
        backendWorkerTask = nil
        backendRequestId = nil
        backendTaskId = nil
        activeVoiceSampleId = nil

        let resumeIndex = min(currentIndex + 1, sentences.count - 1)
        startFlow(
            sentences: sentences,
            currentIndex: currentIndex,
            selectedVoiceSampleId: voiceId,
            player: player,
            resumeAt: resumeIndex
        )
    }

    func playNext(from index: Int, sentences: [String], player: TTSPlayer) {
        guard !sentences.isEmpty else { return }
        let nextOrder = index + 1
        if let url = audioCache[nextOrder] {
            playAudio(from: url, order: nextOrder, sentences: sentences, player: player)
        } else {
            startFlow(
                sentences: sentences,
                currentIndex: index,
                selectedVoiceSampleId: activeVoiceSampleId ?? player.selectedVoiceSampleId,
                player: player,
                resumeAt: index
            )
        }
    }

    func playPrevious(from index: Int, sentences: [String], player: TTSPlayer) {
        guard index >= 0 else { return }
        let order = index + 1
        if let url = audioCache[order] {
            playAudio(from: url, order: order, sentences: sentences, player: player)
        } else {
            // Generate the required chunk again
            backendWorkerTask?.cancel()
            backendWorkerTask = nil
            backendRequestId = nil
            backendTaskId = nil
            startFlow(
                sentences: sentences,
                currentIndex: max(0, order - 1),
                selectedVoiceSampleId: activeVoiceSampleId ?? player.selectedVoiceSampleId,
                player: player,
                resumeAt: max(0, order - 1)
            )
        }
    }

    func handleAudioFinished(player: TTSPlayer) {
        Task { @MainActor in
            let justPlayedOrder = player.currentIndex + 1
            player.progress = Double(justPlayedOrder) / Double(max(1, player.sentences.count))
            let nextOrder = justPlayedOrder + 1
            if nextOrder <= player.sentences.count,
               let url = audioCache[nextOrder] {
                playAudio(from: url, order: nextOrder, sentences: player.sentences, player: player)
            } else if nextOrder <= player.sentences.count {
                startFlow(
                    sentences: player.sentences,
                    currentIndex: player.currentIndex,
                    selectedVoiceSampleId: activeVoiceSampleId ?? player.selectedVoiceSampleId,
                    player: player,
                    resumeAt: player.currentIndex
                )
            } else {
                player.state = .finished
                player.currentWordInSentence = ""
                player.currentWordRange = nil
            }
        }
    }

    // MARK: - Private Backend Logic
    private func prepareAndGenerate(
        sentences: [String],
        resumeIndex: Int,
        voiceSampleId: String,
        player: TTSPlayer
    ) async throws {
        if backendTaskId == nil {
            await taskViewModel.createTask(
                title: player.currentTitle ?? "Untitled",
                visitorId: "iOS Visitor",
                userId: nil,
                voiceSampleId: voiceSampleId,
                platform: "IOS",
                totalChunks: sentences.count
            )
            backendTaskId = await taskViewModel.taskId
        }

        guard let ensuredTaskId = backendTaskId else { return }

        for order in (resumeIndex + 1)...sentences.count {
            if Task.isCancelled { return }
            let text = sentences[order - 1]

            let currentRequest = backendRequestId
            await speechViewModel.generateSpeech(
                taskId: ensuredTaskId,
                requestId: currentRequest,
                inputText: text,
                order: order
            )

            if backendRequestId == nil {
                backendRequestId = await speechViewModel.speechData?.requestId
            }

            var downloadURL: String?
            while downloadURL == nil {
                try await Task.sleep(nanoseconds: 1_500_000_000)
                let reqId = backendRequestId ?? ""
                await speechViewModel.checkStatus(
                    taskId: ensuredTaskId,
                    requestId: reqId,
                    inputText: text,
                    order: order
                )
                downloadURL = await speechViewModel.speechData?.downloadUrl
            }

            if let urlStr = downloadURL, let remote = URL(string: urlStr) {
                do {
                    let local = try await downloadToCache(remote: remote, order: order)
                    await MainActor.run {
                        audioCache[order] = local
                        if order == player.currentIndex + 1 && player.state != .paused {
                            playAudio(from: local, order: order, sentences: sentences, player: player)
                        }
                    }
                } catch {
                    Logger.error(error)
                }
            }
        }
    }

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

    private func playAudio(from url: URL, order: Int, sentences: [String], player: TTSPlayer) {
        do {
            audioPlayer?.stop()
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = player
            audioPlayer?.prepareToPlay()
            player.currentIndex = order - 1
            player.currentSentenceText = sentences[player.currentIndex]
            player.lastPlayedContentId = player.preparedContentId
            player.progress = Double(order) / Double(max(1, sentences.count))
            audioPlayer?.play()
            player.state = .playing
            Logger.log("🔊 [Backend] Playing order \(order)/\(sentences.count)")
        } catch {
            Logger.error(error)
        }
    }

    private func pruneCacheForNewVoice(resumingAt resumeIndex: Int) {
        backendWorkerTask?.cancel()
        backendWorkerTask = nil
        backendRequestId = nil
        backendTaskId = nil

        let keepUpperBound = resumeIndex
        audioCache = audioCache.filter { $0.key <= keepUpperBound }
    }

    private func appHasUpcomingSentence(currentIndex: Int, sentences: [String]) -> Bool {
        guard !sentences.isEmpty else { return false }
        return currentIndex < sentences.count - 1
    }
}

