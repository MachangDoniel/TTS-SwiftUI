//
//  MainTabView.swift
//  TTS
//
//  Created by Doniel Tripura on 11/2/25.
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var tts = TTSPlayer()
    @StateObject private var recentStore = RecentStore()

    var body: some View {
        TabBarView()
            .environmentObject(tts)
            .environmentObject(recentStore)
    }
}

#Preview {
    MainTabView()
}
