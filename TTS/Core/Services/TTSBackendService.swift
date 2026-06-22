//
//  TTSBackendWorker.swift
//  TTS
//
//  Created by Doniel Tripura on 11/2/25.
//

import Foundation
import AVFoundation

@MainActor
final class TTSBackendService {
    private let jobService = PublicTTSJobService()
    private let chunkStore = BackendChunkStore.shared
    private var audioCache: [Int: URL] = [:]
    private var backendRequestId: String?
    private var backendWorkerTask: Task<Void, Never>?
    private var activeFlowSignature: String?
    private var inFlightOrders: Set<Int> = []
    private var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?
    private var currentPlaybackOrder: Int?
    private weak var currentPlayerOwner: TTSPlayer?
    private let downloadQueue = DispatchQueue(label: "tts.backend.download")
    private var activeVoiceSampleId: String?
    private let onlineLibraryStore = OnlineLibraryStore.shared

    func startFlow(
        sentences: [String],
        currentIndex: Int,
        selectedVoiceSampleId: String,
        player: TTSPlayer,
        resumeAt: Int? = nil
    ) {
        guard !sentences.isEmpty else { return }
        let resumeIndex = max(0, min(resumeAt ?? currentIndex, sentences.count - 1))
        let requestedVoice = selectedVoiceSampleId
        let flowSignature = makeFlowSignature(
            sentences: sentences,
            resumeIndex: resumeIndex,
            voiceSampleId: requestedVoice,
            title: player.currentTitle,
            currentURL: player.currentURL
        )

        if activeFlowSignature == flowSignature,
           let existingTask = backendWorkerTask,
           !existingTask.isCancelled {
            return
        }

        if activeVoiceSampleId != requestedVoice {
            pruneCacheForNewVoice(resumingAt: resumeIndex)
            activeVoiceSampleId = requestedVoice
        }

        activeFlowSignature = flowSignature
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
                await MainActor.run {
                    player.backendJobPhase = .failed
                }
                Logger.error(error)
            }
        }
    }

    func cancel() {
        stopProgressTimer()
        backendWorkerTask?.cancel()
        backendWorkerTask = nil
        backendRequestId = nil
        activeFlowSignature = nil
        inFlightOrders.removeAll()
        audioCache.removeAll()
        audioPlayer?.stop()
        audioPlayer = nil
        currentPlaybackOrder = nil
        activeVoiceSampleId = nil
    }

    func pause() {
        audioPlayer?.pause()
        stopProgressTimer()
    }

    func resume() {
        audioPlayer?.play()
        startProgressTimer()
    }

    func stopCurrent(player: TTSPlayer) {
        stopProgressTimer()
        audioPlayer?.stop()
        audioPlayer = nil
        currentPlaybackOrder = nil
        player.state = .idle
    }

    func cancelGenerationOnly(keepingAudio: Bool) {
        stopProgressTimer()
        backendWorkerTask?.cancel()
        backendWorkerTask = nil
        activeFlowSignature = nil
        inFlightOrders.removeAll()
        if !keepingAudio {
            backendRequestId = nil
            audioCache.removeAll()
            audioPlayer?.stop()
            audioPlayer = nil
            currentPlaybackOrder = nil
        }
    }

    func refreshVoice(with voiceId: String, currentIndex: Int, sentences: [String], player: TTSPlayer) {
        guard appHasUpcomingSentence(currentIndex: currentIndex, sentences: sentences) else { return }

        let keepOrderUpperBound = currentIndex + 1
        audioCache = audioCache.filter { $0.key <= keepOrderUpperBound }
        backendWorkerTask?.cancel()
        backendWorkerTask = nil
        activeFlowSignature = nil
        inFlightOrders.removeAll()
        activeVoiceSampleId = nil
        backendRequestId = nil

        let resumeIndex = min(currentIndex + 1, sentences.count - 1)
        startFlow(
            sentences: sentences,
            currentIndex: currentIndex,
            selectedVoiceSampleId: voiceId,
            player: player,
            resumeAt: resumeIndex
        )
    }

    func restoreSavedDocument(
        requestId: String,
        voiceSampleId: String,
        startOrder: Int = 1,
        sentences: [String],
        player: TTSPlayer
    ) {
        guard !sentences.isEmpty else { return }

        backendRequestId = requestId
        activeVoiceSampleId = voiceSampleId
        player.backendJobPhase = .completed
        player.backendJobProgress = 100
        player.state = .loading

        if let chunk = chunkStore.fetchChunk(documentRequestId: requestId, chunkIndex: startOrder) {
            if let localAudioPath = chunk.localAudioPath,
               FileManager.default.fileExists(atPath: localAudioPath) {
                let url = URL(fileURLWithPath: localAudioPath)
                audioCache[startOrder] = url
                playAudio(from: url, order: startOrder, sentences: sentences, player: player)
                return
            }

            if let remoteAudioURL = chunk.remoteAudioURL,
               let remote = URL(string: remoteAudioURL) {
                Task.detached(priority: .utility) { [weak self] in
                    guard let self else { return }
                    do {
                        let local = try await self.downloadToCache(
                            remote: remote,
                            requestId: requestId,
                            order: startOrder
                        )
                        self.chunkStore.saveChunk(
                            documentRequestId: requestId,
                            chunkIndex: startOrder,
                            remoteAudioURL: remoteAudioURL,
                            localAudioPath: local.path
                        )
                        await self.syncOnlineLibraryAudioMetadata(documentRequestId: requestId)
                        await MainActor.run {
                            self.audioCache[startOrder] = local
                            self.playAudio(from: local, order: startOrder, sentences: sentences, player: player)
                        }
                    } catch {
                        await MainActor.run {
                            player.backendJobPhase = .failed
                        }
                        Logger.error(error)
                    }
                }
                return
            }
        }

        startFlow(
            sentences: sentences,
            currentIndex: max(0, startOrder - 1),
            selectedVoiceSampleId: voiceSampleId,
            player: player,
            resumeAt: max(0, startOrder - 1)
        )
    }
}

