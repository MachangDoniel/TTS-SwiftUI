//
//  OnlineLibraryView.swift
//  TTS
//
//  Created by Assistant on 6/15/26.
//

import SwiftUI

struct OnlineLibraryView: View {
    @EnvironmentObject private var onlineLibraryStore: OnlineLibraryStore
    @EnvironmentObject private var tts: TTSPlayer
    @State private var selectedItem: OnlineLibraryItem? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if onlineLibraryStore.projects.isEmpty {
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
                    }
                    .padding(24)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            ForEach(onlineLibraryStore.projects) { project in
                                VStack(alignment: .leading, spacing: 14) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(project.projectTitle)
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.white)
                                            .lineLimit(2)

                                        Text(sourceLine(for: project))
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .lineLimit(2)
                                    }

                                    ForEach(project.items) { item in
                                        Button {
                                            open(item)
                                        } label: {
                                            HStack(spacing: 12) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(item.generatedFileName)
                                                        .font(.subheadline.weight(.medium))
                                                        .foregroundColor(.white)
                                                        .lineLimit(1)

                                                    Text("Voice: \(item.voiceName)")
                                                        .font(.caption)
                                                        .foregroundColor(.gray)

                                                    if item.primaryLocalAudioURL != nil || item.primaryRemoteAudioURL != nil {
                                                        Text("Audio linked")
                                                            .font(.caption2)
                                                            .foregroundColor(.green)
                                                    }

                                                    Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                                                        .font(.caption2)
                                                        .foregroundColor(.gray.opacity(0.8))
                                                }

                                                Spacer()

                                                Image(systemName: "doc.text.fill")
                                                    .foregroundColor(.white)
                                            }
                                            .padding(14)
                                            .background(Color.white.opacity(0.06))
                                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(16)
                                .background(Color(red: 0.10, green: 0.10, blue: 0.11))
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Library Online")
            .fullScreenCover(item: $selectedItem) { item in
                OnlineLibraryPlayerView(item: item, tts: tts)
            }
        }
    }

    private func sourceLine(for project: OnlineLibraryProject) -> String {
        let ext = project.originalSourceExtension.isEmpty ? "unknown" : project.originalSourceExtension.uppercased()
        return "Original: \(project.originalSourceURL) • \(ext)"
    }

    private func open(_ item: OnlineLibraryItem) {
        selectedItem = item
    }
}

#Preview {
    OnlineLibraryView()
        .environmentObject(OnlineLibraryStore.shared)
        .environmentObject(TTSPlayer())
        .preferredColorScheme(.dark)
}
