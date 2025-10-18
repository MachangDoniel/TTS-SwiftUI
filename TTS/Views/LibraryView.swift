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
                                                        print("Unable to resolve local file for: \(item.title)")
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

// MARK: - Filter Enum
enum FileFilter: String, CaseIterable {
    case all = "All Files"
    case pdf = "PDF"
    case text = "Text"
    case image = "Image"
}

// MARK: - Filter Bar
struct FilterBar: View {
    @Binding var selected: FileFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(FileFilter.allCases, id: \.self) { filter in
                    Button {
                        selected = filter
                    } label: {
                        Text(filter.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 14)
                            .background(
                                selected == filter ?
                                Color.blue.opacity(0.9) :
                                Color.white.opacity(0.1)
                            )
                            .clipShape(Capsule())
                            .foregroundColor(selected == filter ? .white : .white.opacity(0.8))
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

// MARK: - Empty State View
struct EmptyLibraryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)
            Image(systemName: "tray.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 90, height: 90)
                .foregroundColor(.gray.opacity(0.7))
                .padding(.bottom, 10)

            Text("Add your first book to get started!")
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .medium))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - File Viewer
struct FileViewerView: View {
    let item: RecentActivity

    private func displayName(from item: RecentActivity) -> String {
        if let nameChild = Mirror(reflecting: item).children.first(where: { $0.label == "fileName" }),
           let name = nameChild.value as? String {
            return name
        }
        if let urlChild = Mirror(reflecting: item).children.first(where: { $0.label == "url" }),
           let url = urlChild.value as? URL {
            return url.lastPathComponent
        }
        if let pathChild = Mirror(reflecting: item).children.first(where: { $0.label == "path" }),
           let path = pathChild.value as? String {
            return URL(fileURLWithPath: path).lastPathComponent
        }
        return "File"
    }

    private func fileURL(from item: RecentActivity) -> URL? {
        let mirror = Mirror(reflecting: item)

        // Try URL-typed properties first
        if let urlChild = mirror.children.first(where: { $0.label == "url" }),
           let url = urlChild.value as? URL {
            return url
        }
        if let fileURLChild = mirror.children.first(where: { $0.label == "fileURL" || $0.label == "localURL" }),
           let url = fileURLChild.value as? URL {
            return url
        }

        // Try path-typed properties next
        if let pathChild = mirror.children.first(where: { $0.label == "path" || $0.label == "filePath" }),
           let path = pathChild.value as? String {
            return URL(fileURLWithPath: path)
        }

        return nil
    }

    private func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    var body: some View {
        VStack(spacing: 16) {
            if let url = fileURL(from: item) {
                // Placeholder viewer; integrate your real viewer here
                Text("Viewing: \(url.lastPathComponent)")
                    .foregroundColor(.white)
                Text(url.path)
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding()
                Text(fileExists(at: url) ? "File exists on disk" : "File not found on disk")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.6))
            } else {
                Text("Unable to open file")
                    .foregroundColor(.white)
            }
            Spacer()
        }
        .navigationTitle(displayName(from: item))
        .navigationBarTitleDisplayMode(.inline)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
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

