//
//  SettingsViewV2.swift
//  TTS
//
//  Created by Doniel Tripura on 6/17/26.
//

import SwiftUI
import UIKit

struct SettingsViewV2: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @EnvironmentObject private var tts: TTSPlayer
    @EnvironmentObject private var voiceCatalog: VoiceCatalog
    @Environment(\.openURL) private var openURL
    @StateObject private var settings = SettingsProvider.shared

    @State private var showImagePicker = false
    @State private var profileImage: UIImage? = UIImage(named: "profileTiger")
    @State private var isShowingLogoutAlert = false
    @State private var isShowingAbout = false
    @State private var isShowingLanguagePicker = false
    @State private var isShowingVoicePreferences = false
    @State private var isShowingPrivacyPolicy = false
    @State private var isShowingTermsOfUse = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    header
                    profileCard
                    subscriptionCard
                    voicePreferencesCard
                    websiteCard
                    helpCard
                    logoutButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $isShowingAbout) {
            NavigationStack {
                AboutView()
            }
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
        .sheet(isPresented: $isShowingLanguagePicker) {
            LanguagePickerView()
                .environmentObject(tts)
                .environmentObject(voiceCatalog)
        }
        .sheet(isPresented: $isShowingVoicePreferences) {
            VoicePreferencesViewV2()
                .environmentObject(tts)
                .environmentObject(voiceCatalog)
        }
        .loadingOverlay($authVM.isLoading)
    }
}

private extension SettingsViewV2 {
    var background: some View {
        LinearGradient(
            colors: [Color(hex: "#0E0E12"), Color(hex: "#0B0B0F"), Color(hex: "#09090B")],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var header: some View {
        HStack {
            Text("Settings")
                .font(.system(size: 30, weight: .regular, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(.top, 6)
    }

    var profileCard: some View {
        VStack(spacing: 18) {
            profileAvatar

            Text(safeEmail)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 18)
        .background(cardBackground)
    }

    var profileAvatar: some View {
        ZStack {
            if let image = profileImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let url = URL(string: settings.pictureURL), !settings.pictureURL.isEmpty {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(ProgressView().tint(.white))
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        fallbackAvatar
                    @unknown default:
                        fallbackAvatar
                    }
                }
            } else {
                fallbackAvatar
            }
        }
        .frame(width: 94, height: 94)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 6)
        .onTapGesture { showImagePicker = true }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(source: .photoLibrary, selectedImage: $profileImage, onImagePicked: { _ in })
        }
    }

    var fallbackAvatar: some View {
        Circle()
            .fill(Color.white.opacity(0.08))
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            )
    }

    var subscriptionCard: some View {
        HStack(spacing: 14) {
            iconCircle(systemName: "rosette")

            VStack(alignment: .leading, spacing: 4) {
                Text("Subscription Expired")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Expired On: 09.05.2026")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.68))
            }

            Spacer(minLength: 8)

            Button {
                // TODO: connect billing flow
            } label: {
                Text("RENEW")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "#C8B7FF"))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(cardBackground)
    }

    var voicePreferencesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Voice Preferences")
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Text("Choose the saved voice and language used for new uploads.")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white.opacity(0.70))

            VStack(spacing: 0) {
                settingsRow(
                    icon: "mic.fill",
                    title: "Change Voice",
                    value: tts.selectedVoiceName,
                    action: { isShowingVoicePreferences = true }
                )

                Divider().overlay(Color.white.opacity(0.08))

                settingsRow(
                    icon: "translate",
                    title: "Voice Language",
                    value: currentLanguage,
                    action: { isShowingLanguagePicker = true }
                )
            }
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(16)
        .background(cardBackground)
    }

    var websiteCard: some View {
        Button {
            if let url = URL(string: AppURLs.website.absoluteString) {
                openURL(url)
            }
        } label: {
            HStack(spacing: 14) {
                iconCircle(systemName: "globe")
                Text("Visit Our Website")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.78))
            }
            .padding(16)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
    }

    var helpCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Help & Feedback")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.68))
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                settingsRow(icon: "globe", title: "Language", value: "English", action: { isShowingLanguagePicker = true })
                dividerRow
                settingsRow(icon: "star", title: "Rate Us", value: nil, action: { })
                dividerRow
                settingsRow(icon: "envelope", title: "Contact Us", value: nil, action: {
                    if let url = URL(string: "mailto:\(AppURLs.support.absoluteString)") {
                        openURL(url)
                    }
                })
                dividerRow
                settingsRow(icon: "square.and.arrow.up", title: "Share App", value: nil, action: { })
                dividerRow
                settingsRow(icon: "info.circle", title: "Version", value: appVersionText, action: { isShowingAbout = true })
            }
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .padding(.vertical, 2)
        .background(cardBackground)
    }

    var logoutButton: some View {
        Button(role: .destructive) {
            isShowingLogoutAlert = true
        } label: {
            Text("Logout")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(Color(hex: "#FF6E8B"))
                .background(Color(hex: "#3B1522"))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(hex: "#5E2235"), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .alert("Are you sure you want to log out?", isPresented: $isShowingLogoutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Logout", role: .destructive) {
                Task { await authVM.logout() }
            }
        } message: {
            Text("You will need to sign in again to access your account.")
        }
    }

    var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }

    var dividerRow: some View {
        Divider().overlay(Color.white.opacity(0.08))
    }

    func settingsRow(icon: String, title: String, value: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                iconCircle(systemName: icon)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title.uppercased())
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.55))
                    if let value {
                        Text(value)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                if value != nil || title == "Language" || title == "Rate Us" || title == "Contact Us" || title == "Share App" || title == "Version" {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    func iconCircle(systemName: String) -> some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .frame(width: 44, height: 44)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: "#CDBAFF"))
            )
    }

    var safeEmail: String {
        let trimmed = settings.email.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Email" : trimmed
    }

    var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? version : "\(version) (\(build))"
    }

    var currentLanguage: String {
        voiceCatalog.voices.first(where: { $0.voiceSampleId == tts.selectedVoiceSampleId })?.language ?? "English"
    }
}

