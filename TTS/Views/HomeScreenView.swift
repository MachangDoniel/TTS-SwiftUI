// HomeScreenView.swift
// TTS
//
// A home screen that matches the provided mock: gradient header, CTA, import grid, and recent activities.

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
        TabView {
            headerSlide
            headerSlide
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .never))
        .frame(height: 220)
    }

    private var headerSlide: some View {
        ZStack(alignment: .leading) {
            // Background stack: gradient + glow + sheen
            ZStack {
                // 1) Base gradient (multi-stop for smoother blend)
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(red: 0.38, green: 0.32, blue: 0.98), location: 0.0),
                        .init(color: Color(red: 0.33, green: 0.61, blue: 0.99), location: 1.0)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // 2) Soft radial glow toward the center-right
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.20),
                        Color.white.opacity(0.00)
                    ]),
                    center: .init(x: 0.75, y: 0.35),
                    startRadius: 10,
                    endRadius: 260
                )

                // 3) Subtle top sheen
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.10),
                        Color.white.opacity(0.00)
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.top, 0)
            .ignoresSafeArea(edges: .top)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Listen with the most\nadvanced AI Voices")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: { onTryForFree?() }) {
                        Text("Try for free")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                Spacer()
                Image(systemName: "book.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .foregroundColor(Color.white.opacity(0.9))
                    .padding(.top, 12)
                    .padding(.trailing, 24)
            }
            .padding(.horizontal, 32)
        }
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

private struct RecentRow: View {
    let item: RecentActivity
    let timeFormatter: DateFormatter

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.15, green: 0.15, blue: 0.16))
                .frame(width: 64, height: 64)
                .overlay(thumbnailOrIcon)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 14, design: .default))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(timeFormatter.string(from: item.createdAt))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer(minLength: 0)
        }
    }

    private var icon: some View {
        iconImage
            .resizable()
            .scaledToFit()
            .frame(width: 30, height: 30)
            .foregroundColor(Color.white.opacity(0.9))
    }

    private var thumbnailOrIcon: AnyView {
        if let data = item.thumbnailData, let uiImage = UIImage(data: data) {
            return AnyView(
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            )
        } else {
            return AnyView(icon)
        }
    }

    private var iconImage: Image {
        switch item.kind {
        case .files: return Image(systemName: "folder.fill")
        case .gdrive: return Image(systemName: "externaldrive.fill")
        case .photos: return Image(systemName: "photo.fill.on.rectangle.fill")
        case .scan: return Image(systemName: "camera.fill")
        case .dbox: return Image(systemName: "shippingbox.fill")
        case .book: return Image(systemName: "book.fill")
        case .text: return Image(systemName: "textformat")
        case .link: return Image(systemName: "link")
        }
    }
}

#Preview {
    ZStack { Color.black.ignoresSafeArea(); HomeScreenView() }
}

