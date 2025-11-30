//
//  LibraryView.swift
//  TTS
//
//  Created by Doniel Tripura on 10/19/25.
//

import SwiftUI

private struct LibraryDocumentItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct LibraryView: View {
    @EnvironmentObject private var recentStore: RecentStore
    @State private var selectedFilter: FileCategory = .all
    @State private var selectedDocumentURL: URL? = nil
    @State private var selectedDocumentItem: LibraryDocumentItem? = nil
    @EnvironmentObject private var tts: TTSPlayer

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 16) {
                    // Top filters
                    FilterBar(selected: $selectedFilter)
                        .padding(.top, 12)

                    if filteredItems.isEmpty {
                        EmptyLibraryView()
                            .padding(.top, 20)
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 20) {
                                // Recent Activity Section
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Recent Activities")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.top, 12)

                                    VStack(spacing: 12) {
                                        ForEach(filteredItems, id: \.id) { item in
                                            Button {
                                                var opened = false
                                                if let bm = item.bookmarkData {
                                                    var isStale = false
                                                    if let resolved = try? URL(resolvingBookmarkData: bm, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale),
                                                       resolved.startAccessingSecurityScopedResource() {
                                                        openRecentItem(url: resolved)
                                                        opened = true
                                                    }
                                                }
                                                if !opened, let url = item.resolvedURL, url.isFileURL, FileManager.default.fileExists(atPath: url.path) {
                                                    openRecentItem(url: url)
                                                    opened = true
                                                }
                                                if !opened {
                                                    Logger.log("Unable to resolve local file for: \(item.title)")
                                                }
                                            } label: {
                                                RecentRow(item: item)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .contentShape(Rectangle())
                                            }
                                            .padding(.horizontal, 12)
                                            .swipeActions(edge: .trailing) {
                                                Button(role: .destructive) {
                                                    recentStore.deleteItem(id: item.id, removeFile: false)
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            }
                                        }
                                    }
                                    .padding(.bottom, 12)
                                }
                                .background(Color(red: 0.10, green: 0.10, blue: 0.11))
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            }
                            .padding(.top, 8)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
            }
            .fullScreenCover(item: $selectedDocumentItem) { item in
                FileViewer(fileURL: item.url, tts: tts)
            }
        }
    }

    // Unified open flow for recent items: stop previous TTS, prepare new file (paused), present viewer
    private func openRecentItem(url: URL) {
        // 1) Stop any previous TTS session right away
        tts.stop()
        // 2) Restart TTS for this new file and pause (no auto-start)
        tts.prepareNewFileOnly(text: "", url: url, title: url.lastPathComponent)
        // 3) Present FileViewer
        selectedDocumentURL = url
        selectedDocumentItem = LibraryDocumentItem(url: url)
    }

    // Filter logic based on FileCategory and item kind
    private var filteredItems: [RecentActivity] {
        recentStore.items.filter { item in
            switch selectedFilter {
            case .all:
                return true
            case .pdf:
                return item.fileExtension.isPDF
            case .text:
                return item.fileExtension.isText
            case .image:
                return item.fileExtension.isImage
            }
        }
    }
}

#Preview {
    NavigationStack {
        LibraryView()
            .environmentObject(RecentStore())
            .environmentObject(TTSPlayer())
            .preferredColorScheme(.dark)
    }
}

