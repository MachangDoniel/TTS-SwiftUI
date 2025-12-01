//
//  GoogleAuthViewModel.swift
//  TTS
//
//  Created by Doniel Tripura on 10/26/25.
//

import SwiftUI
import Combine
import GoogleSignIn
import UIKit
import CryptoKit

@MainActor
final class GoogleAuthViewModel: ObservableObject {
    @Published var isSignedIn = false
    @Published var userName: String?
    @Published var userEmail: String?
    @Published var backendToken: String?
    @Published var errorMessage: String?
    @Published var isLoading = false

    private let clientID = "24441484601-daoeh4vfc9gmle4j9cnavje5lf09m48d.apps.googleusercontent.com"

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: Array<Character> = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess { fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)") }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    // MARK: - Sign In (uses shared AuthViewModel)
    func signIn(using authVM: AuthViewModel) async {
        guard let rootVC = await UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController else {
            errorMessage = "No active window"
            return
        }
        
        do {
            isLoading = true
            errorMessage = nil

            let nonce = randomNonceString()

            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
            
            let result: GIDSignInResult = try await withCheckedThrowingContinuation { continuation in
                GIDSignIn.sharedInstance.signIn(withPresenting: rootVC, hint: nil, additionalScopes: nil, nonce: nonce) { signInResult, error in
                    if let error = error { continuation.resume(throwing: error); return }
                    guard let signInResult = signInResult else {
                        continuation.resume(throwing: NSError(domain: "GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing signInResult"]))
                        return
                    }
                    continuation.resume(returning: signInResult)
                }
            }
            
            let user = result.user

            guard let idToken = user.idToken?.tokenString else {
                errorMessage = "Missing ID token"
                isLoading = false
                return
            }
            
            if let returnedNonce = decodeNonce(fromJWT: idToken), returnedNonce != nonce {
                errorMessage = "Nonce mismatch"
                isLoading = false
                return
            }

            // Call backend
            await authVM.loginWithGoogle(idToken: idToken)

            if let token = authVM.tokenData?.accessToken {
                backendToken = token
                userName = user.profile?.name
                userEmail = user.profile?.email
                isSignedIn = true
                authVM.saveTokenData() // ✅ persist token

                let pictureURL = user.profile?.imageURL(withDimension: 200)?.absoluteString ?? ""
                SettingsProvider.shared.name = user.profile?.name ?? ""
                SettingsProvider.shared.email = user.profile?.email ?? ""
                SettingsProvider.shared.pictureURL = pictureURL
            } else {
                errorMessage = authVM.errorMessage ?? "Login failed"
            }

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Sign Out
    func signOut(using authVM: AuthViewModel) {
        GIDSignIn.sharedInstance.signOut()
        authVM.clearTokenData()
        isSignedIn = false
        backendToken = nil
    }
    
    func handleRestoredSignIn(user: GIDGoogleUser?) {
        if let user = user {
            self.userName = user.profile?.name
            self.userEmail = user.profile?.email
            self.isSignedIn = true
        }
    }
    
    private func decodeNonce(fromJWT jwt: String) -> String? {
        let segments = jwt.components(separatedBy: ".")
        guard segments.count > 1, let payload = decodeJWTSegment(segments[1]), let nonce = payload["nonce"] as? String else { return nil }
        return nonce
    }

    private func decodeJWTSegment(_ segment: String) -> [String: Any]? {
        var base64 = segment.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let length = Double(base64.lengthOfBytes(using: .utf8))
        let requiredLength = 4 * ceil(length / 4.0)
        let paddingLength = requiredLength - length
        if paddingLength > 0 {
            let padding = String(repeating: "=", count: Int(paddingLength))
            base64 += padding
        }
        guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters),
              let json = try? JSONSerialization.jsonObject(with: data),
              let payload = json as? [String: Any] else { return nil }
        return payload
    }
}
