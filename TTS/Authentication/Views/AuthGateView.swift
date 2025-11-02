//
//  AuthGateView.swift
//  TTS
//
//  Created by Doniel Tripura on 11/2/25.
//

import SwiftUI

struct AuthGateView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var isLoaded = false

    var body: some View {
        Group {
#if PRODUCTION
            // MARK: - General Flow
            if !isLoaded {
                ProgressView("Loading session...")
                    .task {
                        authVM.loadTokenData()
                        isLoaded = true
                    }

            } else if authVM.tokenData == nil {
                LoginView()
                    .transition(.opacity)

            } else {
                MainTabView()
                    .transition(.opacity)
            }
#else
            // MARK: - Testing Flow
            MainTabView()
                .transition(.opacity)
#endif
        }
    }
}

#Preview {
    AuthGateView()
        .environmentObject(AuthViewModel())
}
