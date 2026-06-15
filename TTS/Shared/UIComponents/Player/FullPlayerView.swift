//
//  FullPlayerView.swift
//  TTS
//
//  Created by Doniel Tripura on 10/5/25.
//

import SwiftUI
import Combine

struct FullPlayerView: View {
    @ObservedObject var tts: TTSPlayer
    @State private var showLanguagePicker = false
    @State private var showDownloadOptions = false
    @State private var isDragging = false
    @State private var dragValue: Double = 0.0
    @State private var displayedIndex: Int = 0
    @StateObject private var downloader = UniversalAudioDownloader()
    
    let text: String
    let fileURL: URL?
    let fileType: FileType?
    let showBackendTranscript: Bool
    let showTimeline: Bool
    let showSentenceCounter: Bool
    
    var onTogglePlayPause: (() -> Void)? = nil
    
    // Support legacy initializer
    init(tts: TTSPlayer, text: String, onTogglePlayPause: (() -> Void)? = nil) {
        self.tts = tts
        self.text = text
        self.fileURL = nil
        self.fileType = nil
        self.showBackendTranscript = true
        self.showTimeline = true
        self.showSentenceCounter = true
        self.onTogglePlayPause = onTogglePlayPause
    }
    
    // Enhanced initializer with file info for download
    init(
        tts: TTSPlayer,
        text: String,
        fileURL: URL?,
        fileType: FileType?,
        showBackendTranscript: Bool = true,
        showTimeline: Bool = true,
        showSentenceCounter: Bool = true,
        onTogglePlayPause: (() -> Void)? = nil
    ) {
        self.tts = tts
        self.text = text
        self.fileURL = fileURL
        self.fileType = fileType
        self.showBackendTranscript = showBackendTranscript
        self.showTimeline = showTimeline
        self.showSentenceCounter = showSentenceCounter
        self.onTogglePlayPause = onTogglePlayPause
    }
    
