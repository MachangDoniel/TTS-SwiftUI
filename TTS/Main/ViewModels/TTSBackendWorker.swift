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

    // MARK: - Core Controls

    func startFlow(
        sentences: [String],
        currentIndex: Int,
        selectedVoiceSampleId: String,
        player: TTSPlayer,
        resumeAt: Int? = nil
    ) {
        backendWorkerTask?.cancel()
        let resumeIndex = resumeAt ?? currentIndex

        backendWorkerTask = Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            do {
                try await self.prepareAndGenerate(sentences: sentences, resumeIndex: resumeIndex,
                                              voiceSampleId: selectedVoiceSampleId, player: player)
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
    }

    func pause() { audioPlayer?.pause() }
    func resume() { audioPlayer?.play() }

    func playNext(from index: Int, sentences: [String], player: TTSPlayer) {
        let nextOrder = index + 1
        if let url = audioCache[nextOrder] {
            playAudio(from: url, order: nextOrder, sentences: sentences, player: player)
        }
    }

    func playPrevious(from index: Int, sentences: [String], player: TTSPlayer) {
        let prevOrder = index + 1
        if let url = audioCache[prevOrder] {
            playAudio(from: url, order: prevOrder, sentences: sentences, player: player)
        }
    }

    func handleAudioFinished(player: TTSPlayer) {
        Task { @MainActor in
            let justPlayed = player.currentIndex + 1
            let next = justPlayed + 1
            player.progress = Double(justPlayed) / Double(max(1, player.sentences.count))
            if next <= player.sentences.count {
                if let url = audioCache[next] {
                    playAudio(from: url, order: next, sentences: player.sentences, player: player)
                }
            } else {
                player.state = .finished
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
            player.progress = Double(order) / Double(max(1, sentences.count))
            audioPlayer?.play()
            player.state = .playing
            Logger.log("🔊 [Backend] Playing order \(order)/\(sentences.count)")
        } catch {
            Logger.error(error)
        }
    }
}
