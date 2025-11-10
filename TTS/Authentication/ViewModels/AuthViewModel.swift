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
    
    private var isRefreshing = false
    private var refreshWaiters: [CheckedContinuation<Bool, Error>] = []
    
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
    
    func refreshSession() async throws -> Bool {
        if isRefreshing {
            return try await withCheckedThrowingContinuation { continuation in
                refreshWaiters.append(continuation)
            }
        }
        
        guard let refreshToken = tokenData?.refreshToken else {
            notifyLogout(reason: .invalidRefreshToken)
            return false
        }
        
        isRefreshing = true
        
        let maxAttempts = 3
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                let response: AuthResponse = try await APIClient.shared.request(
                    APIEndpoints.refresh,
                    body: RefreshTokenRequest(refreshToken: refreshToken)
                )
                tokenData = response.data
                saveTokenData()
                resumeRefreshWaiters(with: .success(true))
                isRefreshing = false
                Logger.log("✅ Token refreshed successfully")
                return true
            } catch {
                lastError = error
                
                if isUnrecoverableRefreshError(error) {
                    clearTokenData()
                    notifyLogout(reason: .invalidRefreshToken)
                    resumeRefreshWaiters(with: .failure(error))
                    isRefreshing = false
                    Logger.log("❌ Refresh failed: \(error.localizedDescription)")
                    throw error
                }
                
                if attempt < maxAttempts {
                    let nanos = backoffNanos(for: attempt)
                    try? await Task.sleep(nanoseconds: nanos)
                    continue
                } else {
                    clearTokenData()
                    notifyLogout(reason: .maxRetryReached)
                    resumeRefreshWaiters(with: .failure(error))
                    isRefreshing = false
                    Logger.log("❌ Refresh failed: \(error.localizedDescription)")
                    throw error
                }
            }
        }
        
        // Should never reach here but if does:
        isRefreshing = false
        notifyLogout(reason: .maxRetryReached)
        resumeRefreshWaiters(with: .failure(lastError ?? NSError(domain: "", code: -1, userInfo: nil)))
        return false
    }
    
    func logout() async {
        guard let refreshToken = tokenData?.refreshToken else {
            clearTokenData()
            notifyLogout(reason: .invalidRefreshToken)
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let _: AuthResponse = try await APIClient.shared.request(
                APIEndpoints.logout,
                body: RefreshTokenRequest(refreshToken: refreshToken)
            )
            clearTokenData()
            notifyLogout(reason: .invalidRefreshToken)
            Logger.log("✅ Logged out successfully")
        } catch {
            clearTokenData()
            notifyLogout(reason: .invalidRefreshToken)
            errorMessage = "Failed to logout. Please try again."
            Logger.log("❌ Logout failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helpers for refreshSession
    
    private func resumeRefreshWaiters(with result: Result<Bool, Error>) {
        for waiter in refreshWaiters {
            switch result {
            case .success(let value):
                waiter.resume(returning: value)
            case .failure(let error):
                waiter.resume(throwing: error)
            }
        }
        refreshWaiters.removeAll()
    }
    
    private func backoffNanos(for attempt: Int) -> UInt64 {
        // Delays in seconds: 0.5, 1.0, 2.0
        let delays: [Double] = [0.5, 1.0, 2.0]
        guard attempt >= 1 && attempt <= delays.count else {
            return UInt64(0.5 * 1_000_000_000) // default 0.5s
        }
        return UInt64(delays[attempt - 1] * 1_000_000_000)
    }
    
    private func isUnrecoverableRefreshError(_ error: Error) -> Bool {
        // Replace this with actual error checking logic to detect invalid/expired refresh token
        // For example, if error is a HTTP 401 or specific APIError code
        // Here we assume error.localizedDescription contains "invalid refresh token" or "expired"
        let desc = error.localizedDescription.lowercased()
        if desc.contains("invalid refresh token") || desc.contains("expired") || desc.contains("unauthorized") {
            return true
        }
        return false
    }
    
    private enum LogoutReason {
        case invalidRefreshToken
        case maxRetryReached
    }
    
    private func notifyLogout(reason: LogoutReason) {
        switch reason {
        case .invalidRefreshToken:
            errorMessage = "Your session has expired. Please sign in again."
        case .maxRetryReached:
            errorMessage = "Failed to refresh session after multiple attempts. Please sign in again."
        }
        // Additional actions to notify UI or navigate to login can be added here later
    }
}

// MARK: - Token Persistence
extension AuthViewModel {
    private var tokenKey: String { "com.tts.accessTokenData" }

    func saveTokenData() {
        guard let tokenData else { return }
        if let encoded = try? JSONEncoder().encode(tokenData) {
            KeychainService.save(key: tokenKey, data: encoded)
        }
    }

    func loadTokenData() {
        guard let data = KeychainService.load(key: tokenKey),
              let decoded = try? JSONDecoder().decode(TokenData.self, from: data) else {
            return
        }
        self.tokenData = decoded
    }

    func clearTokenData() {
        KeychainService.delete(key: tokenKey)
        self.tokenData = nil
    }
}
