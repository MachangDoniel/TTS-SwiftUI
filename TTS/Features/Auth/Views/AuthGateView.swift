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
    @State private var animatePhaseChange = false

    private enum Phase: Equatable {
        case loading
        case unauthenticated
        case authenticated
    }

    private var currentPhase: Phase {
//#if PRODUCTION
//        if !authVM.hasLoadedFromKeychain { return .loading }
//        return authVM.tokenData == nil ? .unauthenticated : .authenticated
//#else
        return .authenticated
//#endif
    }

    var body: some View {
        ZStack {
            switch currentPhase {
            case .loading:
                ProgressView("Loading session…")
                    .onAppear { }
                    .transition(.opacity)
                    .task {
                        await loadIfNeeded()
                    }
            case .unauthenticated:
                LoginView()
                    .onAppear { }
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .authenticated:
                MainTabView()
                    .onAppear { }
                    .transition(.opacity.combined(with: .scale(scale: 1.02)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: animatePhaseChange)
        .contentTransition(.opacity)
        .onChange(of: currentPhase) { newPhase in
            animatePhaseChange.toggle()
        }
    }

    // MARK: - Async Token Loader
    private func loadIfNeeded() async {
        if !authVM.hasLoadedFromKeychain {
            await authVM.loadTokenDataIfNeeded()
        }
    }
}


#Preview {
    let vm = AuthViewModel()
    return AuthGateView()
        .environmentObject(vm)
}
