//
//  AudioTimelineControls.swift
//  TTS
//
//  Created by Assistant on 11/23/25.
//

import SwiftUI
import Combine

struct AudioTimelineControls: View {
    @ObservedObject var tts: TTSPlayer
    @StateObject private var downloader = UniversalAudioDownloader()
    
    let fileURL: URL?
    let text: String
    let fileType: FileType
    
    var body: some View {
        VStack(spacing: 12) {
            // Timeline Slider
            TimelineSlider(tts: tts)
            
            // Main Controls Row
            HStack(spacing: 20) {
                // Skip Backward 10s
                Button(action: { tts.skipBackward(10.0) }) {
                    Image(systemName: "gobackward.10")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                .disabled(!tts.hasActiveItem || !tts.isSeekable)
                
                // Play/Pause
                Button(action: { tts.togglePlayPause() }) {
                    Image(systemName: tts.state == .playing ? "pause.fill" : "play.fill")
                        .font(.title)
                        .foregroundColor(.white)
                }
                .disabled(tts.sentences.isEmpty)
                
                // Skip Forward 10s
                Button(action: { tts.skipForward(10.0) }) {
                    Image(systemName: "goforward.10")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                .disabled(!tts.hasActiveItem || !tts.isSeekable)
                
                Spacer()
                
                // Download Button
                AudioDownloadButton(
                    content: createFileContent(),
                    downloader: downloader,
                    tts: tts
                )
            }
            .padding(.horizontal)
            
            // Time Display: current time (left), sentence counter (middle), total time (right)
            HStack {
                Text(formatTime(tts.currentTime))
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(counterText())
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(formatTime(tts.totalDuration))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.9))
        .cornerRadius(12)
    }
    
    private func createFileContent() -> FileContent {
        return FileContent(
            url: fileURL ?? URL(fileURLWithPath: "/tmp/unknown"),
            text: text,
            type: fileType,
            title: fileURL?.lastPathComponent ?? "Unknown"
        )
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func counterText() -> String {
        if tts.appVoice == .backend, let requestId = tts.backendDocumentRequestId {
            let chunkCount = BackendChunkStore.shared.fetchAllChunks(documentRequestId: requestId).count
            let currentChunk = min(tts.currentIndex + 1, max(chunkCount, 1))
            return "Chunk \(currentChunk) of \(max(chunkCount, 1))"
        }

        return "\(min(tts.currentIndex, tts.sentences.count - 1) + 1) of \(max(tts.sentences.count, 1))"
    }
}

struct TimelineSlider: View {
    @ObservedObject var tts: TTSPlayer
    @State private var isDragging = false
    @State private var dragValue: Double = 0.0
    
    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                let width = geo.size.width
                let upper = max(1, tts.totalDuration)
                let value = min(max(isDragging ? dragValue : tts.currentTime, 0), upper)
                let progress = CGFloat(value / upper)
                let thumbX = width * progress

                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.25))
                        .frame(height: 3)
                        .cornerRadius(2)

                    Rectangle()
                        .fill(Color.myPrimaryColor)
                        .frame(width: thumbX, height: 3)
                        .cornerRadius(2)

                    Circle()
                        .fill(Color.myPrimaryColor)
                        .frame(width: 12, height: 12)
                        .offset(x: thumbX - 6)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            guard tts.isSeekable else { return }
                            let location = min(max(0, gesture.location.x), width)
                            let percent = width > 0 ? location / width : 0
                            let newValue = percent * upper

                            if !isDragging {
                                isDragging = true
                                dragValue = tts.currentTime
                            }
                            dragValue = min(max(newValue, 0), upper)
                        }
                        .onEnded { _ in
                            guard tts.isSeekable else {
                                isDragging = false
                                return
                            }
                            tts.seek(to: dragValue)
                            isDragging = false
                        }
                )
            }
            .frame(height: 24)
            
            // Progress indicators (sentences)
            if !tts.sentences.isEmpty && tts.isSeekable && !tts.disableHighlighting {
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        ForEach(0..<tts.sentences.count, id: \.self) { index in
                            Rectangle()
                                .fill(index <= tts.currentIndex ? Color.myPrimaryColor : Color.gray.opacity(0.3))
                                .frame(height: 2)
                                .animation(.easeInOut(duration: 0.2), value: tts.currentIndex)
                        }
                    }
                }
                .frame(height: 2)
                .padding(.horizontal)
            }
        }
    }
}

