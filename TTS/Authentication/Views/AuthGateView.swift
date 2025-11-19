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
    @State private var phase: Phase = .loading

    private enum Phase: Equatable {
        case loading
        case unauthenticated
        case authenticated
    }

    var body: some View {
        ZStack {
            switch phase {
            case .loading:
                ProgressView("Loading session…")
                    .transition(.opacity)
                    .task {
                        await loadIfNeeded()
                    }
            case .unauthenticated:
                LoginView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .authenticated:
                MainTabView()
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: phase)
        .contentTransition(.opacity)
        .onChange(of: authVM.hasLoadedFromKeychain) { _ in
            updatePhase()
        }
        .onChange(of: authVM.tokenData != nil) { _ in
            updatePhase()
        }
        .onAppear {
            updatePhase()
        }
    }

    private func loadIfNeeded() async {
        // Only attempt to load once per presentation; AuthViewModel should be idempotent.
        if !authVM.hasLoadedFromKeychain {
            await authVM.loadTokenDataIfNeeded()
        }
        await MainActor.run { updatePhase(animated: true) }
    }

    private func updatePhase(animated: Bool = false) {
        let newPhase: Phase
#if PRODUCTION
        if !authVM.hasLoadedFromKeychain {
            newPhase = .loading
        } else if authVM.tokenData == nil {
            newPhase = .unauthenticated
        } else {
            newPhase = .authenticated
        }
#else
        // In non-production builds, go straight to the app for faster iteration
        newPhase = .authenticated
#endif

        if animated {
            withAnimation(.easeInOut(duration: 0.25)) {
                phase = newPhase
            }
        } else {
            phase = newPhase
        }
    }
}

#Preview {
    AuthGateView()
        .environmentObject(AuthViewModel())
}
