//
//  FileViewerView.swift
//  TTS
//
//  Created by Doniel Tripura on 10/19/25.
//

import SwiftUI


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
