//
//  DownloadManagementViews.swift
//  TTS
//
//  Created by Assistant on 11/23/25.
//

import SwiftUI

struct DownloadManagerView: View {
    @StateObject private var downloader = UniversalAudioDownloader()
    
    var body: some View {
        NavigationView {
            VStack {
                if downloader.isDownloading {
                    DownloadProgressSection(downloader: downloader)
                }
                
                DownloadedFilesSection(downloader: downloader)
                    .navigationTitle("Downloaded Audio")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Clean Up") {
                                Task {
                                    await downloader.cleanupOldCache()
                                }
                            }
                        }
                    }
            }
        }
    }
}

struct DownloadProgressSection: View {
    @ObservedObject var downloader: UniversalAudioDownloader
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Downloading...")
                    .font(.headline)
                Spacer()
                Text("\(Int(downloader.downloadProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: downloader.downloadProgress)
                .progressViewStyle(LinearProgressViewStyle())
            
            Text("\(downloader.downloadQueue.count) items in queue")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

struct DownloadedFilesSection: View {
    @ObservedObject var downloader: UniversalAudioDownloader
    
    var body: some View {
        List {
            ForEach(downloader.downloadedFiles) { file in
                DownloadedFileRow(file: file, downloader: downloader)
            }
            .onDelete(perform: deleteFiles)
        }
    }
    
    private func deleteFiles(at offsets: IndexSet) {
        for index in offsets {
            let file = downloader.downloadedFiles[index]
            downloader.deleteAudioFile(file)
        }
    }
}

struct DownloadedFileRow: View {
    let file: AudioFile
    @ObservedObject var downloader: UniversalAudioDownloader
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: file.fileType.icon)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text(file.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text("\(file.fileType.displayName) • \(formatFileSize(file.fileSize)) • \(formatDuration(file.duration))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(formatDate(file.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Delete", role: .destructive) {
                downloader.deleteAudioFile(file)
            }
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}