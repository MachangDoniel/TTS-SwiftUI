//
//  AuthGateView.swift
//  TTS
//
//  Created by Doniel Tripura on 11/2/25.
//

import SwiftUI

@MainActor
struct AuthGateView: View {
    @EnvironmentObject var authVM: AuthViewModel
    // Removed local loading flag; rely on AuthViewModel's hasLoadedFromKeychain

    var body: some View {
        Group {
#if PRODUCTION
            // MARK: - General Flow
            if !authVM.hasLoadedFromKeychain {
                ProgressView("Loading session...")
                    .task {
                        await authVM.loadTokenDataIfNeeded()
                    }
                
            } else if authVM.tokenData == nil {
                LoginView()
                    .transition(.opacity)
                    .animation(.easeInOut, value: authVM.tokenData != nil)

            } else {
                MainTabView()
                    .transition(.opacity)
                    .animation(.easeInOut, value: authVM.tokenData != nil)
            }
#else
            // MARK: - Testing Flow
            MainTabView()
                .transition(.opacity)
//            TTSDemoView()
#endif
        }
    }
}

#Preview {
    AuthGateView()
        .environmentObject(AuthViewModel())
}
