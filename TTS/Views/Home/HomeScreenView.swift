//
//  HomeScreenView.swift
//  TTS
//
//  Created by Doniel Tripura on 10/19/25.
//

import SwiftUI
import UIKit

struct HomeScreenView: View {
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
    
    @State private var renamingItem: RecentActivity? = nil
    @State private var newTitle: String = ""
    
    private let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df
    }()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea() // base dark background
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    header
                    importSection
                    recentSection
                }
                .padding(.bottom, 32)
            }
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

    // MARK: - Header
    private var header: some View {
        HeaderPager(onTryForFree: onTryForFree)
            .frame(height: 160)
            .padding(.top, 8)
    }

    // MARK: - Import & Listen Section
    private var importSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Import & listen")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.top, 20)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 16) {
                // If you have a picked file URL, call recentStore.add(fileURL: url, kind: .files)
                ImportTile(icon: "File", title: "Files", action: { onPickFiles?() })
                ImportTile(icon: "GDrive", title: "GDrive", tint: .green, action: { onPickGDrive?() })
                ImportTile(icon: "photo.fill.on.rectangle.fill", title: "Photo", tint: .yellow, action: { onPickPhotos?() })
                ImportTile(icon: "Camera", title: "Scan", action: { onScan?() })
                ImportTile(icon: "Dbox", title: "Dbox", tint: .blue, action: { onPickDropbox?() })
                ImportTile(icon: "Book", title: "Book", action: { onPickBook?() })
                ImportTile(icon: "Text", title: "Type", action: { onTypeText?() })
                ImportTile(icon: "Link", title: "Link", action: { onPasteLink?() })
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color(red: 0.10, green: 0.10, blue: 0.11))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 16)
    }

    // MARK: - Recent Section
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activities")
                .font(.system(size: 18, weight: .semibold))
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
                        Button(action: { onOpenRecent?(item) }) {
                            RecentRow(item: item, timeFormatter: timeFormatter)
                        }
                        .padding(.horizontal, 20)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                recentStore.deleteItem(id: item.id, removeFile: false)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                renamingItem = item
                                newTitle = item.title
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                    .padding(.bottom, 16)
                }
            }
        }
        .background(Color(red: 0.10, green: 0.10, blue: 0.11))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 16)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        HomeScreenView()
            .environmentObject(RecentStore())
    }
}
