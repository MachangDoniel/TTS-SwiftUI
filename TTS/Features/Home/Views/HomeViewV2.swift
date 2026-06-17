//
//  HomeViewV2.swift
//  TTS
//
//  Created by Doniel Tripura on 6/17/26.
//

import SwiftUI
import UIKit
import Combine

struct HomeViewV2: View {
    var onPickFiles: (() -> Void)? = nil
    var onPickGDrive: (() -> Void)? = nil
    var onPickPhotos: (() -> Void)? = nil
    var onScan: (() -> Void)? = nil
    var onPickDropbox: (() -> Void)? = nil
    var onPickBook: (() -> Void)? = nil
    var onTypeText: (() -> Void)? = nil
    var onPasteLink: (() -> Void)? = nil
    var onTryForFree: (() -> Void)? = nil
    var onOpenRecent: ((RecentActivity) -> Void)? = nil
    var onSeeAllRecent: (() -> Void)? = nil

    @EnvironmentObject private var recentStore: RecentStore
    @EnvironmentObject private var tts: TTSPlayer

    @State private var renamingItem: RecentActivity? = nil
    @State private var newTitle: String = ""
    @State private var showDeleteConfirm: Bool = false
    @State private var pendingDeleteItem: RecentActivity? = nil
    @State private var heroSelection = 0

    private var heroSlides: [ModernHeroSlide] {
        [
            ModernHeroSlide(
                badge: "Premium",
                title: "Ultra-Realistic\nAI Voices",
                subtitle: "Listen with high-fidelity voices",
                description: "Unlock Pro Access",
                detail: "Priority processing and premium voices",
                ctaTitle: "Subscribe",
                accent: Color(hex: "#CEBDFF"),
                accentStrong: Color(hex: "#6F49D6"),
                glow: Color(hex: "#B699FF").opacity(0.32),
                onTap: onTryForFree
            ),
            ModernHeroSlide(
                badge: "Scan",
                title: "Read Anything\nOn the Fly",
                subtitle: "Capture documents and listen instantly",
                description: "Smart OCR",
                detail: "Turn photos and scans into editable text",
                ctaTitle: "Scan Now",
                accent: Color(hex: "#B9F7D2"),
                accentStrong: Color(hex: "#48B98A"),
                glow: Color(hex: "#66E1B0").opacity(0.22),
                onTap: onScan
            ),
            ModernHeroSlide(
                badge: "Import",
                title: "Start From\nAnywhere",
                subtitle: "Files, links, notes, and uploads all in one place",
                description: "Flexible input",
                detail: "Bring in text from every source you already use",
                ctaTitle: "Open Sources",
                accent: Color(hex: "#9BD3FF"),
                accentStrong: Color(hex: "#5E87FF"),
                glow: Color(hex: "#6EA4FF").opacity(0.24),
                onTap: onTypeText
            )
        ]
    }

    private var moreSources: [ModernActionItem] {
        [
            .init(title: "Files", subtitle: nil, symbol: "folder", style: .chip, action: onPickFiles),
            .init(title: "Link", subtitle: nil, symbol: "link", style: .chip, action: onPasteLink),
            .init(title: "GDrive", subtitle: nil, symbol: "externaldrive", style: .chip, action: onPickGDrive),
            .init(title: "Dbox", subtitle: nil, symbol: "shippingbox", style: .chip, action: onPickDropbox),
            .init(title: "Book", subtitle: nil, symbol: "books.vertical", style: .chip, action: onPickBook)
        ]
    }

    var body: some View {
        ZStack {
            backgroundLayer

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    heroSection
                    quickActionsSection
                    recentSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 0)
                .padding(.bottom, 20)
            }
        }
        .background(Color(hex: "#0D0E14").ignoresSafeArea())
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
}

