//
//  LanguagePickerView.swift
//  TTS
//
//  Created by Doniel Tripura on 10/20/25.
//

import SwiftUI
import AVFoundation
import Combine

// MARK: - View

struct LanguagePickerView: View {
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var showLanguageOptions = false
    @State private var selectedFilter: VoiceType? = nil // nil = all
    @State private var selectedLanguage: String? = nil // nil = all
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @FocusState private var isSearchFieldFocused: Bool

    /// shared TTS player (via environment)
    @EnvironmentObject var tts: TTSPlayer
    
    @EnvironmentObject var voiceCatalog: VoiceCatalog

    // MARK: - Filtering
    var filteredVoices: [Voice] {
        voiceCatalog.voices.filter { voice in
            let matchesSearch = searchText.isEmpty ||
                voice.name.localizedCaseInsensitiveContains(searchText) ||
                voice.language.localizedCaseInsensitiveContains(searchText)
            let matchesLanguage = selectedLanguage == nil || voice.language == selectedLanguage
            let matchesType = selectedFilter == nil || voice.type == selectedFilter?.rawValue
            return matchesSearch && matchesLanguage && matchesType
        }
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let error = errorMessage {
                    VStack {
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.9))
                            .clipShape(Capsule())
                            .padding(.top, 8)
                        Spacer()
                    }
                    .transition(.opacity)
                }

                VStack(spacing: 0) {
                    // MARK: - Top Bar
                    HStack(spacing: 12) {
                        if isSearching {
                            searchBar
                        } else {
                            controlButtons
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .padding(.top, 30)
                    .background(Color.black.opacity(0.95))
//                    .overlay(
//                        ZStack {
//                            if isLoading {
//                                // Loading ring around the control area
//                                ProgressView()
//                                    .progressViewStyle(.circular)
//                                    .tint(.white)
//                            }
//                        }
//                    )

                    // MARK: - Language Filter
                    if showLanguageOptions && !isSearching {
                        languageFilter
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // MARK: - List
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(selectedLanguage ?? "All Languages")
                                .font(.title3)
                                .bold()
                                .padding(.horizontal)
                                .foregroundColor(.white)

                            if filteredVoices.isEmpty {
                                Text("No voices found")
                                    .foregroundColor(.gray)
                                    .padding(.horizontal)
                            } else {
                                ForEach(filteredVoices) { voice in
                                    Button {
                                        selectVoice(voice)
                                    } label: {
                                        VoiceCard(voice: voice)
                                    }
                                }
                            }
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 40)
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Components

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search", text: $searchText)
                .focused($isSearchFieldFocused)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        isSearchFieldFocused = true
                    }
                }
        }
        .padding(8)
        .background(Color(.systemGray6).opacity(0.2))
        .cornerRadius(8)
        .overlay(
            HStack {
                Spacer()
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .padding(.trailing, 8)
                    }
                }
            }
        )
        .overlay(
            HStack {
                Spacer()
                Button("Cancel") {
                    withAnimation {
                        isSearching = false
                        searchText = ""
                        isSearchFieldFocused = false
                    }
                }
                .foregroundColor(.white)
                .padding(.trailing, 6)
            }
        )
    }

    private var controlButtons: some View {
        HStack {
            Button(action: { withAnimation { isSearching = true } }) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }

            Button(action: { withAnimation(.spring()) { showLanguageOptions.toggle() } }) {
                HStack(spacing: 4) {
                    Text("Language")
                        .font(.headline)
                    Image(systemName: showLanguageOptions ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundColor(showLanguageOptions ? Color.blue : Color.white)
                .background(showLanguageOptions ? Color.blue.opacity(0.2) : Color(.systemGray6))
                .clipShape(Capsule())
            }

            Button(action: {
                withAnimation {
                    selectedFilter = (selectedFilter == VoiceType.Free) ? nil : VoiceType.Free
                }
            }) {
                Text("Free")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .foregroundColor(selectedFilter == VoiceType.Free ? Color.blue : Color.white)
                    .background(selectedFilter == VoiceType.Free ? Color.blue.opacity(0.2) : Color(.systemGray6))
                    .clipShape(Capsule())
            }

            Spacer()
        }
    }

    private var languageFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(voiceCatalog.languages, id: \.self) { lang in
                    Button(action: {
                        withAnimation {
                            selectedLanguage = (selectedLanguage == lang) ? nil : lang
                        }
                    }) {
                        Text(lang)
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .foregroundColor(selectedLanguage == lang ? Color.blue : Color.white)
                            .background(selectedLanguage == lang ? Color.blue.opacity(0.2) : Color(.systemGray6))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 6)
        }
    }

    // MARK: - Voice Selection Logic

    private func selectVoice(_ voice: Voice) {
        // update voice id and mode
        errorMessage = nil
        isLoading = true

        // Snapshot BEFORE stopping or changing routing
        let snapshotSentences = tts.sentences
        let snapshotCurrent = tts.currentSentenceText

        // Helper to normalize matching
        func normalize(_ s: String) -> String {
            s.trimmingCharacters(in: .whitespacesAndNewlines)
             .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        }

        tts.selectedVoiceSampleId = voice.voiceSampleId
        if voice.type == VoiceType.Free.rawValue {
            tts.appVoice = .system
        } else {
            // Any non-Free (e.g., Premium) should use backend flow
            tts.appVoice = .backend
        }

        Logger.debugPrint("🎙 Selected voice=\(voice.name) type=\(voice.type) → routing=\(tts.appVoice == .backend ? "backend" : "local")")

        Task { @MainActor in
            do {
                // Use snapshots captured BEFORE stopping
                let sentences = snapshotSentences
                let currentSentence = snapshotCurrent

                // Robust index match using normalization
                let normCurrent = normalize(currentSentence)
                let currentIndex: Int? = sentences.firstIndex { normalize($0) == normCurrent }

                // Determine routing change (free <-> premium)
                let isPremiumSelected = (voice.type != VoiceType.Free.rawValue)
                let previousWasBackend = (tts.appVoice == .backend) // appVoice currently reflects target routing; if you track previous routing, inject it here
                let routingChanged = previousWasBackend != isPremiumSelected

                // Choose resume index: next sentence if routing changed and no active current, else keep current
                let resumeIndex: Int? = {
                    if let idx = currentIndex, !sentences.isEmpty {
                        if routingChanged {
                            return normCurrent.isEmpty ? min(idx + 1, sentences.count - 1) : idx
                        } else {
                            return idx
                        }
                    }
                    return nil
                }()

                // Build text to read from resume index onward
                let textToRead: String = {
                    if let idx = resumeIndex, !sentences.isEmpty {
                        return sentences[idx...].joined(separator: " ")
                    }
                    if !currentSentence.isEmpty { return currentSentence }
                    return sentences.joined(separator: " ")
                }()

                // Remaining chunks estimate for backend task creation
                let remainingChunks: Int = {
                    if let idx = resumeIndex { return max(sentences.count - idx, 0) }
                    return max(sentences.count - (currentIndex ?? 0), 0)
                }()
                Logger.debugPrint("📦 Backend remaining chunks estimate: \(remainingChunks)")

                // Stop current speech now (after snapshot)
                tts.stop()

                // Align highlighting to the sentence we will start from
                if let idx = resumeIndex, !sentences.isEmpty {
                    tts.currentSentenceText = sentences[idx]
                } else if !currentSentence.isEmpty {
                    tts.currentSentenceText = currentSentence
                }

                // Restart reading
                if !textToRead.isEmpty {
                    try await tts.startReading(textToRead)
                } else {
                    Logger.debugPrint("ℹ️ No text to read.")
                }

                // Success → stop loading
                isLoading = false
            } catch {
                // Failure → show error and pause control
                isLoading = false
                errorMessage = (error as NSError).localizedDescription
                Logger.debugPrint("🗣 ❌ Failed to start reading: \(error.localizedDescription)")

                // Auto-dismiss the error banner after a short delay
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    if errorMessage == (error as NSError).localizedDescription {
                        withAnimation { errorMessage = nil }
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    LanguagePickerView()
        .environmentObject(TTSPlayer())
        .environmentObject(VoiceCatalog.shared)
}
