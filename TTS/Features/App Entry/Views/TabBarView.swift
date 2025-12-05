//
//  TabBarView.swift
//  TTS
//
//  Created by Doniel Tripura on 10/4/25.
//

import SwiftUI

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct TabBarView: View {
    @State private var selectedTab: Int = 0
    @State private var didFirstAppear = false
    
    @State private var showDocumentPicker: Bool = false
    @State private var showTextInput = false
    @State private var showCameraReader = false
    @State private var showPhotoReader = false
    
    @State private var selectedDocumentURL: URL?
    @State private var selectedDocumentItem: IdentifiableURL? = nil
    @State private var webLinkItem: IdentifiableURL? = nil
    @State private var extractedTextFromWeb: String? = nil
    @State private var showLinkInput = false
    @State private var linkInputText = ""
    @State private var prefilledLinkText: String? = nil
    
    @StateObject private var recentStore = RecentStore()
    @EnvironmentObject var tts: TTSPlayer
    
    @State private var showBookmarkError = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(
                    onPickFiles: { showDocumentPicker = true },
                    onPickGDrive: { /* TODO */ },
                    onPickPhotos: { showPhotoReader = true },
                    onScan: { showCameraReader = true },
                    onPickDropbox: { /* TODO */ },
                    onPickBook: { /* TODO */ },
                    onTypeText: {
                        // Ensure a clean sheet when typing manually
                        prefilledLinkText = nil
                        showTextInput = true
                    },
                    onPasteLink: {
                        // Open a simple sheet or alert to enter link manually
                        linkInputText = ""
                        showLinkInput = true
                    },
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
                                        // Check TTS state: if stopped (idle/finished), stop it; if playing/paused, let it continue
                                        if tts.state == .idle || tts.state == .finished {
                                            tts.stop()
                                        }
                                        // If playing/paused, let it continue - FileViewer will handle preparation
                                        selectedDocumentURL = resolved
                                        selectedDocumentItem = IdentifiableURL(url: resolved)
                                        opened = true
                                        // Note: do not stopAccessing here; keep access while viewing
                                    }
                                } catch {
                                    Logger.log("Failed to resolve bookmark: \(error)")
                                }
                            }
                            if !opened {
                                if FileManager.default.fileExists(atPath: url.path) {
                                    // Check TTS state: if stopped (idle/finished), stop it; if playing/paused, let it continue
                                    if tts.state == .idle || tts.state == .finished {
                                        tts.stop()
                                    }
                                    // If playing/paused, let it continue - FileViewer will handle preparation
                                    selectedDocumentURL = url
                                    selectedDocumentItem = IdentifiableURL(url: url)
                                    opened = true
                                } else {
                                    Logger.log("Recent file missing at path: \(sp)")
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
                .environmentObject(recentStore)
            }
            .tabItem { Label("Home", systemImage: "house.fill") }
            .tag(0)
            
            Spacer()
            
            NavigationStack {
                LibraryView()
                    .environmentObject(recentStore)
                    .environmentObject(tts)
            }
            .tabItem { Label("Library", systemImage: "tray.fill") }
            .tag(1)

            Spacer()
            
            NavigationStack {
                ProfileView()
            }
            .tabItem { Label("Profile", systemImage: "person.crop.circle") }
            .tag(2)
        }
        .preferredColorScheme(.dark)
        .toolbarBackground(.automatic, for: .tabBar)
        .onAppear {
            if !didFirstAppear {
                didFirstAppear = true
            }
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
                        Logger.log("Failed to create bookmark: \(error)")
                        // Even if bookmark fails, still try to open immediately with active access
                        resolvedURL = url
                        showBookmarkError = true
                    }
                }
                // Navigate to the picked file immediately if available
                if let u = resolvedURL {
                    // Restart TTS for this new file and pause (no auto-start)
                    tts.stop()
                    tts.prepareNewFileOnly(text: "", url: u, title: u.lastPathComponent)
                    // Check TTS state: if stopped (idle/finished), stop it; if playing/paused, let it continue
                    if tts.state == .idle || tts.state == .finished {
                        tts.stop()
                    }
                    // If playing/paused, let it continue - FileViewer will handle preparation
                    selectedDocumentURL = u
                    selectedDocumentItem = IdentifiableURL(url: u)
                }
            }
        }
        .sheet(isPresented: $showTextInput) {
            TextInputView(
                tts: tts,
                prefilledText: prefilledLinkText ?? ""
            ) { url in
                do {
                    let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
                    recentStore.addExternal(fileURL: url, bookmarkData: bookmark, kind: .files)
                    Logger.log("[TabBarView] Added text file to recents with bookmark")
                } catch {
                    Logger.log("[TabBarView] Bookmark error (text): \(error.localizedDescription)")
                    // Fallback: still add without bookmark if it failed
                    recentStore.addExternal(fileURL: url, bookmarkData: Data(), kind: .files)
                    showBookmarkError = true
                }
                // Restart TTS for this new file and pause (no auto-start)
                tts.stop()
                tts.prepareNewFileOnly(text: "", url: url, title: url.lastPathComponent)
                // Check TTS state: if stopped (idle/finished), stop it; if playing/paused, let it continue
                if tts.state == .idle || tts.state == .finished {
                    tts.stop()
                }
                // If playing/paused, let it continue - FileViewer will handle preparation
                selectedTab = 0
                selectedDocumentURL = url
                selectedDocumentItem = IdentifiableURL(url: url)
            }
        }
        .sheet(isPresented: $showCameraReader) {
            ImageReaderView(tts: tts, source: .camera) { url in
                // Restart TTS for this new file and pause (no auto-start)
                tts.stop()
                tts.prepareNewFileOnly(text: "", url: url, title: url.lastPathComponent)
                do {
                    let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
                    recentStore.addExternal(fileURL: url, bookmarkData: bookmark, kind: .scan)
                } catch {
                    Logger.log("Bookmark error (scan): \(error.localizedDescription)")
                    // Fallback: still add without bookmark if it failed
                    recentStore.addExternal(fileURL: url, bookmarkData: Data(), kind: .scan)
                    showBookmarkError = true
                }
                // Open the saved image in FileViewer to unify the flow
                selectedDocumentURL = url
                selectedDocumentItem = IdentifiableURL(url: url)
            }
        }
        .sheet(isPresented: $showPhotoReader) {
            ImageReaderView(tts: tts, source: .gallery) { url in
                // Restart TTS for this new file and pause (no auto-start)
                tts.stop()
                tts.prepareNewFileOnly(text: "", url: url, title: url.lastPathComponent)
                do {
                    let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
                    recentStore.addExternal(fileURL: url, bookmarkData: bookmark, kind: .photos)
                } catch {
                    Logger.log("Bookmark error (photos): \(error.localizedDescription)")
                    // Fallback: still add without bookmark if it failed
                    recentStore.addExternal(fileURL: url, bookmarkData: Data(), kind: .photos)
                    showBookmarkError = true
                }
                // Open the saved image in FileViewer to unify the flow
                selectedDocumentURL = url
                selectedDocumentItem = IdentifiableURL(url: url)
            }
        }
        .sheet(item: $webLinkItem) { item in
            WebReaderView(url: item.url) { extractedText in
                DispatchQueue.main.async {
                    Logger.log("[TabBarView] Web extraction finished, opening TextInputView. Extracted length: \(extractedText.count)")
                    // Restart TTS and pause for the upcoming text input flow
                    tts.stop()
                    tts.prepareNewFileOnly(text: extractedText, url: nil, title: "Web Page")
                    prefilledLinkText = extractedText
                    showTextInput = true
                }
            }
            .environmentObject(tts)
        }
        .sheet(isPresented: $showLinkInput) {
            LinkInputView(isPresented: $showLinkInput, linkText: $linkInputText) { url in
                Logger.log("[TabBarView] Received link input: \(url.absoluteString)")
                // Restart and pause for new web content context
                tts.stop()
                tts.prepareNewFileOnly(text: "", url: url, title: url.absoluteString)
                DispatchQueue.main.async {
                    Logger.log("[TabBarView] Showing WebReaderView sheet")
                    webLinkItem = IdentifiableURL(url: url)
                }
            }
        }
        .alert("Could not save for recent files", isPresented: $showBookmarkError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The image will open now but may not load later from Recents.")
        }
        // Present FileViewer as fullScreenCover when a document is picked
        .fullScreenCover(item: $selectedDocumentItem) { item in
            AccessingFileViewer(url: item.url, tts: tts)
        }
        .overlay(alignment: .bottom) {
            if didFirstAppear, tts.hasActiveItem {
                MiniPlayerView(ttsPlayer: tts, title: tts.currentTitle ?? "Now Playing", onTap: {
                    if let url = tts.currentURL {
                        selectedTab = 0
                        selectedDocumentURL = url
                        selectedDocumentItem = IdentifiableURL(url: url)
                    } else if let url = selectedDocumentURL {
                        // Fallback: navigate to the last selected document
                        selectedTab = 0
                        selectedDocumentURL = url
                        selectedDocumentItem = IdentifiableURL(url: url)
                    } else {
                        Logger.log("Nothing to play or open")
                        // Optional: show a message to the user
                        // e.g., present an alert or haptic to indicate there's nothing to open
                    }
                })
                .padding(.bottom, 56) // keep above the tab bar (approx 49) + spacing
            }
        }
        .background(Color(hex: "#1C1C1E").ignoresSafeArea())
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
                Logger.log("Error copying file locally: \(error)")
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

