import SwiftUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @StateObject private var settings = SettingsProvider.shared
    
    @State private var showImagePicker = false
    @State private var profileImage: UIImage? = UIImage(named: "profileTiger") // Example
    @State private var isShowingMailView = false
    @State private var isShowingShareSheet = false
    @State private var navigateToAbout: Bool = false
    @State private var isShowingLogoutAlert = false
    @State private var isShowingPrivacyPolicy = false
    @State private var isShowingTermsOfUse = false
    
    @State private var showFeedbackPopup = false
    @State private var feedbackTitle: String? = nil
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // MARK: Avatar
                    avatarSection
                    
                    // MARK: Info
                    infoSection
                    
//                    Text("Settings")
//                        .padding(20)
                    
                    // MARK: Settings
                    settingsSection
                    
                    // MARK: Logout
                    logoutButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .allowsHitTesting(!showFeedbackPopup)
        }
        .overlay(
            ZStack {
                if showFeedbackPopup {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea(.container, edges: .all)
                        .ignoresSafeArea(.keyboard) // allow dim to extend under keyboard
                        .contentShape(Rectangle()) // ensure it receives taps everywhere
                        .transition(.opacity)
                        .onTapGesture { showFeedbackPopup = false }

                    // Centered popup with slight offset for keyboard avoidance
                    FeedbackPopup(
                        isPresented: $showFeedbackPopup,
                        title: feedbackTitle ?? "",
                        onSubmit: { text in
                            Logger.log("User wrote: \(text)")
                            showFeedbackPopup = false
                        }
                    )
                    .padding(.horizontal, 24)
                    .zIndex(1)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showFeedbackPopup)
            .zIndex(10)
            .ignoresSafeArea(.keyboard)
        )
//        .disabled(showFeedbackPopup)
        .sheet(isPresented: $isShowingShareSheet) {
            ShareSheet(activityItems: ["Check out this awesome app!"])
        }
        .sheet(isPresented: $isShowingPrivacyPolicy) {
            if let privacyURL = URL(string: AppURLs.privacyPolicy.absoluteString) {
                InAppBrowserView(url: privacyURL, title: "Privacy Policy")
            }
        }
        .sheet(isPresented: $isShowingTermsOfUse) {
            if let termsURL = URL(string: AppURLs.terms.absoluteString) {
                InAppBrowserView(url: termsURL, title: "Terms of Use")
            }
        }
        .loadingOverlay($authVM.isLoading)
    }
    
    // MARK: - Avatar
    private var avatarSection: some View {
        ZStack(alignment: .bottomTrailing) {
            if let url = URL(string: settings.pictureURL), !settings.pictureURL.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 130, height: 130)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 130, height: 130)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 2))
                            .shadow(radius: 6)
                    case .failure(_):
                        fallbackProfileImage
                    @unknown default:
                        fallbackProfileImage
                    }
                }
            } else {
                fallbackProfileImage
            }
            
            Button {
                showImagePicker.toggle()
            } label: {
                Circle()
                    .fill(Color.white)
                    .frame(width: 34, height: 34)
                    .overlay(
                        Image(systemName: "camera.fill")
                            .foregroundColor(.black)
                            .font(.system(size: 16, weight: .semibold))
                    )
                    .shadow(radius: 3)
            }
            .offset(x: -6, y: -6)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
    
    private var fallbackProfileImage: some View {
        Group {
            if let image = profileImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 130, height: 130)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 2))
                    .shadow(radius: 6)
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 130, height: 130)
                    .overlay(Image(systemName: "person.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white.opacity(0.8)))
            }
        }
    }
    
    // MARK: - Info Section
    private var infoSection: some View {
        VStack(spacing: 0) {
            InfoRow(label: "Name", value: safeName)
            Divider().background(Color.white.opacity(0.1))
            InfoRow(label: "Email", value: safeEmail)
//            Divider().background(Color.white.opacity(0.1))
//            InfoRow(label: "Subscription", value: "Basic plan")
        }
        .background(Color(red: 0.13, green: 0.13, blue: 0.14))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // Safe display values
    private var safeName: String {
        let trimmed = settings.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Name" : trimmed
    }

    private var safeEmail: String {
        let trimmed = settings.email.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Email" : trimmed
    }
    
    // MARK: - Settings Section
    private var settingsSection: some View {
        VStack(spacing: 0) {
//            SettingsRow(title: "Send Feedbacks", action: {
//                feedbackTitle = "Send Feedback"
//                showFeedbackPopup = true
//            })
//            Divider().background(Color.white.opacity(0.1))
//            SettingsRow(title: "Request for Feature", action: {
//                feedbackTitle = "Request Feature"
//                showFeedbackPopup = true
//            })
//            Divider().background(Color.white.opacity(0.1))
//            SettingsRow(title: "Review on the App Store", action: { requestAppReview() })
//            Divider().background(Color.white.opacity(0.1))
//            SettingsRow(title: "Share with Friends", action: { isShowingShareSheet = true })
//            Divider().background(Color.white.opacity(0.1))
            SettingsRow(title: "Privacy Policy", action: { isShowingPrivacyPolicy = true })
            Divider().background(Color.white.opacity(0.1))
            SettingsRow(title: "Terms of Use", action: { isShowingTermsOfUse = true })
            Divider().background(Color.white.opacity(0.1))
            SettingsRow(title: "About", action: { navigateToAbout = true })
                .background(
                    NavigationLink(destination: AboutView(), isActive: $navigateToAbout) {
                        EmptyView()
                    }
                    .hidden()
                )
        }
        .background(Color(red: 0.13, green: 0.13, blue: 0.14))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - Logout
    private var logoutButton: some View {
        Button(role: .destructive) {
            isShowingLogoutAlert = true
        } label: {
            Text("Log Out")
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundColor(.red)
        }
        .background(Color(red: 0.13, green: 0.13, blue: 0.14))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .confirmAlert(
            "Are you sure you want to log out?",
            isPresented: $isShowingLogoutAlert,
            message: "You will need to sign in again to access your account.",
            confirmTitle: "Log Out",
            confirmRole: SwiftUI.ButtonRole.destructive,
            cancelTitle: "Cancel",
            onConfirm: {
                Task {
                    await authVM.logout()
                }
            }
        )
    }
    
    // MARK: - Helpers
    private func requestAppReview() {
        // TODO: Trigger SKStoreReviewController.requestReview(in:) where appropriate.
    }
}

// Fallback local confirmAlert in case the utility extension is not compiled in this target.
private struct _ConfirmAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String?
    let confirmTitle: String
    let confirmRole: SwiftUI.ButtonRole?
    let cancelTitle: String
    let onConfirm: () -> Void
    let onCancel: (() -> Void)?

    func body(content: Content) -> some View {
        content.alert(title, isPresented: $isPresented) {
            Button(cancelTitle, role: .cancel) { onCancel?() }
            Button(confirmTitle, role: confirmRole) { onConfirm() }
        } message: {
            if let message { Text(message) }
        }
    }
}

private extension View {
    func confirmAlert(
        _ title: String,
        isPresented: Binding<Bool>,
        message: String? = nil,
        confirmTitle: String = "OK",
        confirmRole: SwiftUI.ButtonRole? = nil,
        cancelTitle: String = "Cancel",
        onConfirm: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) -> some View {
        modifier(
            _ConfirmAlertModifier(
                isPresented: isPresented,
                title: title,
                message: message,
                confirmTitle: confirmTitle,
                confirmRole: confirmRole,
                cancelTitle: cancelTitle,
                onConfirm: onConfirm,
                onCancel: onCancel
            )
        )
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ProfileView()
    }
    .preferredColorScheme(.dark)
}

