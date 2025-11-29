//
//  VoiceCard.swift
//  TTS
//
//  Created by Doniel Tripura on 10/20/25.
//

import SwiftUI

struct VoiceCard: View {
    let voice: Voice
    var isSelected: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 50, height: 50)
                .foregroundColor(.gray)
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
                    var parts = [voice.language, voice.accent]
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
            
            Text(voice.type)
                .font(.caption)
                .foregroundColor(voice.type == "Premium" ? .yellow : .green)
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.15))
        .cornerRadius(12)
        .padding(.horizontal)
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
