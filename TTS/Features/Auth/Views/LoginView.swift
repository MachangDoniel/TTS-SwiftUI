//
//  LoginView.swift
//  TTS
//
//  Created by Doniel Tripura on 10/19/25.
//

import SwiftUI
import Combine
import GoogleSignIn
import UIKit

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var googleVM = GoogleAuthViewModel()
    @State private var restorationCancellable: AnyCancellable? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            
            // MARK: - Header
            VStack(spacing: 8) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.myPrimaryColor)
                    .symbolRenderingMode(.hierarchical)
                    .padding(.bottom, 4)
                Text("Welcome")
                    .font(.largeTitle.bold())
                Text("Sign in to continue")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 16)
            
            Spacer(minLength: 20)
            
            // MARK: - Loading / Status
            if googleVM.isLoading {
                ProgressView("Signing in...")
                    .padding(.top, 8)
            }
            
            if let token = googleVM.backendToken {
                VStack(spacing: 4) {
                    Text("✅ Signed in successfully")
                        .font(.headline)
                        .foregroundColor(.green)
                    Text("Access Token: \(token.prefix(20))...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            }
            
            if let error = googleVM.errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.subheadline)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.red.opacity(0.08))
                )
                .padding(.top, 8)
            }
            
            Spacer()
            
            // MARK: - Google Sign-In Button (Classic Style)
            if !googleVM.isSignedIn {
                Button(action: {
                    Task {
                        await googleVM.signIn(using: authVM)
                    }
                }) {
                    HStack(spacing: 12) {
                        // ✅ Use bundled Google logo or fallback symbol
                        Group {
                            if let uiImage = UIImage(named: "google-logo") {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                            } else {
                                Image(systemName: "globe")
                                    .symbolRenderingMode(.multicolor)
                                    .font(.system(size: 20, weight: .semibold))
                            }
                        }
                        .frame(width: 20, height: 20)
                        
                        Text("Sign in with Google")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .padding(.horizontal)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
                    )
                }
                .buttonStyle(.plain)
                .disabled(googleVM.isLoading)
                .padding(.horizontal, 40)
            } else {
                Button(action: {
                    googleVM.signOut(using: authVM)
                }) {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 40)
            }
            
            // MARK: - Footer
            Text("By continuing, you agree to our Terms and Privacy Policy.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .onAppear {
            restorationCancellable = NotificationCenter.default
                .publisher(for: Notification.Name("GoogleSignInRestored"))
                .receive(on: RunLoop.main)
                .sink { notif in
                    let user = notif.object as? GIDGoogleUser
                    googleVM.handleRestoredSignIn(user: user)
                }
        }
        .onDisappear {
            restorationCancellable?.cancel()
            restorationCancellable = nil
        }
        .background(
            LinearGradient(
                colors: [Color(.systemGroupedBackground), .white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