private extension HomeViewV2 {
    var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "#12101A"),
                    Color(hex: "#0D0E14"),
                    Color(hex: "#09090B")
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [Color(hex: "#7B61FF").opacity(0.16), .clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 420
            )
            .blur(radius: 12)

            RadialGradient(
                colors: [Color(hex: "#2EE6A6").opacity(0.10), .clear],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 360
            )
            .blur(radius: 16)
        }
        .ignoresSafeArea()
    }

    var heroSection: some View {
        VStack(spacing: 8) {
            TabView(selection: $heroSelection) {
                ForEach(Array(heroSlides.enumerated()), id: \.offset) { index, slide in
                    ModernHeroSlideView(slide: slide)
                        .tag(index)
                        .padding(.bottom, 2)
                }
            }
            .frame(height: 282)
            .tabViewStyle(.page(indexDisplayMode: .never))
            .onReceive(Timer.publish(every: 4, on: .main, in: .common).autoconnect()) { _ in
                guard heroSlides.count > 1 else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    heroSelection = (heroSelection + 1) % heroSlides.count
                }
            }

            HStack(spacing: 8) {
                ForEach(heroSlides.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == heroSelection ? Color(hex: "#CEBDFF") : Color.white.opacity(0.18))
                        .frame(width: index == heroSelection ? 24 : 7, height: 7)
                        .animation(.easeInOut(duration: 0.2), value: heroSelection)
                }
            }
        }
    }

    var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    ModernActionTile(
                        item: .init(title: "Text Input", subtitle: "Start from scratch", symbol: "text.quote", style: .hero, action: onTypeText)
                    )
                    .gridCellColumns(2)

                    ModernActionTile(
                        item: .init(title: "PDF", subtitle: nil, symbol: "doc.richtext", style: .square, action: onPickFiles)
                    )
                }

                GridRow {
                    ModernActionTile(
                        item: .init(title: "Image", subtitle: nil, symbol: "photo", style: .square, action: onPickPhotos)
                    )
                    ModernActionTile(
                        item: .init(title: "eBook", subtitle: nil, symbol: "book", style: .square, action: onPickBook)
                    )
                    ModernActionTile(
                        item: .init(title: "Scan", subtitle: nil, symbol: "camera", style: .square, action: onScan)
                    )
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("More sources")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(moreSources) { item in
                        ModernChipAction(item: item)
                    }
                }
            }
        }
    }

    var recentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Recent History")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    onSeeAllRecent?()
                } label: {
                    Text("See all")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color(hex: "#BFAAFF"))
                }
                .buttonStyle(.plain)
                .disabled(onSeeAllRecent == nil)
                .opacity(onSeeAllRecent == nil ? 0.7 : 1.0)
            }

            if recentStore.items.isEmpty {
                ModernEmptyRecentState()
            } else {
                VStack(spacing: 12) {
                    ForEach(Array(recentStore.items.prefix(3))) { item in
                        ModernRecentCard(
                            item: item,
                            onOpen: { openRecentItem(item) },
                            onRename: {
                                renamingItem = item
                                newTitle = item.title
                            },
                            onDelete: {
                                pendingDeleteItem = item
                                showDeleteConfirm = true
                            }
                        )
                    }
                }
            }
        }
    }

    func openRecentItem(_ item: RecentActivity) {
        if let url = item.resolvedURL, url.isFileURL, FileManager.default.fileExists(atPath: url.path) {
            tts.stop()
            tts.prepareNewFileOnly(text: "", url: url, title: url.lastPathComponent)
            onOpenRecent?(item)
        } else if let bm = item.bookmarkData {
            var isStale = false
            if let resolved = try? URL(resolvingBookmarkData: bm, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale),
               resolved.startAccessingSecurityScopedResource() {
                tts.stop()
                tts.prepareNewFileOnly(text: "", url: resolved, title: resolved.lastPathComponent)
                onOpenRecent?(item)
            } else {
                onOpenRecent?(item)
            }
        } else {
            onOpenRecent?(item)
        }
    }
}

private struct ModernHeroSlide {
    let badge: String
    let title: String
    let subtitle: String
    let description: String
    let detail: String
    let ctaTitle: String
    let accent: Color
    let accentStrong: Color
    let glow: Color
    let onTap: (() -> Void)?
}

private struct ModernHeroSlideView: View {
    let slide: ModernHeroSlide

    var body: some View {
        Button {
            slide.onTap?()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(hex: "#12141D"))
                    .overlay(
                        LinearGradient(
                            colors: [
                                slide.accent.opacity(0.22),
                                Color.clear,
                                slide.accentStrong.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 14) {
                    Text(slide.badge.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.8)
                        .foregroundStyle(Color(hex: "#E4D8FF"))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(slide.accent.opacity(0.18))
                        .clipShape(Capsule())

                    Text(slide.title)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .lineSpacing(-4)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)

                    Text(slide.subtitle)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(.white.opacity(0.78))

                    Spacer(minLength: 0)

                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(slide.description)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                            Text(slide.detail)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(.white.opacity(0.75))
                                .lineLimit(2)
                        }

                        Spacer(minLength: 0)

                        Text(slide.ctaTitle)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color(hex: "#4A2EAA"))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "#E3D2FF"), Color(hex: "#B89CF8")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: slide.glow, radius: 18, x: 0, y: 10)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .padding(16)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .frame(height: 270)
    }
}