extension TTSBackendService {
    func playNext(from index: Int, sentences: [String], player: TTSPlayer) {
        guard !sentences.isEmpty else { return }
        let nextOrder = index + 1
        if let url = audioCache[nextOrder] {
            playAudio(from: url, order: nextOrder, sentences: sentences, player: player)
        } else {
            player.backendJobPhase = .prefetchingNextChunk
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
            return
        }

        if let documentRequestId = backendRequestId,
           let chunk = chunkStore.fetchChunk(documentRequestId: documentRequestId, chunkIndex: order),
           let localAudioPath = chunk.localAudioPath {
            let url = URL(fileURLWithPath: localAudioPath)
            audioCache[order] = url
            playAudio(from: url, order: order, sentences: sentences, player: player)
            return
        }

        player.backendJobPhase = .prefetchingNextChunk
        startFlow(
            sentences: sentences,
            currentIndex: max(0, order - 1),
            selectedVoiceSampleId: activeVoiceSampleId ?? player.selectedVoiceSampleId,
            player: player,
            resumeAt: max(0, order - 1)
        )
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
                player.currentTime = player.totalDuration
                player.state = .paused
                player.backendJobPhase = .prefetchingNextChunk
                player.backendPendingAutoAdvance = true
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
                player.backendPendingAutoAdvance = false
                player.updateTimeToComplete()
            }
        }
    }

    func seekPlayback(
        to time: TimeInterval,
        sentenceIndex: Int,
        sentences: [String],
        player: TTSPlayer,
        resume: Bool
    ) {
        guard sentences.indices.contains(sentenceIndex) else { return }

        let order = sentenceIndex + 1
        let effectiveTime = player.totalDuration > 0 ? min(max(time, 0), player.totalDuration) : max(time, 0)
        let localStart = max(0, effectiveTime - sentenceStartTime(for: order, durations: player.estimatedSentenceDurations))
        player.currentIndex = sentenceIndex
        player.currentSentenceText = sentences[sentenceIndex]
        player.currentWordInSentence = ""
        player.currentWordRange = nil
        player.currentWordIndexInSentence = nil
        player.currentWordToken = nil
        player.position = .init(sentenceIndex: sentenceIndex, wordNSRange: nil, wordIndex: nil)
        player.currentTime = effectiveTime
        player.progress = player.totalDuration > 0 ? min(effectiveTime / player.totalDuration, 1.0) : player.progress
        player.timeToComplete = max(player.totalDuration - player.currentTime, 0)

        let cachedURL: URL?

        if let url = audioCache[order] {
            cachedURL = url
        } else if
            let documentRequestId = backendRequestId,
            let chunk = chunkStore.fetchChunk(documentRequestId: documentRequestId, chunkIndex: order),
            let localAudioPath = chunk.localAudioPath,
            FileManager.default.fileExists(atPath: localAudioPath)
        {
            let url = URL(fileURLWithPath: localAudioPath)
            audioCache[order] = url
            cachedURL = url
        } else {
            cachedURL = nil
        }

        guard let url = cachedURL else {
            if resume {
                player.backendJobPhase = .prefetchingNextChunk
                player.backendPendingAutoAdvance = true
                startFlow(
                    sentences: sentences,
                    currentIndex: sentenceIndex,
                    selectedVoiceSampleId: activeVoiceSampleId ?? player.selectedVoiceSampleId,
                    player: player,
                    resumeAt: sentenceIndex
                )
            }
            return
        }

        if currentPlaybackOrder == order, let audioPlayer {
            let clampedStart = max(0, min(localStart, audioPlayer.duration))
            audioPlayer.currentTime = clampedStart
            player.currentTime = time
            player.progress = player.totalDuration > 0 ? min(time / player.totalDuration, 1.0) : player.progress
            player.timeToComplete = max(player.totalDuration - player.currentTime, 0)

            if resume {
                audioPlayer.play()
                player.state = .playing
                startProgressTimer()
            } else {
                audioPlayer.pause()
                player.state = .paused
                stopProgressTimer()
            }
            return
        }

        playAudio(
            from: url,
            order: order,
            sentences: sentences,
            player: player,
            startAt: localStart,
            shouldResume: resume
        )
    }
}

