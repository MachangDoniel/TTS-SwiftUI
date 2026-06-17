//
//  LibraryViewV2.swift
//  TTS
//
//  Created by Doniel Tripura on 6/17/26.
//

import SwiftUI

private struct LibraryDocumentItemV2: Identifiable {
    let id = UUID()
    let url: URL
}

struct LibraryViewV2: View {
    @EnvironmentObject private var recentStore: RecentStore
    @EnvironmentObject private var tts: TTSPlayer

    @State private var selectedFilter: FileCategory = .all
    @State private var selectedDocumentURL: URL? = nil
    @State private var selectedDocumentItem: LibraryDocumentItemV2? = nil
    @State private var actionItem: RecentActivity? = nil
    @State private var showDeleteConfirm: Bool = false
    @State private var renamingItem: RecentActivity? = nil
    @State private var newTitle: String = ""
    @State private var isSearchVisible = false
    @State private var searchText = ""

    private var deleteAlertTitle: String {
        let name = actionItem?.title ?? "this item"
        return "Are you sure to delete \(name)?"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background

                VStack(spacing: 18) {
                    header
                    filterRow

                    if groupedSections.isEmpty {
                        EmptyLibraryView()
                            .padding(.top, 36)
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 28) {
                                ForEach(groupedSections) { section in
                                    historySection(section)
                                }

                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                            .padding(.bottom, 24)
                        }
                    }
                }
                .padding(.top, 8)
            }
            .navigationBarHidden(true)
            .fullScreenCover(item: $selectedDocumentItem) { item in
                FileViewer(fileURL: item.url, tts: tts)
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
    }
}

private extension LibraryViewV2 {
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
            Text(isSearchVisible ? "Search" : "History")
                .font(.system(size: 30, weight: .regular, design: .rounded))
                .foregroundStyle(.white)

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
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(FileCategory.allCases, id: \.self) { category in
                    filterPill(title: category.displayName, selected: selectedFilter == category) {
                        selectedFilter = category
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 2)
    }

    func filterPill(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(selected ? .white : .white.opacity(0.7))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(selected ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .stroke(selected ? Color.white.opacity(0.12) : Color.white.opacity(0.05), lineWidth: 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    func historySection(_ section: HistorySection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title.uppercased())
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.62))
                .padding(.horizontal, 4)

            VStack(spacing: 14) {
                ForEach(section.items) { item in
                    historyCard(item)
                }
            }
        }
    }

    func historyCard(_ item: RecentActivity) -> some View {
        Button {
            openRecentItem(item)
        } label: {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 14) {
                    iconBubble(for: item)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.title)
                            .font(.system(size: 19, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        HStack(spacing: 12) {
                            metaPill(system: item.kind.systemIcon, text: item.kind.title)
                            metaPill(system: "clock", text: durationText(for: item))
                        }

                        HStack(spacing: 12) {
                            metaPill(system: "circle.fill", text: timeText(for: item), isFilled: true)
                            metaPill(system: "globe", text: languageText(for: item))
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.bottom, 14)

                Divider()
                    .overlay(Color.white.opacity(0.14))
                    .padding(.bottom, 12)

                HStack(spacing: 14) {
                    progressBar(for: item)

                    Button {
                        openRecentItem(item)
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

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
                        Image(systemName: "arrow.down.to.line")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 40, height: 40)
                    }
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    func iconBubble(for item: RecentActivity) -> some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .frame(width: 54, height: 54)
            .overlay(
                Image(systemName: item.kind.systemIcon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
            )
    }

    func metaPill(system: String, text: String, isFilled: Bool = false) -> some View {
        HStack(spacing: 6) {
            if system == "circle.fill" {
                Circle()
                    .fill(Color.white.opacity(0.45))
                    .frame(width: 7, height: 7)
            } else {
                Image(systemName: system)
                    .font(.system(size: 11, weight: .semibold))
            }

            Text(text)
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white.opacity(0.72))
    }

    func progressBar(for item: RecentActivity) -> some View {
        let words = max(item.wordCount ?? 0, 1)
        let progress = min(0.95, max(0.12, Double(words % 7 + 1) / 8.0))
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 6)
                Capsule()
                    .fill(Color(hex: "#CEBDFF"))
                    .frame(width: max(8, geo.size.width * progress), height: 6)
            }
        }
        .frame(height: 6)
    }

    func openRecentItem(_ item: RecentActivity) {
        if let bm = item.bookmarkData {
            var isStale = false
            if let resolved = try? URL(resolvingBookmarkData: bm, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale),
               resolved.startAccessingSecurityScopedResource() {
                open(url: resolved)
                return
            }
        }

        if let url = item.resolvedURL, url.isFileURL, FileManager.default.fileExists(atPath: url.path) {
            open(url: url)
            return
        }

        Logger.log("Unable to resolve local file for: \(item.title)")
    }

    func open(url: URL) {
        tts.stop()
        tts.prepareNewFileOnly(text: "", url: url, title: url.lastPathComponent)
        selectedDocumentURL = url
        selectedDocumentItem = LibraryDocumentItemV2(url: url)
    }

    func durationText(for item: RecentActivity) -> String {
        let totalSeconds = Int(Double(item.wordCount ?? 0) * 0.4)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func timeText(for item: RecentActivity) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let calendar = Calendar.current
        if calendar.isDateInToday(item.createdAt) {
            return formatter.string(from: item.createdAt)
        }
        if calendar.isDateInYesterday(item.createdAt) {
            return "Yesterday"
        }
        formatter.dateStyle = .medium
        return formatter.string(from: item.createdAt)
    }

    func languageText(for item: RecentActivity) -> String {
        switch item.kind {
        case .photos: return "Image"
        case .scan: return "Scan"
        case .link: return "Link"
        case .book: return "Book"
        case .dbox: return "Dropbox"
        case .gdrive: return "Drive"
        case .files: return "Files"
        case .text: return "Text"
        }
    }

    var groupedSections: [HistorySection] {
        let filtered = recentStore.items
            .filter(matchesSearch)
            .filter(matchesCategory)
            .sorted { $0.createdAt > $1.createdAt }

        let grouped = Dictionary(grouping: filtered) { item -> String in
            if Calendar.current.isDateInToday(item.createdAt) { return "Today" }
            if Calendar.current.isDateInYesterday(item.createdAt) { return "Yesterday" }
            return "Older"
        }

        let order = ["Today", "Yesterday", "Older"]
        return order.compactMap { key in
            guard let items = grouped[key], !items.isEmpty else { return nil }
            return HistorySection(title: key, items: items)
        }
    }

    func matchesCategory(_ item: RecentActivity) -> Bool {
        switch selectedFilter {
        case .all: return true
        case .pdf: return item.fileExtension.isPDF
        case .text: return item.fileExtension.isText
        case .image: return item.fileExtension.isImage
        }
    }

    func matchesSearch(_ item: RecentActivity) -> Bool {
        guard isSearchVisible, !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return true }
        return item.title.localizedCaseInsensitiveContains(searchText) ||
        (item.sourcePath?.localizedCaseInsensitiveContains(searchText) ?? false)
    }
}

private struct HistorySection: Identifiable {
    let title: String
    let items: [RecentActivity]

    var id: String { title }
}

private extension FileCategory {
    var displayName: String {
        switch self {
        case .all: return "All"
        case .pdf: return "PDF"
        case .text: return "Text"
        case .image: return "Image"
        }
    }
}

#Preview {
    LibraryViewV2()
        .environmentObject(RecentStore())
        .environmentObject(TTSPlayer())
        .preferredColorScheme(.dark)
}