private struct ModernActionItem: Identifiable {
    enum Style {
        case hero
        case square
        case chip
    }

    let id = UUID()
    let title: String
    let subtitle: String?
    let symbol: String
    let style: Style
    let action: (() -> Void)?
}

private struct ModernActionTile: View {
    let item: ModernActionItem
    var spanningTwoColumns: Bool = false

    var body: some View {
        Button {
            item.action?()
        } label: {
            switch item.style {
            case .hero:
                heroBody
            case .square:
                squareBody
            case .chip:
                chipBody
            }
        }
        .buttonStyle(.plain)
        .disabled(item.action == nil)
        .opacity(item.action == nil ? 0.95 : 1.0)
    }

    private var heroBody: some View {
        HStack(alignment: .center, spacing: 16) {
            iconBubble(size: 52, fill: Color.white.opacity(0.12), stroke: Color.white.opacity(0.2), symbolColor: .white)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.title)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(item.subtitle ?? "")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color(hex: "#D5B9FF"), Color(hex: "#7F5AE0")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color(hex: "#7F5AE0").opacity(0.35), radius: 22, x: 0, y: 14)
    }

    private var squareBody: some View {
        VStack(spacing: 10) {
            iconBubble(size: 40, fill: Color.white.opacity(0.08), stroke: Color.white.opacity(0.06), symbolColor: .white.opacity(0.95))
            Text(item.title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, minHeight: 104)
        .padding(10)
        .background(Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var chipBody: some View {
        HStack(spacing: 10) {
            iconBubble(size: 28, fill: Color.white.opacity(0.10), stroke: Color.white.opacity(0.06), symbolColor: .white.opacity(0.95))
            Text(item.title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func iconBubble(size: CGFloat, fill: Color, stroke: Color, symbolColor: Color) -> some View {
        RoundedRectangle(cornerRadius: size / 2, style: .continuous)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: size / 2, style: .continuous)
                    .stroke(stroke, lineWidth: 1)
            )
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: item.symbol)
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(symbolColor)
            )
    }
}

private struct ModernChipAction: View {
    let item: ModernActionItem

    var body: some View {
        Button {
            item.action?()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(item.action == nil ? Color.white.opacity(0.45) : Color(hex: "#BFAAFF"))
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(item.action == nil)
    }
}

private struct ModernRecentCard: View {
    let item: RecentActivity
    let onOpen: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onOpen) {
                HStack(spacing: 14) {
                    iconBlock

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        Text(relativeTimeText)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.white.opacity(0.65))
                    }

                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .trailing, spacing: 10) {
                Text(durationText)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))

                HStack(spacing: 8) {
                    Button(action: onOpen) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Menu {
                        Button("Rename", systemImage: "pencil", action: onRename)
                        Button(role: .destructive, action: onDelete) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .rotationEffect(.degrees(90))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(0.05))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var iconBlock: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .frame(width: 46, height: 46)
            .overlay(iconView)
    }

    @ViewBuilder
    private var iconView: some View {
        if let data = item.thumbnailData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else {
            Image(systemName: iconName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white.opacity(0.78))
        }
    }

    private var iconName: String {
        switch item.kind {
        case .files: return "doc.text.fill"
        case .gdrive: return "externaldrive.fill"
        case .photos: return "photo.fill"
        case .scan: return "camera.fill"
        case .dbox: return "shippingbox.fill"
        case .book: return "book.fill"
        case .text: return "textformat"
        case .link: return "link"
        }
    }

    private var durationText: String {
        guard let wordCount = item.wordCount, wordCount > 0 else { return "00:00" }

        let totalSeconds = Int(0.4 * Double(wordCount))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var relativeTimeText: String {
        let interval = Date().timeIntervalSince(item.createdAt)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let mins = Int(interval / 60)
            return "\(mins) min ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        }
        let days = Int(interval / 86400)
        return "\(days) day\(days == 1 ? "" : "s") ago"
    }
}

private struct ModernEmptyRecentState: View {
    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .frame(width: 54, height: 54)
                .overlay(
                    Image(systemName: "tray.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("Add your first document to get started")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                Text("Files, scans, photos, and links will appear here.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.66))
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

#Preview {
    HomeViewV2()
        .environmentObject(RecentStore())
        .environmentObject(TTSPlayer())
        .preferredColorScheme(.dark)
}
