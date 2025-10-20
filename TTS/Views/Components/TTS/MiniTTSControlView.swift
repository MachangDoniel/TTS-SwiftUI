//
//  MiniTTSBar.swift
//  TTS
//
//  Created by Doniel Tripura on 10/5/25.
//

import SwiftUI

struct MiniTTSControlView: View {
    @ObservedObject var ttsPlayer: TTSPlayer
    let title: String
    var onTap: (() -> Void)? = nil

    var body: some View {
        let isPlaying = (ttsPlayer.isSpeaking && !ttsPlayer.isPaused)
        let subtitle = isPlaying ? "Playing" : "Paused"

        ZStack(alignment: .bottomLeading) {
            HStack(spacing: 12) {
                // Artwork / placeholder
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "waveform")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: { ttsPlayer.togglePlayPause() }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(red: 0.10, green: 0.10, blue: 0.11))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 8)
            .contentShape(Rectangle())
            .onTapGesture { onTap?() }

            // Progress bar at the bottom edge of the card
            Rectangle()
                .fill(Color.accentColor)
                .frame(height: 3)
                .opacity(ttsPlayer.progress > 0 ? 1 : 0)
                .frame(maxWidth: .infinity, alignment: .leading)
                .mask(
                    GeometryReader { geo in
                        Rectangle()
                            .frame(width: max(0, geo.size.width * CGFloat(ttsPlayer.progress)))
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 2)
        }
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle)")
    }
}
