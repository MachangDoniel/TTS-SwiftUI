//
//  VoiceCard.swift
//  TTS
//
//  Created by Doniel Tripura on 10/20/25.
//

import SwiftUI
import AVFoundation

struct VoiceCard: View {
    let voice: Voice
    var isSelected: Bool = false
    
    @State private var uiImage: UIImage? = nil
    @State private var previewPlayer: AVAudioPlayer? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let img = uiImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(voice.gender == .male ? ImageAssets.male_voice : ImageAssets.female_voice)
                        .resizable()
                        .scaledToFill()
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            .clipped()
            .overlay(
                Group {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .background(Color.black.opacity(0.7).clipShape(Circle()))
                            .offset(x: 5, y: 5)
                    }
                },
                alignment: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(voice.name)
                    .font(.headline)
                    .foregroundColor(.white)

                let subtitle: String = {
                    var parts = [voice.language, voice.accent].filter { !$0.isEmpty }
                    if let mood = voice.mood, !mood.isEmpty {
                        parts.append(mood)
                    }
                    return parts.joined(separator: " • ")
                }()

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()

            HStack(spacing: 8) {
                
                if voice.type == VoiceType.Premium.rawValue {
                    Button {
                        Task {
                            if let url = await VoiceCatalog.shared.audioPreviewURLCached(for: voice) {
                                do {
                                    previewPlayer = try AVAudioPlayer(contentsOf: url)
                                    previewPlayer?.prepareToPlay()
                                    previewPlayer?.play()
                                } catch {
                                    Logger.log("⚠️ Failed to play preview: \(error.localizedDescription)")
                                }
                            } else {
                                Logger.log("⚠️ No preview URL available for this voice")
                            }
                        }
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
                
                Text(voice.type)
                    .font(.caption)
                    .foregroundColor(voice.type == VoiceType.Premium.rawValue ? .yellow : .green)

            }
        }
        .padding()
        .background(isSelected ? Color(red: 65/255, green: 91/255, blue: 246/255).opacity(0.17) : Color(.systemGray6).opacity(0.15))
        .cornerRadius(12)
        .padding(.horizontal)
        .task {
            if uiImage == nil {
                if let data = await VoiceCatalog.shared.imageData(for: voice), let img = UIImage(data: data) {
                    uiImage = img
                }
            }
        }
    }
}

struct VoiceCard_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                VoiceCard(
                    voice: Voice(
                        name: "Emma",
                        language: "English",
                        accent: "British",
                        mood: "Calm",
                        type: "Premium",
                        voiceSampleId: "1"
                    ),
                    isSelected: true
                )
                
                VoiceCard(
                    voice: Voice(
                        name: "John",
                        language: "English",
                        accent: "American",
                        mood: "Energetic",
                        type: "Standard",
                        voiceSampleId: "1"
                    ),
                    isSelected: false
                )
            }
        }
        .previewLayout(.sizeThatFits)
    }
}