    var body: some View {
        VStack(spacing: 16) {
            
            // Old progress bar (commented out - replaced with enhanced timeline)
            //             ProgressView(value: tts.progress)
            //                 .progressViewStyle(.linear)
            //                 .tint(.myPrimaryColor)
            //                 .padding(.horizontal)
            
            // Enhanced Timeline Slider (skinnier version)
            if showTimeline {
                VStack(spacing: 2) {
                let sliderValueBinding: Binding<Double> = (isDragging || tts.state != .playing) ? $dragValue : Binding(
                    get: {
                        let upper = max(1, tts.totalDuration)
                        let current = min(max(tts.currentTime, 0), upper)
                        return current
                    },
                    set: { newValue in
                        dragValue = newValue
                    }
                )
                //                Slider(
                //                    value: isDragging ? $dragValue : .constant(tts.currentTime),
                //                    in: 0...max(1, tts.totalDuration),
                //                    onEditingChanged: { editing in
                //                        if editing {
                //                            isDragging = true
                //                            dragValue = tts.currentTime
                //                        } else {
                //                            tts.seek(to: dragValue)
                //                            isDragging = false
                //                        }
                //                    }
                //                )
                MySlider(
                    value: sliderValueBinding,
                    range: 0...max(1, tts.totalDuration),
                    onEditingChanged: { editing in
                        if editing {
                            isDragging = true
                            let upper = max(1, tts.totalDuration)
                            dragValue = min(max(tts.currentTime, 0), upper)
                        } else {
                            let upper = max(1, tts.totalDuration)
                            let clamped = min(max(dragValue, 0), upper)
                            tts.seek(to: clamped)
                            isDragging = false
                        }
                    }
                )
                .frame(height: 24)
                .padding(.horizontal)
                .disabled(!tts.isSeekable)
                
                //                // Sentence progress indicators (skinnier)
                //                if !tts.disableHighlighting && !tts.sentences.isEmpty && tts.isSeekable {
                //                    GeometryReader { geometry in
                //                        HStack(spacing: 0) {
                //                            ForEach(0..<tts.sentences.count, id: \.self) { index in
                //                                Rectangle()
                //                                    .fill(index <= tts.currentIndex ? Color.myPrimaryColor : Color.gray.opacity(0.3))
                //                                    .frame(height: 1.5)
                //                                    .animation(.easeInOut(duration: 0.2), value: tts.currentIndex)
                //                            }
                //                        }
                //                    }
                //                    .frame(height: 1.5)
                //                    .padding(.horizontal)
                //                }
                }
            }
            
            // Time display: current time (left), sentence counter (middle), total time (right)
            HStack {
                let clampedCurrent = min(max(tts.currentTime, 0), max(1, tts.totalDuration))
                let currentIndexSafe = min(tts.currentIndex, max(tts.sentences.count - 1, 0))
                let totalSentencesSafe = max(tts.sentences.count, 1)
                let displayedCurrent = (tts.state == .playing) ? clampedCurrent : min(max(dragValue, 0), max(1, tts.totalDuration))
                let displayedIndexSafe = min(max(displayedIndex, 0), max(tts.sentences.count - 1, 0))
                
                if showTimeline {
                    Text(formatTime(displayedCurrent))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if showSentenceCounter {
                    Text("\(displayedIndexSafe + 1) of \(totalSentencesSafe)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if showTimeline {
                    Text(formatTime(tts.totalDuration))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)

            if showBackendTranscript, tts.appVoice == .backend, !tts.backendTranscript.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Backend Text")
                            .font(.caption)
                            .foregroundColor(.gray)

                        Spacer()

                        Text(tts.backendAccessTier.rawValue)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }

                    TextEditor(text: .constant(tts.backendTranscript))
                        .scrollContentBackground(.hidden)
                        .background(Color.white.opacity(0.06))
                        .foregroundColor(.white)
                        .frame(minHeight: 120, maxHeight: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .disabled(true)
                }
                .padding(.horizontal)
            }
            
            // Main controls
            HStack(spacing: 32) {
                
                // Language / Backend voice picker
                Button(action: {
                    showLanguagePicker.toggle()
                }) {
                    
                    Image(TTSUtility.findGender() == .male ? ImageAssets.male_voice : ImageAssets.female_voice)
                        .resizable()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                }
                
                // Back (10-second skip backwards)
                Button(action: {
                    tts.skipBackward(10.0)
                }) {
                    VStack {
                        Image(systemName: tts.appVoice == .system ? "chevron.backward.2" : "gobackward.10")
                            .font(.title2)
                        Text(tts.appVoice == .system ? "Prev" : "10s")
                            .font(.caption2)
                    }
                }
                .disabled(!tts.hasActiveItem || !tts.isSeekable)
                
                // Play / Pause
                Button(action: {
                    onTogglePlayPause?()
                    
                    if tts.sentences.isEmpty {
                        tts.prepare(
                            text: text,
                            url: tts.currentURL,
                            title: tts.currentTitle
                        )
                    }
                    
                    switch tts.state {
                    case .idle, .finished:
                        let upper = max(1, tts.totalDuration)
                        let target = min(max(dragValue, 0), upper)
                        tts.seek(to: target)
                        tts.playFromCurrent()
                    case .playing, .paused:
                        if tts.state == .paused {
                            let upper = max(1, tts.totalDuration)
                            let target = min(max(dragValue, 0), upper)
                            tts.seek(to: target)
                        }
                        tts.togglePlayPause()
                    case .loading:
                        break
                    }
                }) {
                    ZStack {
                        // Main round button
                        Circle()
                            .fill(Color.myPrimaryColor)
                            .frame(width: 70, height: 70)
                        
                        // Loader ring (layout-stable; rotates only while loading)
                        ZStack {
                            // Background track (always present to keep layout stable)
                            Circle()
                                .stroke(Color.white.opacity(0.12), lineWidth: 3)
                                .frame(width: 76, height: 76)
                            
                            // Foreground arc — visible and rotating only when loading
                            Circle()
                                .trim(from: 0.0, to: 0.78)
                                .stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .frame(width: 76, height: 76)
                                .rotationEffect(.degrees(-90)) // start at top
                                .rotationEffect(.degrees(tts.state == .loading ? 360 : 0))
                                .animation(
                                    tts.state == .loading
                                    ? .linear(duration: 1.1).repeatForever(autoreverses: false)
                                    : .default,
                                    value: tts.state
                                )
                                .opacity(tts.state == .loading ? 1.0 : 0.0)
                        }
                        
                        Image(systemName: tts.state == .playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .disabled(tts.state == .loading || tts.sentences.isEmpty)
                .animation(.easeInOut(duration: 0.15), value: tts.state)
                
                // Forward (10-second skip forward)
                Button(action: {
                    tts.skipForward(10.0)
                }) {
                    HStack(alignment: .center, spacing: 8) {
                        VStack {
                            Image(systemName: tts.appVoice == .system ? "chevron.forward.2" : "goforward.10")
                                .font(.title2)
                            Text(tts.appVoice == .system ? "Next" : "10s")
                                .font(.caption2)
                        }

                        if tts.appVoice == .backend, tts.backendJobPhase != .idle {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tts.backendJobPhase.displayName)
                                    .font(.caption2)
                                    .lineLimit(1)

                                if let progress = tts.backendJobProgress {
                                    Text("\(progress)%")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                } else if tts.state == .loading {
                                    ProgressView()
                                        .controlSize(.mini)
                                }
                            }
                        }
                    }
                }
                .disabled(!tts.hasActiveItem || !tts.isSeekable)
                
                // Download / Share button
                Button(action: {
                    if let fileURL = fileURL, let fileType = fileType {
                        showDownloadOptions = true
                    } else {
                        // Fallback to share for text input
                        shareText()
                    }
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title2)
                }
                .disabled(true)
                .opacity(0)
            }
            .padding(.horizontal)
            .foregroundColor(.white)
            
        }
        .onAppear {
            let upper = max(1, tts.totalDuration)
            dragValue = min(max(tts.currentTime, 0), upper)
            displayedIndex = min(tts.currentIndex, max(tts.sentences.count - 1, 0))
        }
        .onChange(of: tts.state) { newState in
            // When playback is not active, ensure UI time does not keep advancing visually
            switch newState {
            case .paused, .idle, .loading, .finished:
                isDragging = false
                let upper = max(1, tts.totalDuration)
                let clamped = min(max(tts.currentTime, 0), upper)
                dragValue = clamped
                displayedIndex = min(tts.currentIndex, max(tts.sentences.count - 1, 0))
            case .playing:
                let upper = max(1, tts.totalDuration)
                dragValue = min(max(tts.currentTime, 0), upper)
                displayedIndex = min(tts.currentIndex, max(tts.sentences.count - 1, 0))
            }
        }
        .onReceive(tts.$currentTime.removeDuplicates()) { time in
            // Only reflect time changes in UI while actually playing
            guard tts.state == .playing else { return }
            let upper = max(1, tts.totalDuration)
            let clamped = min(max(time, 0), upper)
            if !isDragging { // don't fight user drag
                dragValue = clamped
            }
        }
        .onReceive(tts.$currentIndex.removeDuplicates()) { idx in
            guard tts.state == .playing else { return }
            displayedIndex = min(idx, max(tts.sentences.count - 1, 0))
        }
        .padding(.vertical)
        .background(Color(.systemGray6).opacity(0.15))
        .cornerRadius(16)
        .padding(.horizontal)
        .padding(.bottom)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerView()
                .environmentObject(tts)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDownloadOptions) {
            if let fileURL = fileURL, let fileType = fileType {
                VoiceDownloadOptionsView(
                    content: FileContent(
                        url: fileURL,
                        text: text,
                        type: fileType,
                        title: fileURL.lastPathComponent
                    ),
                    downloader: downloader,
                    tts: tts,
                    isPresented: $showDownloadOptions
                )
            }
        }
    }
}

extension FullPlayerView {
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func shareText() {
        // TODO: Implement text sharing functionality
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
}

struct MySlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let onEditingChanged: (Bool) -> Void

