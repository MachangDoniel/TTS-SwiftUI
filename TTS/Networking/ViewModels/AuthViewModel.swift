//
//  AuthViewModel.swift
//  TTS
//
//  Created by Doniel Tripura on 10/19/25.
//


import Foundation
import Combine


@MainActor
final class AuthViewModel: ObservableObject {
    @Published var tokenData: TokenData?
    @Published var errorMessage: String?
    @Published var isLoading = false
    
    func loginWithGoogle(provider: String = "google", idToken: String, platform: String = "iOS") async {
        isLoading = true
        defer { isLoading = false }
        
        let body = GoogleAuthRequest(provider: provider, idToken: idToken, platform: platform)
        
        do {
            let response: AuthResponse = try await APIClient.shared.request(
                APIEndpoints.googleAuth,
                body: body
            )
            tokenData = response.data
            Logger.log("✅ Login successful: \(response.data.accessToken)")
        } catch {
            errorMessage = error.localizedDescription
            Logger.log("❌ Login failed: \(error.localizedDescription)")
        }
    }
}
