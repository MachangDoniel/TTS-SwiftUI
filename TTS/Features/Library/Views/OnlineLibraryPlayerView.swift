//
//  OnlineLibraryPlayerView.swift
//  TTS
//
//  Created by Assistant on 6/15/26.
//

import SwiftUI
import AVFoundation

struct OnlineLibraryPlayerView: View {
    @ObservedObject var tts: TTSPlayer
    @Environment(\.dismiss) private var dismiss

    @State private var activeItem: OnlineLibraryItem
    @State private var transcript: String = ""
    @State private var didPrepare = false
    private let jobService = PublicTTSJobService()
    private let chunkStore = BackendChunkStore.shared

    init(item: OnlineLibraryItem, tts: TTSPlayer) {
        self._tts = ObservedObject(wrappedValue: tts)
        self._activeItem = State(initialValue: item)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.down")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.white)
                }

                Spacer()

                Text(activeItem.title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                Text(activeItem.voiceName)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Text(activeItem.projectTitle)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(transcript.isEmpty ? "Loading transcript..." : transcript)
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }

            FullPlayerView(
                tts: tts,
                text: transcript,
                fileURL: activeItem.generatedTextURL,
                fileType: .text,
                showBackendTranscript: false,
                showTimeline: true,
                showSentenceCounter: true
            )
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .task {
            guard !didPrepare else { return }
            didPrepare = true
            await preparePlayback()
        }
    }

    @MainActor
    private func preparePlayback() async {
        let resolvedItem = await ensureTranscriptIsAvailable(for: activeItem)
        let resolvedDuration = resolvedItem.totalDuration ?? computeTotalDuration(for: resolvedItem)
        var preparedItem = resolvedItem
        if resolvedItem.totalDuration != resolvedDuration, resolvedDuration ?? 0 > 0 {
            preparedItem.totalDuration = resolvedDuration
            OnlineLibraryStore.shared.save(item: preparedItem)
        }
        activeItem = preparedItem
        seedChunkStore(using: preparedItem)

        let content = (try? String(contentsOf: preparedItem.generatedTextURL, encoding: .utf8)) ?? ""
        transcript = content

        tts.appVoice = .backend
        tts.selectedVoiceSampleId = preparedItem.voiceSampleId
        tts.selectedVoiceName = preparedItem.voiceName
        tts.backendDocumentRequestId = preparedItem.requestId
        tts.prepareNewFileOnly(
            text: content,
            url: preparedItem.generatedTextURL,
            title: preparedItem.title,
            onlineSourceReference: preparedItem.originalURL,
            onlineProjectTitle: preparedItem.projectTitle,
            backendTotalDuration: resolvedDuration
        )
        tts.appVoice = .backend
        tts.selectedVoiceSampleId = preparedItem.voiceSampleId
        tts.selectedVoiceName = preparedItem.voiceName
        tts.backendDocumentRequestId = preparedItem.requestId
        tts.backendTranscript = content
        tts.backendJobPhase = .completed
        tts.backendJobProgress = 100
        tts.state = .idle
    }

    private func ensureTranscriptIsAvailable(for item: OnlineLibraryItem) async -> OnlineLibraryItem {
        if FileManager.default.fileExists(atPath: item.generatedTextURL.path) {
            return item
        }

        guard !item.remoteTextURLs.isEmpty else {
            return item
        }

        do {
            let chunks = try await jobService.downloadChunkTexts(from: item.remoteTextURLs)
            let content = chunks
                .sorted { $0.index < $1.index }
                .map(\.text)
                .joined(separator: "\n\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !content.isEmpty else {
                return item
            }

            let persistedFile = try jobService.persistTranscriptFile(
                text: content,
                requestId: item.requestId,
                voiceName: item.voiceName,
                preferredBaseName: item.projectTitle
            )

            var updated = item
            updated.generatedTextFilePath = persistedFile.fileURL.lastPathComponent
            await MainActor.run {
                OnlineLibraryStore.shared.save(item: updated)
            }
            return updated
        } catch {
            Logger.error(error)
            return item
        }
    }

    private func seedChunkStore(using item: OnlineLibraryItem) {
        let chunkCount = max(
            item.remoteTextURLs.count,
            max(item.remoteAudioURLs.count, item.resolvedLocalAudioURLs.count)
        )
        guard chunkCount > 0 else { return }

        for index in 0..<chunkCount {
            let order = index + 1
            let remoteTextURL = item.remoteTextURLs[safe: index]
            let remoteAudioURL = item.remoteAudioURLs[safe: index]
            let localAudioPath = item.resolvedLocalAudioURLs[safe: index].flatMap { url in
                FileManager.default.fileExists(atPath: url.path) ? url.path : nil
            }

            chunkStore.saveChunk(
                documentRequestId: item.requestId,
                chunkIndex: order,
                remoteTextURL: remoteTextURL,
                remoteAudioURL: remoteAudioURL,
                localAudioPath: localAudioPath
            )
        }
    }

    private func computeTotalDuration(for item: OnlineLibraryItem) -> TimeInterval? {
        let urls = item.resolvedLocalAudioURLs
        guard !urls.isEmpty else { return nil }

        let durations = urls.compactMap { url -> TimeInterval? in
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return try? AVAudioPlayer(contentsOf: url).duration
        }

        let total = durations.reduce(0, +)
        return total > 0 ? total : nil
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

#Preview {
    OnlineLibraryPlayerView(
        item: OnlineLibraryItem(
            title: "Transcript.txt",
            sourcePath: nil,
            kind: .text,
            requestId: "request-1",
            projectKey: "project-1",
            projectTitle: "Project",
            originalSourceURL: "/tmp/original.pdf",
            originalSourceExtension: "pdf",
            generatedTextFilePath: "/tmp/transcript.txt",
            remoteTextURLs: [],
            remoteAudioURLs: [],
            localAudioPaths: [],
            voiceSampleId: "1",
            voiceName: "Voice"
        ),
        tts: TTSPlayer()
    )
}