extension TTSBackendService {
    private func prepareAndGenerate(
        sentences: [String],
        resumeIndex: Int,
        voiceSampleId: String,
        player: TTSPlayer
    ) async throws {
        let voice = resolveBackendVoice(from: voiceSampleId)
        let fullText = sentences.joined(separator: "\n")

        if backendRequestId == nil {
            try await bootstrapInitialChunk(
                fullText: fullText,
                sentences: sentences,
                voice: voice,
                resumeIndex: resumeIndex,
                player: player
            )
        }

        guard let documentRequestId = backendRequestId else { return }
        let allStoredChunks = chunkStore.fetchAllChunks(documentRequestId: documentRequestId)
        let finalOrder = min(allStoredChunks.count, sentences.count)
        let prefetchDistance = max(1, player.backendAccessTier.prefetchDistance)
        let startingOrder = max(2, resumeIndex + 1)
        let targetOrder = min(finalOrder, startingOrder + prefetchDistance - 1)

        guard startingOrder <= targetOrder else { return }

        for order in startingOrder...targetOrder {
            if Task.isCancelled { return }
            if audioCache[order] != nil { continue }
            if inFlightOrders.contains(order) { continue }

            guard let chunkRecord = chunkStore.fetchChunk(documentRequestId: documentRequestId, chunkIndex: order),
                  let text = chunkRecord.text else {
                continue
            }

            inFlightOrders.insert(order)
            defer { inFlightOrders.remove(order) }

            await MainActor.run {
                player.backendJobPhase = .prefetchingNextChunk
            }

            let uploadFileURL = try jobService.makeUploadFile(
                text: text,
                requestId: documentRequestId,
                chunkIndex: order,
                fileExtension: "txt"
            )

            let uploadData = try await jobService.createUploadURL(
                UploadJobURLRequest(
                    userId: nil,
                    visitorId: "iOS Visitor",
                    characterCount: text.count,
                    voiceSampleId: voice.backendVoiceID ?? Int(voice.voiceSampleId) ?? 1,
                    languageCode: resolvedLanguageCode(for: text, voice: voice),
                    platform: "IOS",
                    scanner: false,
                    fileExtension: "txt"
                )
            )

            try await jobService.uploadFile(fileURL: uploadFileURL, to: uploadData.uploadUrl)
            _ = try await jobService.triggerSpeechGeneration(
                requestId: uploadData.requestId,
                userId: nil,
                visitorId: "iOS Visitor"
            )

            let status = try await jobService.waitForJobCompletion(
                requestId: uploadData.requestId,
                userId: nil,
                visitorId: "iOS Visitor",
                onUpdate: { [weak player] status in
                    Task { @MainActor in
                        player?.backendJobPhase = BackendJobPhase.fromRemoteStatus(status.status)
                        player?.backendJobProgress = status.progress
                    }
                }
            )

            guard let remoteAudioURL = status.downloadUrl,
                  let remote = URL(string: remoteAudioURL),
                  !remoteAudioURL.isEmpty else {
                continue
            }

            let local = try await downloadToCache(
                remote: remote,
                requestId: documentRequestId,
                order: order
            )
            chunkStore.saveChunk(
                documentRequestId: documentRequestId,
                chunkIndex: order,
                remoteAudioURL: remoteAudioURL,
                localAudioPath: local.path
            )

            await MainActor.run {
                audioCache[order] = local
                self.synchronizeTimeline(
                    documentRequestId: documentRequestId,
                    currentOrder: order,
                    currentPlayer: nil,
                    sentences: sentences,
                    player: player
                )
                player.backendJobPhase = .completed
                player.backendJobProgress = 100
                self.syncOnlineLibraryAudioMetadata(
                    documentRequestId: documentRequestId,
                    totalDuration: player.totalDuration
                )
                if order == player.currentIndex + 1 && (player.state != .paused || player.backendPendingAutoAdvance) {
                    playAudio(from: local, order: order, sentences: sentences, player: player)
                }
            }
        }
    }

