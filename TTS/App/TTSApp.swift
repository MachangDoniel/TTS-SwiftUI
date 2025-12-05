//
//  TTSApp.swift
//  TTS
//
//  Created by Doniel Tripura on 10/4/25.
//

import SwiftUI

@main
struct TTSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authVM = AuthViewModel()
    
    init() {
        // Debug prints for build configuration
        #if PRODUCTION
        print("🔥 Running in PRODUCTION mode")
        #else
        print("🧪 Running in DEVELOPMENT mode")
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authVM)
                .environmentObject(VoiceCatalog.shared)
        }
    }
}
