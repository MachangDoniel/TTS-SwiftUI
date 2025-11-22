//
//  FullPlayerView.swift
//  TTS
//
//  Created by Doniel Tripura on 10/5/25.
//

import SwiftUI

struct FullPlayerView: View {
    @ObservedObject var tts: TTSPlayer
    @State private var showLanguagePicker = false
    let text: String

    var body: some View {
        VStack(spacing: 16) {

            // Progress bar across sentences
            ProgressView(value: tts.progress)
                .progressViewStyle(.linear)
                .tint(.blue)
                .padding(.horizontal)

            // Sentence counter
            HStack {
                Text("00:00")
                Spacer()
                Text("\(tts.currentIndex + 1) of \(max(tts.sentences.count, 1))")
                Spacer()
                Text("00:01")
            }
            .font(.caption)
            .foregroundColor(.gray)
            .padding(.horizontal)

            // Main controls
            HStack(spacing: 32) {

                // Language / Backend voice picker
                Button(action: {
                    showLanguagePicker.toggle()
                }) {
                    Image("liberia_flag") // Replace with your asset or SF symbol
                        .resizable()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                }

                // Back (previous sentence)
                Button(action: {
                    tts.previousSentence()
                }) {
                    VStack {
                        Image(systemName: "gobackward.10")
                            .font(.title2)
                        Text("10")
                            .font(.caption2)
                    }
                }

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
                            .fill(Color.blue)
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

                // Forward (next sentence)
                Button(action: {
                    tts.nextSentence()
                }) {
                    VStack {
                        Image(systemName: "goforward.10")
                            .font(.title2)
                        Text("10")
                            .font(.caption2)
                    }
                }

                // Share (placeholder)
                Button(action: {
                    // TODO: share current text
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title2)
                }
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
    }
}

#Preview {
    FullPlayerView(
        tts: TTSPlayer(),
        text: "Hello world. This is a test."
    )
    .background(Color.black)
}
