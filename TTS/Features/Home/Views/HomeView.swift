//
//  HomeView.swift
//  TTS
//
//  Created by Doniel Tripura on 10/19/25.
//

import SwiftUI
import UIKit

struct HomeView: View {
    // Callbacks for actions
    var onPickFiles: (() -> Void)?
    var onPickGDrive: (() -> Void)?
    var onPickPhotos: (() -> Void)?
    var onScan: (() -> Void)?
    var onPickDropbox: (() -> Void)?
    var onPickBook: (() -> Void)?
    var onTypeText: (() -> Void)?
    var onPasteLink: (() -> Void)?
    var onTryForFree: (() -> Void)?
    var onOpenRecent: ((RecentActivity) -> Void)?
    
    @EnvironmentObject private var recentStore: RecentStore
    @EnvironmentObject private var tts: TTSPlayer
    
    @State private var renamingItem: RecentActivity? = nil
    @State private var newTitle: String = ""
    @State private var showDeleteConfirm: Bool = false
    @State private var pendingDeleteItem: RecentActivity? = nil

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 5) {
                    header
                    importSection
                    recentSection
                }
                .padding(.bottom, 32)
            }
            .background(
                Color(hex: Color.primaryBackgroundColor).ignoresSafeArea()
            )
        }
        .alert(pendingDeleteItem != nil ? "Are you sure to delete \(pendingDeleteItem!.title)?" : "Are you sure to delete this item?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {
                pendingDeleteItem = nil
            }
            Button("Delete", role: .destructive) {
                if let toDelete = pendingDeleteItem {
                    recentStore.deleteItem(id: toDelete.id, removeFile: false)
                }
                pendingDeleteItem = nil
            }
        } message: {
            Text("This action cannot be undone.")
        }
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
    }
    
    private var header: some View {
        HomeBannerView(
            onScan: onScan,
            onPasteLink: onPasteLink,
            onTypeText: onTypeText
        )
    }

    // MARK: - Import & Listen Section
    private var importSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Import & listen")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.top, 20)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                // If pick file URL, call recentStore.add(fileURL: url, kind: .files)
                InputSourceTile(icon: "Text", title: "Type", action: { onTypeText?() })
                InputSourceTile(icon: "Camera", title: "Scan", action: { onScan?() })
                InputSourceTile(icon: "Photo", title: "Photo", tint: .yellow, action: { onPickPhotos?() })
                InputSourceTile(icon: "File", title: "Files", action: { onPickFiles?() })
                InputSourceTile(icon: "Link", title: "Link", action: { onPasteLink?() })

                InputSourceTile(icon: "GDrive", title: "GDrive", tint: .green, status: .comingSoon, action: { onPickGDrive?() })
                InputSourceTile(icon: "Dbox", title: "Dbox", tint: .blue, status: .comingSoon, action: { onPickDropbox?() })
                InputSourceTile(icon: "Book", title: "Book", status: .comingSoon, action: { onPickBook?() })
                
                
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .background(Color(hex: Color.secondaryBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.vertical, 0)
    }

    // MARK: - Recent Section
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activities")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.top, 20)

            if recentStore.items.isEmpty {
                VStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color(red: 0.12, green: 0.12, blue: 0.13))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "tray.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 48, height: 48)
                                .foregroundColor(Color.gray)
                        )
                        .padding(.top, 24)

                    Text("Add your first book to get started!")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.bottom, 28)
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 14) {
                    ForEach(recentStore.items) { item in
                        HStack(alignment: .center, spacing: 8) {
                            Button(action: { openRecentItem(item) }) {
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
                                    // Confirm delete via alert
                                    renamingItem = nil
                                    pendingDeleteItem = item
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
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 16)
            }
        }
        .background(Color(red: 0.10, green: 0.10, blue: 0.11))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 12)
    }
    
    // Unified open flow for recent items: stop previous TTS, prepare new file (paused), then delegate navigation
    private func openRecentItem(_ item: RecentActivity) {
        // Resolve URL if possible
        if let url = item.resolvedURL, url.isFileURL, FileManager.default.fileExists(atPath: url.path) {
            // Stop previous and prepare new file paused
            tts.stop()
            tts.prepareNewFileOnly(text: "", url: url, title: url.lastPathComponent)
            // Delegate navigation to the parent via callback (keeps routing consistent)
            onOpenRecent?(item)
        } else if let bm = item.bookmarkData {
            var isStale = false
            if let resolved = try? URL(resolvingBookmarkData: bm, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale),
               resolved.startAccessingSecurityScopedResource() {
                tts.stop()
                tts.prepareNewFileOnly(text: "", url: resolved, title: resolved.lastPathComponent)
                onOpenRecent?(item)
            } else {
                onOpenRecent?(item) // fallback: let parent handle if not resolvable
            }
        } else {
            onOpenRecent?(item)
        }
    }
}

#Preview {
    ZStack {
        Color(hex: "#1C1C1E").ignoresSafeArea()
        HomeView()
            .environmentObject(RecentStore())
    }
}
