//
//  ContentView.swift
//  TTS
//
//  Created by Doniel Tripura on 10/4/25.
//

import SwiftUI

struct ContentView: View {
    
    @StateObject private var tts = TTSPlayer()
    @StateObject private var recentStore = RecentStore()
    var body: some View {
        TabBarView()
            .environmentObject(tts)
            .environmentObject(recentStore)
//        TTSDemoView()
    }
}

#Preview {
    ContentView()
}
