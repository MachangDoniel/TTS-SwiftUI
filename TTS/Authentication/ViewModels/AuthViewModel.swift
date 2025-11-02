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
    
    func loginWithGoogle(provider: ProviderEnum = .google, idToken: String, platform: PlatformEnum = .iOS) async {
        isLoading = true
        defer { isLoading = false }
        
        let body = GoogleAuthRequest(provider: provider.rawValue, idToken: idToken, platform: platform.rawValue)
        
        do {
            let response: AuthResponse = try await APIClient.shared.request(
                APIEndpoints.googleAuth,
                body: body
            )
            tokenData = response.data
            saveTokenData()
            Logger.log("✅ Login successful: \(response.data.accessToken)")
        } catch {
            errorMessage = error.localizedDescription
            Logger.log("❌ Login failed: \(error.localizedDescription)")
        }
    }
}

extension AuthViewModel {
    func refreshSession() async {
        guard let refreshToken = tokenData?.refreshToken else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let response: AuthResponse = try await APIClient.shared.request(
                APIEndpoints.refresh,
                body: RefreshTokenRequest(refreshToken: refreshToken)
            )
            tokenData = response.data
            Logger.log("✅ Token refreshed successfully")
        } catch {
            errorMessage = error.localizedDescription
            Logger.log("❌ Refresh failed: \(error.localizedDescription)")
        }
    }

    func logout() async {
        guard let refreshToken = tokenData?.refreshToken else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let _: AuthResponse = try await APIClient.shared.request(
                APIEndpoints.logout,
                body: RefreshTokenRequest(refreshToken: refreshToken)
            )
            self.clearTokenData()
            tokenData = nil
            Logger.log("✅ Logged out successfully")
        } catch {
            errorMessage = error.localizedDescription
            Logger.log("❌ Logout failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Token Persistence
extension AuthViewModel {
    private var tokenKey: String { "com.tts.accessTokenData" }

    func saveTokenData() {
        guard let tokenData else { return }
        if let encoded = try? JSONEncoder().encode(tokenData) {
            UserDefaults.standard.set(encoded, forKey: tokenKey)
        }
    }

    func loadTokenData() {
        guard let data = UserDefaults.standard.data(forKey: tokenKey),
              let decoded = try? JSONDecoder().decode(TokenData.self, from: data) else {
            return
        }
        self.tokenData = decoded
    }

    func clearTokenData() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        self.tokenData = nil
    }
}
