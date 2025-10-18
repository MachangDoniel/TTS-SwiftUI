import SwiftUI
import UIKit

struct ProfileView: View {
    @State private var showImagePicker = false
    @State private var profileImage: UIImage? = UIImage(named: "profileTiger") // Example
    @State private var isShowingMailView = false
    @State private var isShowingShareSheet = false
    @State private var isShowingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // MARK: Avatar
                    avatarSection
                    
                    // MARK: Info
                    infoSection
                    
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
        }
        .sheet(isPresented: $isShowingShareSheet) {
            ShareSheet(activityItems: ["Check out this awesome app!"])
        }
        .alert(isPresented: $isShowingAlert) {
            Alert(title: Text("Info"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    // MARK: - Avatar
    private var avatarSection: some View {
        ZStack(alignment: .bottomTrailing) {
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
    
    // MARK: - Info Section
    private var infoSection: some View {
        VStack(spacing: 0) {
            InfoRow(label: "Name", value: "Tashin")
            Divider().background(Color.white.opacity(0.1))
            InfoRow(label: "Email", value: "tashin@gmail.com")
            Divider().background(Color.white.opacity(0.1))
            InfoRow(label: "Subscription", value: "Basic plan")
        }
        .background(Color(red: 0.13, green: 0.13, blue: 0.14))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - Settings Section
    private var settingsSection: some View {
        VStack(spacing: 0) {
            SettingsRow(title: "Send Feedbacks", action: { isShowingMailView = true })
            Divider().background(Color.white.opacity(0.1))
            SettingsRow(title: "Review on the App Store", action: { requestAppReview() })
            Divider().background(Color.white.opacity(0.1))
            SettingsRow(title: "Share with Friends", action: { isShowingShareSheet = true })
            Divider().background(Color.white.opacity(0.1))
            SettingsRow(title: "Privacy Policy", action: { openURL("https://example.com/privacy") })
            Divider().background(Color.white.opacity(0.1))
            SettingsRow(title: "Terms of Use", action: { openURL("https://example.com/terms") })
            Divider().background(Color.white.opacity(0.1))
            SettingsRow(title: "About", action: { alertMessage = "App version 1.0.0"; isShowingAlert = true })
        }
        .background(Color(red: 0.13, green: 0.13, blue: 0.14))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - Logout
    private var logoutButton: some View {
        Button(role: .destructive) {
            alertMessage = "You have been logged out."
            isShowingAlert = true
        } label: {
            Text("Log Out")
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundColor(.red)
        }
        .background(Color(red: 0.13, green: 0.13, blue: 0.14))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - Helpers
    private func requestAppReview() {
        alertMessage = "App review would be triggered here."
        isShowingAlert = true
    }
    
    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Reusable Components

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.white.opacity(0.9))
            Spacer()
            Text(value)
                .foregroundColor(.white.opacity(0.7))
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.horizontal)
        .frame(height: 48)
    }
}

struct SettingsRow: View {
    let title: String
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.horizontal)
            .frame(height: 48)
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ProfileView()
    }
    .preferredColorScheme(.dark)
}