private struct _SettingsConfirmAlertModifier: ViewModifier {
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
    func settingsConfirmAlert(
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
            _SettingsConfirmAlertModifier(
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

private struct VoicePreferencesViewV2: View {
    @EnvironmentObject private var tts: TTSPlayer
    @EnvironmentObject private var voiceCatalog: VoiceCatalog
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: Int = 0
    @State private var searchText: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#09090B").ignoresSafeArea()

                VStack(spacing: 16) {
                    segmentedHeader
                    filtersRow

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 22) {
                            recentSection
                            ForEach(groupedVoices.keys.sorted(), id: \.self) { language in
                                if let voices = groupedVoices[language], !voices.isEmpty {
                                    languageSection(language: language, voices: voices)
                                }
                            }
                            showMoreButton
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
                .padding(.top, 10)
            }
            .navigationBarHidden(true)
        }
    }
}

private extension VoicePreferencesViewV2 {
    var segmentedHeader: some View {
        HStack(spacing: 0) {
            segment(title: "Premium", isSelected: selectedTab == 0) { selectedTab = 0 }
            segment(title: "Free", isSelected: selectedTab == 1) { selectedTab = 1 }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }

    func segment(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.62))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? Color.white.opacity(0.08) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    var filtersRow: some View {
        HStack(spacing: 12) {
            filterChip(systemName: "magnifyingglass", title: nil) { }
            filterChip(systemName: nil, title: "Languages") { }
            filterChip(systemName: nil, title: "Offline") { }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }

    func filterChip(systemName: String?, title: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemName {
                    Image(systemName: systemName)
                        .font(.system(size: 14, weight: .semibold))
                }
                if let title {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                if title == "Languages" {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recents")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            let recentVoices = filteredVoices.filter { $0.isSystemVoice ? selectedTab == 1 : selectedTab == 0 }.prefix(1)
            ForEach(Array(recentVoices), id: \.id) { voice in
                voiceCard(voice)
            }
        }
    }

    func languageSection(language: String, voices: [Voice]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(language)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            VStack(spacing: 12) {
                ForEach(voices.prefix(4)) { voice in
                    voiceCard(voice)
                }
            }

            Button("Show more \(language) voices") { }
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Color(hex: "#CDBAFF"))
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
    }

    func voiceCard(_ voice: Voice) -> some View {
        Button {
            selectVoice(voice)
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: voice.isBackendVoice ? "lock.fill" : "person.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.72))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(voice.name)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text("\(voice.language) • \(voice.accent.isEmpty ? voice.type : voice.accent)")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if voice.isBackendVoice {
                    Text("PREMIUM")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(Color(hex: "#CDBAFF"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Capsule())
                }

                Button {
                    preview(voice)
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    var showMoreButton: some View {
        Button("Show more voices") { }
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .foregroundStyle(Color(hex: "#CDBAFF"))
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }

    var filteredVoices: [Voice] {
        let base = voiceCatalog.voices.filter { voice in
            let isPremium = voice.type == VoiceType.Premium.rawValue
            return selectedTab == 0 ? isPremium : !isPremium
        }

        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return base }
        let query = searchText.lowercased()
        return base.filter { voice in
            voice.name.lowercased().contains(query) || voice.language.lowercased().contains(query)
        }
    }

    var groupedVoices: [String: [Voice]] {
        Dictionary(grouping: filteredVoices) { $0.language }
    }

    func selectVoice(_ voice: Voice) {
        let targetMode: AppVoiceMode = voice.isSystemVoice ? .system : .backend
        if tts.appVoice != targetMode {
            tts.updateVoiceMode(targetMode)
        }
        tts.selectedVoiceName = voice.name
        tts.updateSelectedVoiceSampleId(voice.voiceSampleId)
    }

    func preview(_ voice: Voice) {
        let targetMode: AppVoiceMode = voice.isSystemVoice ? .system : .backend
        if tts.appVoice != targetMode {
            tts.updateVoiceMode(targetMode)
        }
        tts.selectedVoiceName = voice.name
        tts.updateSelectedVoiceSampleId(voice.voiceSampleId)
    }
}

#Preview {
    SettingsViewV2()
        .environmentObject(AuthViewModel())
        .environmentObject(TTSPlayer())
        .environmentObject(VoiceCatalog.shared)
        .preferredColorScheme(.dark)
}
