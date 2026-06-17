//
//  OnlineLibraryViewV2.swift
//  TTS
//
//  Created by Doniel Tripura on 6/17/26.
//

import SwiftUI

struct OnlineLibraryViewV2: View {
    @EnvironmentObject private var onlineLibraryStore: OnlineLibraryStore
    @EnvironmentObject private var tts: TTSPlayer
    @State private var selectedItem: OnlineLibraryItem? = nil
    @State private var searchText: String = ""
    @State private var isSearchVisible = false

    var body: some View {
        NavigationStack {
            ZStack {
                background

                if filteredProjects.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 22) {
                            header

                            ForEach(filteredProjects) { project in
                                projectCard(project)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 28)
                    }
                }
            }
            .navigationBarHidden(true)
            .fullScreenCover(item: $selectedItem) { item in
                OnlineLibraryPlayerView(item: item, tts: tts)
            }
        }
    }
}

private extension OnlineLibraryViewV2 {
    var background: some View {
        LinearGradient(
            colors: [Color(hex: "#0C0C10"), Color(hex: "#0B0B0F"), Color(hex: "#09090B")],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    var header: some View {
        HStack {
            Text(isSearchVisible ? "Search" : "Library Online")
                .font(.system(size: 30, weight: .regular, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 12)

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSearchVisible.toggle()
                    if !isSearchVisible { searchText = "" }
                }
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(.white.opacity(0.78))
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
        }
    }

    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 42))
                .foregroundColor(.gray)

            Text("No online projects yet")
                .font(.headline)
                .foregroundColor(.white)

            Text("Generated backend text files will appear here.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }

    func projectCard(_ project: OnlineLibraryProject) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(project.projectTitle)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(sourceLine(for: project))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(2)
            }

            VStack(spacing: 12) {
                ForEach(filteredItems(in: project)) { item in
                    itemRow(item)
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    func itemRow(_ item: OnlineLibraryItem) -> some View {
        Button {
            selectedItem = item
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.78))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.generatedFileName)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text("Voice: \(item.voiceName)")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.white.opacity(0.58))

                    HStack(spacing: 8) {
                        if item.primaryLocalAudioURL != nil || item.primaryRemoteAudioURL != nil {
                            badge("Audio linked", tint: Color(hex: "#B9F7D2"))
                        }
                        badge(item.createdAt.formatted(date: .abbreviated, time: .shortened), tint: .white.opacity(0.7))
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    func badge(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.04))
            .clipShape(Capsule())
    }

    func sourceLine(for project: OnlineLibraryProject) -> String {
        let ext = project.originalSourceExtension.isEmpty ? "unknown" : project.originalSourceExtension.uppercased()
        return "Original: \(project.originalSourceURL) • \(ext)"
    }

    func filteredItems(in project: OnlineLibraryProject) -> [OnlineLibraryItem] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return project.items
        }

        let query = searchText.lowercased()
        return project.items.filter { item in
            item.generatedFileName.lowercased().contains(query) ||
            item.voiceName.lowercased().contains(query) ||
            item.projectTitle.lowercased().contains(query)
        }
    }

    var filteredProjects: [OnlineLibraryProject] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = onlineLibraryStore.projects

        guard !query.isEmpty else { return source }

        return source.compactMap { project in
            let items = filteredItems(in: project)
            guard !items.isEmpty else { return nil }
            return OnlineLibraryProject(
                projectKey: project.projectKey,
                projectTitle: project.projectTitle,
                originalSourceURL: project.originalSourceURL,
                originalSourceExtension: project.originalSourceExtension,
                items: items
            )
        }
    }
}

#Preview {
    OnlineLibraryViewV2()
        .environmentObject(OnlineLibraryStore.shared)
        .environmentObject(TTSPlayer())
        .preferredColorScheme(.dark)
}
