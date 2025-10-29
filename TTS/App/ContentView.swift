//
//  ContentView.swift
//  TTS
//
//  Created by Doniel Tripura on 10/4/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var tts = TTSPlayer()
    @StateObject private var recentStore = RecentStore()
    @State private var isLoaded = false

    var body: some View {
        Group {
//            if !isLoaded {
//                ProgressView("Loading session...")
//                    .task {
//                        authVM.loadTokenData()
//                        isLoaded = true
//                    }
//            } else if authVM.tokenData == nil {
//                // Not logged in yet
//                LoginView()
//                    .transition(.opacity)
//            } else {
                // Already logged in
                TabBarView()
                    .environmentObject(tts)
                    .environmentObject(recentStore)
                    .transition(.opacity)
//            }
        }
        .id(authVM.tokenData?.accessToken ?? "nil")
        .animation(.easeInOut, value: authVM.tokenData != nil)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
