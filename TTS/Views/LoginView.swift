//
//  LoginView.swift
//  TTS
//
//  Created by Doniel Tripura on 10/19/25.
//


import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Login")
                .font(.largeTitle.bold())
            
            Button(action: {
                Task {
                    await viewModel.loginWithGoogle(idToken: "your_test_token_here")
                }
            }) {
                Text("Sign in with Google")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            if viewModel.isLoading {
                ProgressView("Signing in...")
            }
            
            if let token = viewModel.tokenData?.accessToken {
                Text("Access Token: \(token)")
                    .font(.footnote)
                    .padding()
            }
            
            if let error = viewModel.errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .padding()
    }
}
