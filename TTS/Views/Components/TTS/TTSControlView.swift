//
//  TTSControlView.swift
//  TTS
//
//  Created by Doniel Tripura on 10/5/25.
//

import SwiftUI

struct TTSControlView: View {
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
                    if !tts.isSpeaking {
                        tts.startReading(text)
                    } else {
                        tts.togglePlayPause()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 70, height: 70)
                        Image(systemName: tts.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

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
    TTSControlView(
        tts: TTSPlayer(),
        text: "Hello world. This is a test."
    )
    .background(Color.black)
}
