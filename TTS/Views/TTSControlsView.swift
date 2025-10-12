//
//  TTSControlsView.swift
//  TTS
//
//  Created by Doniel Tripura on 10/5/25.
//

import SwiftUI

struct TTSControlsView: View {
    @ObservedObject var tts: TTSPlayer
    let text: String

    var body: some View {
        HStack(spacing: 25) {
            Button(action: {
                tts.previousSentence()
            }) {
                Image(systemName: "backward.fill")
                    .font(.title)
            }

            Button(action: {
                if !tts.isSpeaking {
                    tts.startReading(text)
                } else {
                    tts.togglePlayPause()
                }
            }) {
                Image(systemName: tts.isPaused ? "play.fill" : "pause.fill")
                    .font(.largeTitle)
            }

            Button(action: {
                tts.nextSentence()
            }) {
                Image(systemName: "forward.fill")
                    .font(.title)
            }
        }
        .padding()
    }
}


#Preview {
    TTSControlsView(
        tts: TTSPlayer(),
        text: "This is the first sentence. Here is the second sentence. And finally, this is the third one."
    )
}