    @State private var isDragging = false

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let clampedValue = min(max(value, range.lowerBound), range.upperBound)
            let progress = CGFloat((clampedValue - range.lowerBound) / (range.upperBound - range.lowerBound))
            let thumbX = width * progress

            ZStack(alignment: .leading) {

                // Track background
                Rectangle()
                    .fill(Color.white.opacity(0.25))
                    .frame(height: 3)
                    .cornerRadius(2)

                // Progress bar
                Rectangle()
                    .fill(Color.myPrimaryColor)
                    .frame(width: thumbX, height: 3)
                    .cornerRadius(2)

                // Small thumb
                Circle()
                    .fill(Color.myPrimaryColor)
                    .frame(width: 12, height: 12)     // 👈 Change size here
                    .offset(x: thumbX - 6)            // center alignment
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                let location = min(max(0, gesture.location.x), width)
                                let percent = location / width
                                let unclamped = range.lowerBound + Double(percent) * (range.upperBound - range.lowerBound)
                                let newValue = min(max(unclamped, range.lowerBound), range.upperBound)

                                isDragging = true
                                onEditingChanged(true)
                                value = newValue
                            }
                            .onEnded { _ in
                                isDragging = false
                                onEditingChanged(false)
                            }
                    )
            }
        }
        .frame(height: 24)
    }
}

#Preview {
    FullPlayerView(
        tts: TTSPlayer(),
        text: "Hello world. This is a test."
    )
    .background(Color.black)
}
