//
//  LibraryView.swift
//  TTS
//
//  Created by Doniel Tripura on 10/19/25.
//

import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var recentStore: RecentStore
    @State private var selectedFilter: FileFilter = .all
    @State private var selectedDocumentURL: URL? = nil
    @EnvironmentObject private var tts: TTSPlayer

    private let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df
    }()

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
                                        ForEach(filteredItems) { item in
                                            Button {
                                                // Resolve via bookmark first if present
                                                var opened = false
                                                if let bm = item.bookmarkData {
                                                    var isStale = false
                                                    if let resolved = try? URL(resolvingBookmarkData: bm, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale) {
                                                        if resolved.startAccessingSecurityScopedResource() {
                                                            // Stop any ongoing TTS to ensure clean refresh
                                                            if tts.currentURL != resolved {
                                                                tts.stop()
                                                            }
                                                            selectedDocumentURL = resolved
                                                            opened = true
                                                            // keep access while viewing; we'll stop on navigate back
                                                        }
                                                    }
                                                }
                                                if !opened {
                                                    if let url = item.resolvedURL, url.isFileURL, FileManager.default.fileExists(atPath: url.path) {
                                                        if tts.currentURL != url {
                                                            tts.stop()
                                                        }
                                                        selectedDocumentURL = url
                                                        opened = true
                                                    } else {
                                                        // TODO: handle links/text or show message
                                                        Logger.log("Unable to resolve local file for: \(item.title)")
                                                    }
                                                }
                                            } label: {
                                                RecentRow(item: item, timeFormatter: timeFormatter)
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
            .navigationDestination(isPresented: Binding(
                get: { selectedDocumentURL != nil },
                set: { if !$0 { selectedDocumentURL = nil } }
            )) {
                if let url = selectedDocumentURL {
                    FileViewer(fileURL: url, tts: tts)
                        .navigationTitle(url.lastPathComponent)
                        .navigationBarTitleDisplayMode(.inline)
                } else {
                    EmptyView()
                }
            }
        }
    }

    // Filter logic based on FileFilter and item kind
    private var filteredItems: [RecentActivity] {
        switch selectedFilter {
        case .all:
            return recentStore.items
        case .pdf:
            return recentStore.items.filter { item in
                item.fileExtensionLowercased == "pdf"
            }
        case .text:
            return recentStore.items.filter { item in
                let ext = item.fileExtensionLowercased ?? ""
                return ["txt", "md", "rtf"].contains(ext)
            }
        case .image:
            return recentStore.items.filter { item in
                let ext = item.fileExtensionLowercased ?? ""
                return ["png","jpg","jpeg","heic","gif","tiff","bmp","webp"].contains(ext)
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

