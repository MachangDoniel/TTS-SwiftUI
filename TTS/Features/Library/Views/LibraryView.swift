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
    @State private var actionItem: RecentActivity? = nil
    @State private var showDeleteConfirm: Bool = false
    @State private var renamingItem: RecentActivity? = nil
    @State private var newTitle: String = ""
    @EnvironmentObject private var tts: TTSPlayer

    private var deleteAlertTitle: String {
        let name = actionItem?.title ?? "this item"
        return "Are you sure to delete \(name)?"
    }

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
                                            HStack(alignment: .center, spacing: 8) {
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
                                                .buttonStyle(PlainButtonStyle())

                                                Menu {
                                                    Button("Rename", systemImage: "pencil") {
                                                        renamingItem = item
                                                        newTitle = item.title
                                                    }
                                                    Button(role: .destructive) {
                                                        actionItem = item
                                                        showDeleteConfirm = true
                                                    } label: {
                                                        Label("Delete", systemImage: "trash")
                                                    }
                                                } label: {
                                                    Image(systemName: "ellipsis")
                                                        .rotationEffect(.degrees(90))
                                                        .foregroundColor(.white)
                                                        .padding(8)
                                                        .background(Color.white.opacity(0.08))
                                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                                }
                                            }
                                            .padding(.horizontal, 12)
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
                .sheet(item: $renamingItem, onDismiss: { newTitle = "" }) { item in
                    NavigationStack {
                        Form {
                            Section(header: Text("Rename")) {
                                TextField("Title", text: $newTitle)
                            }
                        }
                        .navigationTitle("Rename")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { renamingItem = nil }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Save") {
                                    recentStore.rename(id: item.id, newTitle: newTitle)
                                    renamingItem = nil
                                }
                            }
                        }
                    }
                }
                .alert(deleteAlertTitle, isPresented: $showDeleteConfirm) {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete", role: .destructive) {
                        if let item = actionItem {
                            recentStore.deleteItem(id: item.id, removeFile: false)
                        }
                        actionItem = nil
                    }
                } message: {
                    Text("This action cannot be undone.")
                }
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
