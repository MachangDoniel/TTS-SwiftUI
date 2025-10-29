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

@MainActor
final class GoogleAuthViewModel: ObservableObject {
    @Published var isSignedIn = false
    @Published var userName: String?
    @Published var userEmail: String?
    @Published var backendToken: String?
    @Published var errorMessage: String?
    @Published var isLoading = false

    private let clientID = "24441484601-daoeh4vfc9gmle4j9cnavje5lf09m48d.apps.googleusercontent.com"

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

            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            let user = result.user

            guard let idToken = user.idToken?.tokenString else {
                errorMessage = "Missing ID token"
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
}
