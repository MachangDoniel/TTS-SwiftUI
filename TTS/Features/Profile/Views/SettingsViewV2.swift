//
//  SettingsViewV2.swift
//  TTS
//
//  Created by Doniel Tripura on 6/17/26.
//

import SwiftUI
import UIKit
import AVFoundation

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
            VoicePreferencesViewV2()
                .environmentObject(tts)
                .environmentObject(voiceCatalog)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingVoicePreferences) {
            VoicePreferencesViewV2()
                .environmentObject(tts)
                .environmentObject(voiceCatalog)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
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

struct VoicePreferencesViewV2: View {
    @EnvironmentObject private var tts: TTSPlayer
    @EnvironmentObject private var voiceCatalog: VoiceCatalog
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: Int = 0
    @State private var searchText: String = ""
    @State private var isSearching = false
    @State private var selectedLanguage: String?
    @State private var showLanguages = false
    @State private var offlineOnly = false
    @State private var cachedAudioVoiceIds: Set<String> = []
    @State private var downloadingVoiceIds: Set<String> = []
    @State private var previewPlayer: AVPlayer?
    @State private var previewEndObserver: NSObjectProtocol?
    @State private var previewingVoiceId: String?
    @State private var pausedPreviewVoiceId: String?
    @State private var isPreviewPlaying = false
    @State private var pendingVoiceSampleId: String = ""
    @State private var pendingVoiceName: String = ""
    @State private var pendingVoiceMode: AppVoiceMode = .system
    @FocusState private var searchFocused: Bool

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
                        .padding(.bottom, 108)
                    }

                    saveVoiceButton
                }
                .padding(.top, 10)
            }
            .navigationBarHidden(true)
            .onAppear {
                loadPendingVoiceFromCurrentSelection()
                refreshCachedAudioState()
            }
            .onChange(of: voiceCatalog.voices) { _ in
                refreshCachedAudioState()
            }
            .onDisappear {
                stopPreview()
            }
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                if isSearching {
                    searchField
                } else {
                    filterChip(systemName: "magnifyingglass", title: nil, isActive: false) {
                        withAnimation {
                            isSearching = true
                            searchFocused = true
                        }
                    }
                    filterChip(systemName: nil, title: selectedLanguage ?? "Languages", isActive: selectedLanguage != nil || showLanguages) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            showLanguages.toggle()
                        }
                    }
                    filterChip(systemName: nil, title: "Offline", isActive: offlineOnly) {
                        withAnimation {
                            offlineOnly.toggle()
                        }
                    }
                    Spacer(minLength: 0)
                }
            }

            if showLanguages && !isSearching {
                languageScroller
            }
        }
        .padding(.horizontal, 16)
    }

    var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.62))
            TextField("Search", text: $searchText)
                .focused($searchFocused)
                .foregroundStyle(.white)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            Button {
                withAnimation {
                    searchText = ""
                    isSearching = false
                    searchFocused = false
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white.opacity(0.62))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    var languageScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                languageChip(title: "All", isSelected: selectedLanguage == nil) {
                    selectedLanguage = nil
                }
                ForEach(voiceCatalog.languages, id: \.self) { language in
                    languageChip(title: language, isSelected: selectedLanguage == language) {
                        selectedLanguage = language
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    func languageChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? Color(hex: "#CDBAFF") : .white.opacity(0.76))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(isSelected ? Color.white.opacity(0.08) : Color.white.opacity(0.04))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    func filterChip(systemName: String?, title: String?, isActive: Bool, action: @escaping () -> Void) -> some View {
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
            .foregroundStyle(isActive ? Color(hex: "#CDBAFF") : .white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(isActive ? Color.white.opacity(0.08) : Color.white.opacity(0.04))
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
        HStack(spacing: 12) {
            Button {
                setPendingVoice(voice)
            } label: {
                HStack(spacing: 12) {
                    VoiceAvatarView(voice: voice)

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
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

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

            previewControl(for: voice)
        }
        .padding(14)
        .background(pendingVoiceSampleId == voice.voiceSampleId ? Color.white.opacity(0.08) : Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(pendingVoiceSampleId == voice.voiceSampleId ? Color(hex: "#CDBAFF").opacity(0.7) : Color.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    var saveVoiceButton: some View {
        Button {
            savePendingVoice()
        } label: {
            Text("Save Voice")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(pendingVoiceSampleId.isEmpty)
        .opacity(pendingVoiceSampleId.isEmpty ? 0.45 : 1)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .background(
            LinearGradient(
                colors: [Color(hex: "#09090B").opacity(0), Color(hex: "#09090B"), Color(hex: "#09090B")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    @ViewBuilder
    func previewControl(for voice: Voice) -> some View {
        if voice.isBackendVoice, voice.audioPreviewURL != nil {
            Button {
                Task { await handlePreviewTap(for: voice) }
            } label: {
                ZStack {
                    if downloadingVoiceIds.contains(voice.voiceSampleId) {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: previewIconName(for: voice))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
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
            let matchesTab = selectedTab == 0 ? isPremium : !isPremium
            let matchesLanguage = selectedLanguage == nil || selectedLanguage == voice.language
            let matchesOffline = !offlineOnly || voice.isSystemVoice || cachedAudioVoiceIds.contains(voice.voiceSampleId)
            return matchesTab && matchesLanguage && matchesOffline
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

    func loadPendingVoiceFromCurrentSelection() {
        pendingVoiceSampleId = tts.selectedVoiceSampleId
        pendingVoiceName = tts.selectedVoiceName
        pendingVoiceMode = resolvedPendingVoiceMode(for: tts.selectedVoiceSampleId) ?? tts.appVoice
    }

    func setPendingVoice(_ voice: Voice) {
        pendingVoiceSampleId = voice.voiceSampleId
        pendingVoiceName = voice.name
        pendingVoiceMode = resolvedPendingVoiceMode(for: voice.voiceSampleId) ?? (voice.isSystemVoice ? .system : .backend)
    }

    func savePendingVoice() {
        guard !pendingVoiceSampleId.isEmpty else { return }
        let targetMode = resolvedPendingVoiceMode(for: pendingVoiceSampleId) ?? pendingVoiceMode
        tts.selectedVoiceName = pendingVoiceName
        if tts.appVoice != targetMode {
            tts.updateVoiceMode(targetMode)
        }
        tts.updateSelectedVoiceSampleId(pendingVoiceSampleId)
        tts.activatePlaybackAudioSession()
        dismiss()
    }

    func resolvedPendingVoiceMode(for voiceSampleId: String) -> AppVoiceMode? {
        guard let voice = voiceCatalog.voices.first(where: { $0.voiceSampleId == voiceSampleId }) else {
            return nil
        }
        return voice.isSystemVoice ? .system : .backend
    }

    @MainActor
    func handlePreviewTap(for voice: Voice) async {
        guard voice.isBackendVoice else { return }

        if previewingVoiceId == voice.voiceSampleId, isPreviewPlaying {
            previewPlayer?.pause()
            pausedPreviewVoiceId = voice.voiceSampleId
            isPreviewPlaying = false
            return
        }

        if let player = previewPlayer, pausedPreviewVoiceId == voice.voiceSampleId {
            player.play()
            previewingVoiceId = voice.voiceSampleId
            pausedPreviewVoiceId = nil
            isPreviewPlaying = true
            return
        }

        let audioURL: URL?
        if let cachedURL = VoiceCatalog.shared.cachedAudioPreviewURL(for: voice) {
            audioURL = cachedURL
        } else {
            downloadingVoiceIds.insert(voice.voiceSampleId)
            audioURL = await VoiceCatalog.shared.downloadAudioPreview(for: voice)
            downloadingVoiceIds.remove(voice.voiceSampleId)
            refreshCachedAudioState()
        }

        guard let audioURL else { return }
        playPreview(url: audioURL, voiceId: voice.voiceSampleId)
    }

    @MainActor
    func playPreview(url: URL, voiceId: String) {
        tts.activatePlaybackAudioSession()

        previewPlayer?.pause()
        if let observer = previewEndObserver {
            NotificationCenter.default.removeObserver(observer)
            previewEndObserver = nil
        }

        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)
        previewEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            previewingVoiceId = nil
            pausedPreviewVoiceId = nil
            isPreviewPlaying = false
        }

        player.play()
        previewPlayer = player
        previewingVoiceId = voiceId
        pausedPreviewVoiceId = nil
        isPreviewPlaying = true

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            if previewingVoiceId == voiceId,
               previewPlayer?.currentItem?.status == .failed {
                let message = previewPlayer?.currentItem?.error?.localizedDescription ?? "unknown player error"
                Logger.log("⚠️ Failed to play preview: \(message)")
                previewingVoiceId = nil
                pausedPreviewVoiceId = nil
                isPreviewPlaying = false
            }
        }
    }

    @MainActor
    func stopPreview() {
        previewPlayer?.pause()
        previewPlayer = nil
        if let observer = previewEndObserver {
            NotificationCenter.default.removeObserver(observer)
            previewEndObserver = nil
        }
        previewingVoiceId = nil
        pausedPreviewVoiceId = nil
        isPreviewPlaying = false
    }

    func previewIconName(for voice: Voice) -> String {
        if previewingVoiceId == voice.voiceSampleId, isPreviewPlaying {
            return "pause.fill"
        }
        return cachedAudioVoiceIds.contains(voice.voiceSampleId) ? "play.fill" : "arrow.down"
    }

    func refreshCachedAudioState() {
        cachedAudioVoiceIds = Set(
            voiceCatalog.voices
                .filter { VoiceCatalog.shared.isAudioPreviewCached(for: $0) }
                .map(\.voiceSampleId)
        )
    }
}

private struct VoiceAvatarView: View {
    let voice: Voice
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(voice.gender == .male ? ImageAssets.male_voice : ImageAssets.female_voice)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(Circle())
        .task(id: "\(voice.imageURL?.absoluteString ?? "")_\(voice.updatedAt ?? "")") {
            guard let data = await VoiceCatalog.shared.imageData(for: voice),
                  let loadedImage = UIImage(data: data) else {
                return
            }
            image = loadedImage
        }
    }
}

#Preview {
    SettingsViewV2()
        .environmentObject(AuthViewModel())
        .environmentObject(TTSPlayer())
        .environmentObject(VoiceCatalog.shared)
        .preferredColorScheme(.dark)
}
