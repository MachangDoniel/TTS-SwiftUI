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
    @StateObject private var downloader = UniversalAudioDownloader()
    
    let text: String
    let fileURL: URL?
    let fileType: FileType?
    
    // Support legacy initializer
    init(tts: TTSPlayer, text: String) {
        self.tts = tts
        self.text = text
        self.fileURL = nil
        self.fileType = nil
    }
    
    // Enhanced initializer with file info for download
    init(tts: TTSPlayer, text: String, fileURL: URL?, fileType: FileType?) {
        self.tts = tts
        self.text = text
        self.fileURL = fileURL
        self.fileType = fileType
    }
    
    var body: some View {
        VStack(spacing: 16) {
            
            // Old progress bar (commented out - replaced with enhanced timeline)
            //             ProgressView(value: tts.progress)
            //                 .progressViewStyle(.linear)
            //                 .tint(.myPrimaryColor)
            //                 .padding(.horizontal)
            
            // Enhanced Timeline Slider (skinnier version)
            VStack(spacing: 2) {
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
                    value: isDragging ? $dragValue : Binding(
                        get: {
                            let upper = max(1, tts.totalDuration)
                            return min(max(tts.currentTime, 0), upper)
                        },
                        set: { dragValue = $0 }
                    ),
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
            
            // Time display: current time (left), sentence counter (middle), total time (right)
            HStack {
                Text(formatTime(min(max(tts.currentTime, 0), max(1, tts.totalDuration))))
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text("\(min(tts.currentIndex, tts.sentences.count - 1) + 1) of \(max(tts.sentences.count, 1))")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(formatTime(tts.totalDuration))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)
            
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
                    if tts.sentences.isEmpty {
                        tts.prepare(
                            text: text,
                            url: tts.currentURL,
                            title: tts.currentTitle
                        )
                    }
                    
                    switch tts.state {
                    case .idle, .finished:
                        tts.playFromCurrent()
                    case .playing, .paused:
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
                    VStack {
                        Image(systemName: tts.appVoice == .system ? "chevron.forward.2" : "goforward.10")
                            .font(.title2)
                        Text(tts.appVoice == .system ? "Next" : "10s")
                            .font(.caption2)
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
                .opacity(0.4)
            }
            .padding(.horizontal)
            .foregroundColor(.white)
            
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
        text: "Hello world. This is a test.",
        fileURL: URL(fileURLWithPath: "/tmp/test.txt"),
        fileType: .text
    )
    .background(Color.black)
}

