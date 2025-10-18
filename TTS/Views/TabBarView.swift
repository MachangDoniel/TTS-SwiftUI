//
//  TabBarView.swift
//  TTS
//
//  Created by Doniel Tripura on 10/4/25.
//

import SwiftUI

struct TabBarView: View {
    
    @State private var selectedTab: Int = 2
    @State private var showCamera: Bool = false
    @State private var image: UIImage?
    @State private var showBottomSheet: Bool = false
    @State private var showDocumentPicker: Bool = false
    @State private var selectedDocumentURL: URL?
    
    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                
                // Camera Tab
                VStack {
                    if let img = image {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 300)
                            .cornerRadius(12)
                            .padding()
                    }
                }
                .tabItem { Label("Camera", systemImage: "camera.fill") }
                .tag(1)
                
                Spacer()
                
                // Add Tab
                VStack {
                    Text("Add")
                        .font(.largeTitle)
                        .padding()
                }
                .tabItem { Label("Add", systemImage: "plus.circle.fill") }
                .tag(2)
                
                Spacer()
                
                // Account Tab
                VStack {
                    Text("Account")
                        .font(.largeTitle)
                        .padding()
                }
                .tabItem { Label("Account", systemImage: "person.circle.fill") }
                .tag(3)
            }
            .padding([.leading, .trailing], 20)
            .onChange(of: selectedTab) { newValue in
                if newValue == 1 { showCamera = true }
                else if newValue == 2 { showBottomSheet = true }
            }
            // Camera
            .sheet(isPresented: $showCamera) {
                ImagePicker(sourceType: .camera) { img in
                    self.image = img
                }
            }
            // BottomSheet
            .sheet(isPresented: $showBottomSheet) {
                BottomSheet(showBottomSheet: $showBottomSheet) {
                    showDocumentPicker = true
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            // Document Picker -> Navigation to FileViewer
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker { url in
                    if let localURL = copyToLocal(url: url) {
                        selectedDocumentURL = localURL
                    }
                }
            }
            // NavigationLink for FileViewer
            .navigationDestination(isPresented: Binding(
                    get: { selectedDocumentURL != nil },
                    set: { if !$0 { selectedDocumentURL = nil } }
                )) {
                if let url = selectedDocumentURL {
                    FileViewer(fileURL: url)
                        .navigationTitle(url.lastPathComponent)
                        .navigationBarTitleDisplayMode(.inline)
                } else {
                    EmptyView()
                }
            }
        }
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
}


#Preview {
    TabBarView()
}

