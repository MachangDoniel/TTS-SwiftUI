//
//  VoiceCard.swift
//  TTS
//
//  Created by Doniel Tripura on 10/20/25.
//

import SwiftUI

struct VoiceCard: View {
    let voice: Voice
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 50, height: 50)
                .foregroundColor(.gray)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(voice.name)
                    .font(.headline)
                    .foregroundColor(.white)
                Text("\(voice.language) • \(voice.accent) • \(voice.mood)")
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
                    )
                )
                
                VoiceCard(
                    voice: Voice(
                        name: "John",
                        language: "English",
                        accent: "American",
                        mood: "Energetic",
                        type: "Standard",
                        voiceSampleId: "1"
                    )
                )
            }
        }
        .previewLayout(.sizeThatFits)
    }
}