    private func bootstrapInitialChunk(
        fullText: String,
        sentences: [String],
        voice: Voice,
        resumeIndex: Int,
        player: TTSPlayer
    ) async throws {
        let seedRequestId = UUID().uuidString

        await MainActor.run {
            player.backendJobPhase = .requestingUploadURL
            player.backendJobProgress = nil
        }

        let initialUpload = try jobService.prepareInitialUpload(
            originalFileURL: player.onlineProjectSourceURL ?? player.currentURL,
            fallbackText: fullText,
            requestId: seedRequestId,
            title: player.onlineProjectTitle ?? player.currentTitle
        )

        let initialUploadData = try await jobService.createUploadURL(
            UploadJobURLRequest(
                userId: nil,
                visitorId: "iOS Visitor",
                characterCount: fullText.count,
                voiceSampleId: voice.backendVoiceID ?? Int(voice.voiceSampleId) ?? 1,
                languageCode: resolvedLanguageCode(for: fullText, voice: voice),
                platform: "IOS",
                scanner: true,
                fileExtension: initialUpload.fileExtension
            )
        )

        backendRequestId = initialUploadData.requestId
        await MainActor.run {
            player.backendDocumentRequestId = initialUploadData.requestId
        }
        chunkStore.clearDocument(documentRequestId: initialUploadData.requestId)

        await MainActor.run {
            player.backendJobPhase = .uploadingSource
        }
        Logger.log("⬆️ [Backend] Uploading source file for request \(initialUploadData.requestId)")
        try await jobService.uploadFile(fileURL: initialUpload.fileURL, to: initialUploadData.uploadUrl)

        await MainActor.run {
            player.backendJobPhase = .triggeringSpeechGeneration
        }
        Logger.log("▶️ [Backend] Triggering speech generation for request \(initialUploadData.requestId)")
        let triggerStatus = try await jobService.triggerSpeechGeneration(
            requestId: initialUploadData.requestId,
            userId: nil,
            visitorId: "iOS Visitor"
        )

        await MainActor.run {
            player.backendJobPhase = BackendJobPhase.fromRemoteStatus(triggerStatus.status)
            player.backendJobProgress = triggerStatus.progress
        }

        let initialStatus = try await jobService.waitForJobCompletion(
            requestId: initialUploadData.requestId,
            userId: nil,
            visitorId: "iOS Visitor",
            onUpdate: { [weak player] status in
                Task { @MainActor in
                    player?.backendJobPhase = BackendJobPhase.fromRemoteStatus(status.status)
                    player?.backendJobProgress = status.progress
                }
            }
        )

        let chunkTextURLs = initialStatus.chunkTextUrls ?? []
        var transcriptParts: [String] = []
        transcriptParts.reserveCapacity(chunkTextURLs.count)

        for (index, sourceURL) in chunkTextURLs.enumerated() {
            let item = try await jobService.downloadChunkText(from: sourceURL, index: index)
            chunkStore.saveChunk(
                documentRequestId: initialUploadData.requestId,
                chunkIndex: item.index + 1,
                text: item.text,
                remoteTextURL: item.sourceURL
            )
            transcriptParts.append(item.text)
        }

        await MainActor.run {
            player.backendTranscript = transcriptParts.joined(separator: "\n\n")
        }

        let transcriptText = transcriptParts.joined(separator: "\n\n")
        if !transcriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let persistedFile = try jobService.persistTranscriptFile(
                text: transcriptText,
                requestId: initialUploadData.requestId,
                voiceName: voice.name,
                preferredBaseName: player.onlineProjectTitle ?? player.currentTitle?.replacingOccurrences(of: ".txt", with: "")
            )

            let originalSourceURL = player.onlineProjectSourceURL ?? player.currentURL
            let originalSourceString = originalSourceURL?.isFileURL == true
                ? originalSourceURL?.path ?? persistedFile.fileURL.path
                : originalSourceURL?.absoluteString ?? persistedFile.fileURL.path
            let originalExtension = originalSourceURL?.pathExtension.lowercased()
                ?? player.currentURL?.pathExtension.lowercased()
                ?? "txt"
            let projectTitle = player.onlineProjectTitle
                ?? player.currentTitle
                ?? persistedFile.fileName
            let projectKey = (originalSourceURL?.absoluteString ?? player.currentURL?.absoluteString ?? projectTitle)

            await MainActor.run {
                onlineLibraryStore.save(
                    item: OnlineLibraryItem(
                        title: persistedFile.fileName,
                        sourcePath: persistedFile.fileURL.path,
                        kind: .text,
                        thumbnailData: nil,
                        bookmarkData: nil,
                        wordCount: transcriptText.split { $0.isWhitespace || $0.isNewline }.count,
                        requestId: initialUploadData.requestId,
                        projectKey: projectKey,
                        projectTitle: projectTitle,
                        originalSourceURL: originalSourceString,
                        originalSourceExtension: originalExtension,
                        generatedTextFilePath: persistedFile.fileURL.path,
                        remoteTextURLs: chunkTextURLs,
                        remoteAudioURLs: [],
                        localAudioPaths: [],
                        voiceSampleId: voice.voiceSampleId,
                        voiceName: voice.name
                    )
                )
            }
        }

