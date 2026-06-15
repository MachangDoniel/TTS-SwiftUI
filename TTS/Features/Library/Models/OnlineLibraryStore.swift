//
//  OnlineLibraryStore.swift
//  TTS
//
//  Created by Assistant on 6/15/26.
//

import Foundation
import Combine

@MainActor
final class OnlineLibraryStore: ObservableObject {
    static let shared = OnlineLibraryStore()

    @Published private(set) var items: [OnlineLibraryItem] = []

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let storeURL: URL

    private init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        self.storeURL = documentsURL.appendingPathComponent("OnlineLibraryStore.json")

        load()
    }

    func save(item: OnlineLibraryItem) {
        let normalizedItem = item.normalizedForPersistence(fileManager: fileManager)

        if let index = items.firstIndex(where: { $0.requestId == normalizedItem.requestId }) {
            items[index] = normalizedItem
        } else {
            items.insert(normalizedItem, at: 0)
        }

        items.sort { $0.createdAt > $1.createdAt }
        persist()
    }

    func delete(requestId: String) {
        items.removeAll { $0.requestId == requestId }
        persist()
    }

    var projects: [OnlineLibraryProject] {
        let grouped = Dictionary(grouping: items, by: \.projectKey)

        return grouped.values.compactMap { projectItems in
            guard let first = projectItems.first else { return nil }
            return OnlineLibraryProject(
                projectKey: first.projectKey,
                projectTitle: first.projectTitle,
                originalSourceURL: first.originalSourceURL,
                originalSourceExtension: first.originalSourceExtension,
                items: projectItems.sorted { $0.createdAt > $1.createdAt }
            )
        }
        .sorted { $0.items.first?.createdAt ?? .distantPast > $1.items.first?.createdAt ?? .distantPast }
    }

    private func load() {
        guard fileManager.fileExists(atPath: storeURL.path) else {
            items = []
            return
        }

        do {
            let data = try Data(contentsOf: storeURL)
            items = try decoder.decode([OnlineLibraryItem].self, from: data)
                .map { $0.normalizedForPersistence(fileManager: fileManager) }
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            Logger.log("❌ Failed loading online library items: \(error.localizedDescription)")
            items = []
        }
    }

    private func persist() {
        do {
            let data = try encoder.encode(items)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            Logger.log("❌ Failed saving online library items: \(error.localizedDescription)")
        }
    }
}
