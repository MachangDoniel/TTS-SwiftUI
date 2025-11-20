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
    @Published var apiError: APIError?
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var hasLoadedFromKeychain = false
    
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
            apiError = APIError.network(error)
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
            apiError = APIError.network(error)
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
        case userInitiated
        case unauthorized
        case invalidRefreshToken
        case maxRetryReached
    }
    
    private func notifyLogout(reason: LogoutReason) {
        switch reason {
        case .userInitiated:
            apiError = .unauthorized
        case .unauthorized:
            apiError = .unauthorized
        case .invalidRefreshToken:
            apiError = .unauthorized
        case .maxRetryReached:
            apiError = .server(401)
        }
        // Additional UI handling can be added later
    }
    
    // MARK: - JWT Helpers
    /// Attempts to decode the `exp` (expiry) claim from a JWT access token and return it as a Date.
    /// Returns nil if decoding fails or the claim is not present.
    private static func decodeJWTExpiry(from jwt: String) -> Date? {
        // JWT format: header.payload.signature (Base64URL)
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        let payloadPart = String(parts[1])

        // Convert Base64URL to Base64 by replacing URL-safe characters and padding
        var base64 = payloadPart.replacingOccurrences(of: "-", with: "+")
                                 .replacingOccurrences(of: "_", with: "/")
        let paddingLength = 4 - (base64.count % 4)
        if paddingLength < 4 { base64 += String(repeating: "=", count: paddingLength) }

        guard let data = Data(base64Encoded: base64) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let dict = json as? [String: Any] else { return nil }

        // `exp` is seconds since epoch
        if let exp = dict["exp"] as? Double {
            return Date(timeIntervalSince1970: exp)
        } else if let expInt = dict["exp"] as? Int {
            return Date(timeIntervalSince1970: TimeInterval(expInt))
        }
        return nil
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

    func loadTokenData() async {
        guard let data = await KeychainService.loadAsync(key: tokenKey),
              let decoded = try? JSONDecoder().decode(TokenData.self, from: data) else {
            return
        }
        // Validate expiry using JWT `exp` if present in access token
        let accessToken = decoded.accessToken
        if let expDate = Self.decodeJWTExpiry(from: accessToken), expDate < Date() {
            // Token expired, clear and request refresh later
            clearTokenData()
            return
        }

        // Persist decoded token in memory
        self.tokenData = decoded
    }

    // New async wrapper used by the view
    func loadTokenDataIfNeeded() async {
        if !hasLoadedFromKeychain {
            await loadTokenData()
            hasLoadedFromKeychain = true
        }
    }

    func clearTokenData() {
        KeychainService.delete(key: tokenKey)
        self.tokenData = nil
    }
}