        guard let initialDownloadURL = initialStatus.downloadUrl,
              let remote = URL(string: initialDownloadURL),
              !initialDownloadURL.isEmpty else {
            return
        }

        chunkStore.saveChunk(
            documentRequestId: initialUploadData.requestId,
            chunkIndex: 1,
            remoteAudioURL: initialDownloadURL
        )

        let local = try await downloadToCache(
            remote: remote,
            requestId: initialUploadData.requestId,
            order: 1
        )
        chunkStore.saveChunk(
            documentRequestId: initialUploadData.requestId,
            chunkIndex: 1,
            localAudioPath: local.path
        )

        await MainActor.run {
            audioCache[1] = local
            self.synchronizeTimeline(
                documentRequestId: initialUploadData.requestId,
                currentOrder: 1,
                currentPlayer: nil,
                sentences: sentences,
                player: player
            )
            player.backendJobPhase = .completed
            player.backendJobProgress = 100
            self.syncOnlineLibraryAudioMetadata(
                documentRequestId: initialUploadData.requestId,
                totalDuration: player.totalDuration
            )
            if resumeIndex == 0 && player.state != .paused {
                playAudio(from: local, order: 1, sentences: sentences, player: player)
            }
        }
    }

    private func downloadToCache(remote: URL, requestId: String, order: Int) async throws -> URL {
        let (data, _) = try await URLSession.shared.data(from: remote)
        return try await withCheckedThrowingContinuation { cont in
            downloadQueue.async {
                do {
                    let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                    let sanitizedRequestId = requestId.replacingOccurrences(of: "/", with: "_")
                    let fileURL = dir.appendingPathComponent("\(sanitizedRequestId)_chunk_\(order).mp3")
                    try data.write(to: fileURL, options: .atomic)
                    cont.resume(returning: fileURL)
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }
}

extension TTSBackendService {
    @MainActor
    private func syncOnlineLibraryAudioMetadata(documentRequestId: String, totalDuration: TimeInterval? = nil) {
        guard let existing = onlineLibraryStore.items.first(where: { $0.requestId == documentRequestId }) else {
            return
        }

        let chunks = chunkStore.fetchAllChunks(documentRequestId: documentRequestId)
        let remoteAudioURLs = chunks.compactMap(\.remoteAudioURL)
        let localAudioPaths = chunks.compactMap(\.localAudioPath)

        var updated = existing
        updated.remoteAudioURLs = remoteAudioURLs
        updated.localAudioPaths = localAudioPaths
        if let totalDuration {
            updated.totalDuration = totalDuration
        }
        onlineLibraryStore.save(item: updated)
    }

    private func playAudio(
        from url: URL,
        order: Int,
        sentences: [String],
        player: TTSPlayer,
        startAt: TimeInterval = 0,
        shouldResume: Bool = true
    ) {
        do {
            stopProgressTimer()
            audioPlayer?.stop()
            configureAudioSessionForBackgroundPlayback()
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = player
            audioPlayer?.prepareToPlay()
            currentPlaybackOrder = order
            currentPlayerOwner = player
            synchronizeTimeline(
                documentRequestId: backendRequestId,
                currentOrder: order,
                currentPlayer: audioPlayer,
                sentences: sentences,
                player: player
            )
            player.currentIndex = order - 1
            player.currentSentenceText = sentences[player.currentIndex]
            player.lastPlayedContentId = player.preparedContentId
            let clampedStart = max(0, min(startAt, audioPlayer?.duration ?? startAt))
            audioPlayer?.currentTime = clampedStart
            player.currentTime = sentenceStartTime(for: order, durations: player.estimatedSentenceDurations) + clampedStart
            player.progress = player.totalDuration > 0 ? min(player.currentTime / player.totalDuration, 1.0) : player.progress
            player.timeToComplete = max(player.totalDuration - player.currentTime, 0)

            if shouldResume {
                audioPlayer?.play()
                player.state = .playing
                player.backendPendingAutoAdvance = false
                startProgressTimer()
                prefetchUpcomingChunks(after: order, sentences: sentences, player: player)
            } else {
                audioPlayer?.pause()
                player.state = .paused
                stopProgressTimer()
            }
            Logger.log("🔊 [Backend] Playing order \(order)/\(sentences.count)")
        } catch {
            Logger.error(error)
        }
    }

    private func pruneCacheForNewVoice(resumingAt resumeIndex: Int) {
        backendWorkerTask?.cancel()
        backendWorkerTask = nil
        activeFlowSignature = nil
        inFlightOrders.removeAll()
        backendRequestId = nil

        let keepUpperBound = resumeIndex
        audioCache = audioCache.filter { $0.key <= keepUpperBound }
    }

    private func appHasUpcomingSentence(currentIndex: Int, sentences: [String]) -> Bool {
        guard !sentences.isEmpty else { return false }
        return currentIndex < sentences.count - 1
    }

    private func makeFlowSignature(
        sentences: [String],
        resumeIndex: Int,
        voiceSampleId: String,
        title: String?,
        currentURL: URL?
    ) -> String {
        let titlePart = title ?? ""
        let urlPart = currentURL?.absoluteString ?? ""
        let textPart = sentences.joined(separator: "\n")
        return "\(voiceSampleId)|\(resumeIndex)|\(titlePart)|\(urlPart)|\(textPart.hashValue)"
    }

    private func resolveBackendVoice(from voiceSampleId: String) -> Voice {
        if let match = VoiceCatalog.shared.voices.first(where: { $0.voiceSampleId == voiceSampleId }) {
            return match
        }

        return Voice(
            name: "Backend Voice",
            language: "English",
            accent: "",
            type: VoiceType.Premium.rawValue,
            voiceSampleId: voiceSampleId,
            source: .remote,
            languageCode: "en",
            backendVoiceID: Int(voiceSampleId)
        )
    }

    private func resolvedLanguageCode(for text: String, voice: Voice) -> String {
        if let languageCode = voice.languageCode, !languageCode.isEmpty {
            return languageCode
        }
        return LanguageDetection.detectLanguage(from: text) ?? "en"
    }

    private func prefetchUpcomingChunks(after order: Int, sentences: [String], player: TTSPlayer) {
        let nextResumeIndex = order
        guard nextResumeIndex < sentences.count else { return }
        startFlow(
            sentences: sentences,
            currentIndex: max(0, order - 1),
            selectedVoiceSampleId: activeVoiceSampleId ?? player.selectedVoiceSampleId,
            player: player,
            resumeAt: nextResumeIndex
        )
    }

    private func configureAudioSessionForBackgroundPlayback() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            Logger.error(error)
        }
    }

    func getCachedAudio(for order: Int) -> URL? {
        audioCache[order]
    }

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard
                    let self,
                    let player = self.currentPlayerOwner,
                    let audioPlayer = self.audioPlayer,
                    let order = self.currentPlaybackOrder
                else {
                    return
                }

                let start = self.sentenceStartTime(for: order, durations: player.estimatedSentenceDurations)
                player.currentTime = start + audioPlayer.currentTime
                if player.totalDuration > 0 {
                    player.progress = min(player.currentTime / player.totalDuration, 1.0)
                    player.timeToComplete = max(player.totalDuration - player.currentTime, 0)
                }
                self.maybePrefetchNextChunk(
                    currentOrder: order,
                    audioPlayer: audioPlayer,
                    sentences: player.sentences,
                    player: player
                )
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func synchronizeTimeline(
        documentRequestId: String?,
        currentOrder: Int,
        currentPlayer: AVAudioPlayer?,
        sentences: [String],
        player: TTSPlayer
    ) {
        var durations = Array(repeating: 0.0, count: sentences.count)

        if let documentRequestId {
            let chunks = chunkStore.fetchAllChunks(documentRequestId: documentRequestId)
            for chunk in chunks {
                let index = chunk.chunkIndex - 1
                guard durations.indices.contains(index) else { continue }
                if let localAudioPath = chunk.localAudioPath,
                   FileManager.default.fileExists(atPath: localAudioPath),
                   let duration = audioDuration(at: URL(fileURLWithPath: localAudioPath)) {
                    durations[index] = duration
                }
            }
        }

        let currentIndex = currentOrder - 1
        if durations.indices.contains(currentIndex),
           durations[currentIndex] == 0,
           let currentPlayer {
            durations[currentIndex] = currentPlayer.duration
        }

        let resolvedDurations = durations
        let total = resolvedDurations.prefix(while: { $0 > 0 }).reduce(0, +)

        if resolvedDurations.contains(where: { $0 > 0 }) {
            player.estimatedSentenceDurations = resolvedDurations
            player.totalDuration = total > 0 ? total : player.totalDuration
            player.isSeekable = total > 0
            player.timeToComplete = max(total - sentenceStartTime(for: currentOrder, durations: resolvedDurations), 0)
        }
    }

    private func maybePrefetchNextChunk(
        currentOrder: Int,
        audioPlayer: AVAudioPlayer,
        sentences: [String],
        player: TTSPlayer
    ) {
        let nextOrder = currentOrder + 1
        guard nextOrder <= sentences.count else { return }
        guard audioCache[nextOrder] == nil else { return }
        guard !inFlightOrders.contains(nextOrder) else { return }

        let remaining = max(audioPlayer.duration - audioPlayer.currentTime, 0)
        guard remaining <= 1.5 else { return }

        prefetchUpcomingChunks(after: currentOrder, sentences: sentences, player: player)
    }

    private func sentenceStartTime(for order: Int, durations: [TimeInterval]) -> TimeInterval {
        let prefixCount = max(0, min(order - 1, durations.count))
        return durations.prefix(prefixCount).reduce(0, +)
    }

    private func audioDuration(at url: URL) -> TimeInterval? {
        do {
            return try AVAudioPlayer(contentsOf: url).duration
        } catch {
            return nil
        }
    }
}
