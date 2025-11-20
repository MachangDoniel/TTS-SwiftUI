//
//  ContentView.swift
//  TTS
//
//  Created by Doniel Tripura on 10/4/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authVM: AuthViewModel

        var body: some View {
            AuthGateView()
                .id(authVM.tokenData?.accessToken ?? "nil")
                .animation(.easeInOut, value: authVM.tokenData != nil)
        }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
