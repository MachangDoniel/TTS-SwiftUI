//
//  TabBarView.swift
//  TTS
//
//  Created by Doniel Tripura on 10/4/25.
//

import SwiftUI

struct TabBarView: View {
    @State private var selectedTab: Int = 0
    
    @State private var showDocumentPicker: Bool = false
    @State private var showTextInput = false
    @State private var showCameraReader = false
    @State private var showPhotoReader = false
    
    @State private var selectedDocumentURL: URL?
    @StateObject private var recentStore = RecentStore()
    @StateObject private var tts = TTSPlayer()

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                // Home Tab
                HomeView(
                    onPickFiles: { showDocumentPicker = true },
                    onPickGDrive: { /* TODO */ },
                    onPickPhotos: { showPhotoReader = true },
                    onScan: { showCameraReader = true },
                    onPickDropbox: { /* TODO */ },
                    onPickBook: { /* TODO */ },
                    onTypeText: { showTextInput = true },
                    onPasteLink: { /* TODO */ },
                    onTryForFree: { /* TODO */ },
                    onOpenRecent: { item in
                        if let sp = item.sourcePath, !sp.isEmpty,
                           item.kind == .files || item.kind == .book || item.kind == .photos || item.kind == .scan || item.kind == .dbox {
                            let url = URL(fileURLWithPath: sp)
                            var opened = false
                            // Try resolving bookmark first (if available)
                            if let rec = recentStore.items.first(where: { $0.sourcePath == sp && $0.kind == item.kind }), let bm = rec.bookmarkData {
                                var isStale = false
                                do {
                                    let resolved = try URL(resolvingBookmarkData: bm, options: [], relativeTo: nil, bookmarkDataIsStale: &isStale)
                                    if resolved.startAccessingSecurityScopedResource() {
                                        // Stop any ongoing TTS to ensure clean refresh
                                        tts.stop()
                                        selectedDocumentURL = resolved
                                        opened = true
                                        // Note: do not stopAccessing here; keep access while viewing
                                    }
                                } catch {
                                    print("Failed to resolve bookmark: \(error)")
                                }
                            }
                            if !opened {
                                if FileManager.default.fileExists(atPath: url.path) {
                                    // Stop any ongoing TTS to ensure clean refresh
                                    tts.stop()
                                    selectedDocumentURL = url
                                    opened = true
                                } else {
                                    print("Recent file missing at path: \(sp)")
                                }
                            }
                        } else if item.kind == .link,
                                  let sp = item.sourcePath, let url = URL(string: sp) {
                            // TODO: Optionally open URL externally
                            // UIApplication.shared.open(url)
                        } else {
                            // TODO: Handle text or cloud sources
                        }
                    }
                )
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)
                .environmentObject(recentStore)
                
                Spacer()

                // Library Tab
                LibraryView()
                    .tabItem { Label("Library", systemImage: "tray.fill") }
                    .tag(1)
                    .environmentObject(recentStore)
                    .environmentObject(tts)
                
                Spacer()

                // Profile Tab (placeholder)
                ProfileView()
                    .preferredColorScheme(.dark)
                    .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                    .tag(2)
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker { url in
                    var resolvedURL: URL? = nil
                    if url.startAccessingSecurityScopedResource() {
                        do {
                            let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
                            // Store recent using bookmark (no full copy)
                            recentStore.addExternal(fileURL: url, bookmarkData: bookmark, kind: .files)
                            resolvedURL = url
                        } catch {
                            print("Failed to create bookmark: \(error)")
                            // Even if bookmark fails, still try to open immediately with active access
                            resolvedURL = url
                        }
                    }
                    // Navigate to the picked file immediately if available
                    if let u = resolvedURL {
                        // Stop any ongoing TTS and reset state before opening a new file
                        tts.stop()
                        selectedDocumentURL = u
                    }
                }
            }
            .sheet(isPresented: $showTextInput) {
                TextInputView(tts: tts) { url in
                    // Add to recent and open file
                    do {
                        let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
                        recentStore.addExternal(fileURL: url, bookmarkData: bookmark, kind: .files)
                    } catch {
                        print("Bookmark error:", error.localizedDescription)
                        // Fallback: still add without bookmark if it failed
                        recentStore.addExternal(fileURL: url, bookmarkData: Data(), kind: .files)
                    }
                    // Stop any ongoing speech and open the new text file
                    tts.stop()
                    selectedTab = 0
                    selectedDocumentURL = url
                }
            }
            .sheet(isPresented: $showCameraReader) {
                ImageReaderView(tts: tts, source: .camera) { url in
                    do {
                        let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
                        recentStore.addExternal(fileURL: url, bookmarkData: bookmark, kind: .scan)
                    } catch {
                        print("Bookmark error (scan):", error.localizedDescription)
                        // Fallback: still add without bookmark if it failed
                        recentStore.addExternal(fileURL: url, bookmarkData: Data(), kind: .scan)
                    }
                }
            }
            .sheet(isPresented: $showPhotoReader) {
                ImageReaderView(tts: tts, source: .gallery) { url in
                    do {
                        let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
                        recentStore.addExternal(fileURL: url, bookmarkData: bookmark, kind: .photos)
                    } catch {
                        print("Bookmark error (photos):", error.localizedDescription)
                        // Fallback: still add without bookmark if it failed
                        recentStore.addExternal(fileURL: url, bookmarkData: Data(), kind: .photos)
                    }
                }
            }
            
            // Navigation to FileViewer when a document is picked
            .navigationDestination(isPresented: Binding(
                get: { selectedDocumentURL != nil },
                set: { if !$0 { selectedDocumentURL = nil } }
            )) {
                if let url = selectedDocumentURL {
                    AccessingFileViewer(url: url, tts: tts)
                        .navigationTitle(url.lastPathComponent)
                        .navigationBarTitleDisplayMode(.inline)
                } else {
                    EmptyView()
                }
            }
            .overlay(alignment: .bottom) {
                if tts.hasActiveItem {
                    MiniTTSControlView(ttsPlayer: tts, title: tts.currentTitle ?? "Now Playing", onTap: {
                        if let url = tts.currentURL {
                            selectedTab = 0
                            selectedDocumentURL = url
                        } else if let url = selectedDocumentURL {
                            // Fallback: navigate to the last selected document
                            selectedTab = 0
                            selectedDocumentURL = url
                        } else {
                            debugPrint("Nothing to play or open")
                            // Optional: show a message to the user
                            // e.g., present an alert or haptic to indicate there's nothing to open
                        }
                    })
                    .padding(.bottom, 56) // keep above the tab bar (approx 49) + spacing
                }
            }
        }
        .background(Color(.black))
    }

    func copyToLocal(url: URL) -> URL? {
        var localURL: URL? = nil
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            let fileName = url.lastPathComponent
            let tempDir = FileManager.default.temporaryDirectory
            let destinationURL = tempDir.appendingPathComponent(fileName)
            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(at: url, to: destinationURL)
                localURL = destinationURL
            } catch {
                print("Error copying file locally: \(error)")
            }
        }
        return localURL
    }

    // Helper that ensures security-scoped access while viewing the file
    private struct AccessingFileViewer: View {
        let url: URL
        let tts: TTSPlayer
        @State private var didStartAccess = false

        var body: some View {
            FileViewer(fileURL: url, tts: tts)
                .onAppear {
                    // Ensure we have access when presented from Files app
                    if !didStartAccess {
                        if url.startAccessingSecurityScopedResource() {
                            didStartAccess = true
                        }
                    }
                }
                .onDisappear {
                    // Release access when leaving the viewer
                    if didStartAccess {
                        url.stopAccessingSecurityScopedResource()
                        didStartAccess = false
                    }
                }
        }
    }
}

#Preview {
    TabBarView()
}