struct AudioDownloadButton: View {
    let content: FileContent
    @ObservedObject var downloader: UniversalAudioDownloader
    @ObservedObject var tts: TTSPlayer
    
    @State private var downloadState: DownloadState = .notStarted
    @State private var showingVoiceOptions = false
    
    var body: some View {
        Button {
            if downloadState == .notStarted || !downloadState.isActive {
                showingVoiceOptions = true
            }
        } label: {
            VStack(spacing: 2) {
                downloadIcon
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(width: 48, height: 44)
            .background(downloadBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .disabled(downloadState.isActive)
        .onReceive(downloader.$downloadStates.map { $0[content.id] ?? .notStarted }) { state in
            downloadState = state
        }
        .sheet(isPresented: $showingVoiceOptions) {
            VoiceDownloadOptionsView(
                content: content,
                downloader: downloader,
                tts: tts,
                isPresented: $showingVoiceOptions
            )
        }
    }
    
    private var downloadIcon: Image {
        switch downloadState {
        case .notStarted:
            return Image(systemName: "arrow.down.circle")
        case .queued:
            return Image(systemName: "clock")
        case .downloading:
            return Image(systemName: "arrow.down.circle.fill")
        case .completed:
            return Image(systemName: "checkmark.circle.fill")
        case .failed:
            return Image(systemName: "exclamationmark.circle")
        }
    }
    
    private var downloadBackgroundColor: Color {
        switch downloadState {
        case .notStarted:
            return .myPrimaryColor.opacity(0.7)
        case .queued:
            return .orange.opacity(0.7)
        case .downloading:
            return .myPrimaryColor.opacity(0.9)
        case .completed:
            return .green.opacity(0.7)
        case .failed:
            return .red.opacity(0.7)
        }
    }
}

struct VoiceDownloadOptionsView: View {
    let content: FileContent
    @ObservedObject var downloader: UniversalAudioDownloader
    @ObservedObject var tts: TTSPlayer
    @Binding var isPresented: Bool
    
    @State private var selectedVoiceMode: AppVoiceMode = .system
    @State private var selectedVoiceSampleId: String = ""
    @State private var selectedVoiceName: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Download Audio")
                        .font(.title2)
                        .bold()
                    
                    Text("Choose voice mode and voice for audio generation:")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Voice Mode Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Voice Engine")
                        .font(.headline)
                    
                    Picker("Voice Mode", selection: $selectedVoiceMode) {
                        if tts.appVoice == .system {
                            Text("System Voice").tag(AppVoiceMode.system)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Voice ID Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Voice")
                        .font(.headline)
                    
                    TextField("Voice Name", text: $selectedVoiceName)
                        .textFieldStyle(.roundedBorder)
                        .disabled(selectedVoiceMode == .system)
                    
                    Text(selectedVoiceMode == .system ? "Uses current system voice" : "Enter voice name for backend generation")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Download Button
                Button("Download Audio") {
                    startDownload()
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.myPrimaryColor)
                .cornerRadius(8)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .onAppear {
            selectedVoiceMode = tts.appVoice
            selectedVoiceSampleId = tts.selectedVoiceSampleId
            selectedVoiceName = tts.selectedVoiceName
        }
    }
    
    private func startDownload() {
        Task {
            await downloader.downloadAudio(
                for: content,
                voiceMode: selectedVoiceMode,
                voiceId: selectedVoiceSampleId
            )
        }
        isPresented = false
    }
}
