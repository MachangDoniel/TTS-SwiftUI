// RecentActivity.swift
// Local model + store for recent activities

import Foundation
import SwiftUI
import Combine
import CoreData
import PDFKit
import UIKit

// MARK: - Model
struct RecentActivity: Identifiable, Codable, Equatable {
    enum Kind: String, Codable, CaseIterable {
        case files, gdrive, photos, scan, dbox, book, text, link

        var displayName: String {
            switch self {
            case .files: return "Files"
            case .gdrive: return "GDrive"
            case .photos: return "Photo"
            case .scan: return "Scan"
            case .dbox: return "Dbox"
            case .book: return "Book"
            case .text: return "Type"
            case .link: return "Link"
            }
        }
    }

    let id: UUID
    var title: String // already sanitized for display
    var sourcePath: String?
    var kind: Kind
    var createdAt: Date
    var thumbnailData: Data? // optional small preview (e.g., PDF first page)
    var bookmarkData: Data? // security-scoped bookmark for external files

    // Derived file extension and category, based on sourcePath or title
    var fileExtensionLowercased: String? {
        // Prefer sourcePath if available
        if let sp = sourcePath, !sp.isEmpty {
            // Try to parse as URL first
            if let url = URL(string: sp), url.scheme != nil {
                let ext = url.pathExtension
                if !ext.isEmpty { return ext.lowercased() }
            }
            // Fall back to path string
            if let ext = sp.split(separator: ".").last, sp.contains(".") {
                return String(ext).lowercased()
            }
        }
        // Fallback: try to infer from title if it contains an extension
        if let ext = title.split(separator: ".").last, title.contains(".") {
            return String(ext).lowercased()
        }
        return nil
    }

    enum FileCategory {
        case pdf
        case text
        case image
        case other
    }

    var fileCategory: FileCategory {
        if kind == .text { return .text }
        if kind == .photos { return .image }
        guard let ext = fileExtensionLowercased else { return .other }
        if ext == "pdf" { return .pdf }
        if ext == "txt" { return .text }
        if ["png", "jpg", "jpeg", "heic"].contains(ext) { return .image }
        return .other
    }

    init(id: UUID = UUID(), title: String, sourcePath: String? = nil, kind: Kind, createdAt: Date = Date(), thumbnailData: Data? = nil, bookmarkData: Data? = nil) {
        self.id = id
        self.title = title
        self.sourcePath = sourcePath
        self.kind = kind
        self.createdAt = createdAt
        self.thumbnailData = thumbnailData
        self.bookmarkData = bookmarkData
    }

    // Resolve a usable URL for this activity, preferring security-scoped bookmarks
    var resolvedURL: URL? {
        // 1) Try bookmark if available (for external files)
        if let bookmarkData {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmarkData,
                                  options: [.withoutUI],
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &isStale) {
                return url
            }
        }

        // 2) Fall back to sourcePath
        guard let sp = sourcePath, !sp.isEmpty else { return nil }

        // If it's a proper URL string (has a scheme), use it
        if let url = URL(string: sp), url.scheme != nil {
            return url
        }

        // Otherwise treat it as a local file path
        return URL(fileURLWithPath: sp)
    }

    // Convenience for checking disk existence when resolvedURL is file URL
    var fileExistsOnDisk: Bool {
        guard let url = resolvedURL, url.isFileURL else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }
}

// MARK: - Store (Core Data persistence)
final class RecentStore: ObservableObject {
    @Published private(set) var items: [RecentActivity] = []

    private let maxItems = 50

    // MARK: - Core Data stack (programmatic model)
    private let container: NSPersistentContainer
    private let context: NSManagedObjectContext

    init() {
        let model = Self.buildModel()
        container = NSPersistentContainer(name: "RecentModel", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        let storeURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("RecentModel.sqlite")
        description.url = storeURL
        description.type = NSSQLiteStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let err = loadError {
            assertionFailure("Failed to load Core Data store: \(err)")
        }
        context = container.viewContext
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        load()
    }

    private static func buildModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // Entity: RecentActivityEntity
        let entity = NSEntityDescription()
        entity.name = "RecentActivityEntity"
        entity.managedObjectClassName = "NSManagedObject"

        // Attributes
        let idAttr = NSAttributeDescription()
        idAttr.name = "id"
        idAttr.attributeType = .UUIDAttributeType
        idAttr.isOptional = false

        let titleAttr = NSAttributeDescription()
        titleAttr.name = "title"
        titleAttr.attributeType = .stringAttributeType
        titleAttr.isOptional = false

        let sourcePathAttr = NSAttributeDescription()
        sourcePathAttr.name = "sourcePath"
        sourcePathAttr.attributeType = .stringAttributeType
        sourcePathAttr.isOptional = true

        let kindAttr = NSAttributeDescription()
        kindAttr.name = "kind"
        kindAttr.attributeType = .stringAttributeType
        kindAttr.isOptional = false

        let createdAtAttr = NSAttributeDescription()
        createdAtAttr.name = "createdAt"
        createdAtAttr.attributeType = .dateAttributeType
        createdAtAttr.isOptional = false

        let thumbAttr = NSAttributeDescription()
        thumbAttr.name = "thumbnailData"
        thumbAttr.attributeType = .binaryDataAttributeType
        thumbAttr.isOptional = true

        let bookmarkAttr = NSAttributeDescription()
        bookmarkAttr.name = "bookmarkData"
        bookmarkAttr.attributeType = .binaryDataAttributeType
        bookmarkAttr.isOptional = true

        entity.properties = [idAttr, titleAttr, sourcePathAttr, kindAttr, createdAtAttr, thumbAttr, bookmarkAttr]

        // No uniqueness constraints; we'll dedupe manually for flexible logic
        model.entities = [entity]
        return model
    }

    // MARK: - Public API (unchanged)

    func add(title: String, kind: RecentActivity.Kind) {
        let display = sanitizeTitle(title)
        let activity = RecentActivity(title: display, kind: kind)
        dedupAndInsert(activity)
    }

    func add(fileURL: URL, kind: RecentActivity.Kind) {
        let base = fileURL.deletingPathExtension().lastPathComponent
        let display = sanitizeTitle(base)
        var thumb: Data? = nil
        if fileURL.pathExtension.lowercased() == "pdf", let doc = PDFDocument(url: fileURL), let page = doc.page(at: 0) {
            let size = CGSize(width: 64, height: 64)
            let img = page.thumbnail(of: size, for: .cropBox)
            thumb = img.pngData()
        }
        let activity = RecentActivity(title: display,
                                      sourcePath: fileURL.isFileURL ? fileURL.path : fileURL.absoluteString,
                                      kind: kind,
                                      thumbnailData: thumb)
        dedupAndInsert(activity)
    }

    func addExternal(fileURL: URL, bookmarkData: Data, kind: RecentActivity.Kind) {
        let base = fileURL.deletingPathExtension().lastPathComponent
        let display = sanitizeTitle(base)
        var thumb: Data? = nil
        if fileURL.pathExtension.lowercased() == "pdf", let doc = PDFDocument(url: fileURL), let page = doc.page(at: 0) {
            let size = CGSize(width: 64, height: 64)
            let img = page.thumbnail(of: size, for: .cropBox)
            thumb = img.pngData()
        }
        let activity = RecentActivity(title: display,
                                      sourcePath: fileURL.isFileURL ? fileURL.path : fileURL.absoluteString,
                                      kind: kind,
                                      thumbnailData: thumb,
                                      bookmarkData: bookmarkData)
        dedupAndInsert(activity)
    }

    func addLink(url: URL, title: String? = nil) {
        let displayTitle: String
        if let title = title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            displayTitle = sanitizeTitle(title)
        } else {
            let host = url.host ?? "Link"
            let path = url.path.isEmpty ? "" : url.path
            let raw = path.isEmpty ? host : host + path
            displayTitle = sanitizeTitle(raw)
        }
        let activity = RecentActivity(title: displayTitle, sourcePath: url.absoluteString, kind: .link)
        dedupAndInsert(activity)
    }

    func addText(content: String) {
        let firstLine = content.split(separator: "\n").first.map(String.init) ?? content
        let display = sanitizeTitle(firstLine)
        let activity = RecentActivity(title: display, kind: .text)
        dedupAndInsert(activity)
    }

    func remove(_ id: UUID) {
        let fetch: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "RecentActivityEntity")
        fetch.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        do {
            let toDelete = try context.fetch(fetch) as? [NSManagedObject] ?? []
            for obj in toDelete { context.delete(obj) }
            try context.save()
            load()
        } catch {
            // Handle errors as needed
        }
    }

    func clear() {
        let fetch: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "RecentActivityEntity")
        let batch = NSBatchDeleteRequest(fetchRequest: fetch)
        do {
            try context.execute(batch)
            try context.save()
            load()
        } catch {
            // Handle errors as needed
        }
    }

    // Rename activity title and underlying file if applicable
    func rename(id: UUID, newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let display = sanitizeTitle(trimmed)

        let fr = NSFetchRequest<NSManagedObject>(entityName: "RecentActivityEntity")
        fr.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fr.fetchLimit = 1
        do {
            guard let obj = try context.fetch(fr).first else { return }
            let kindRaw = (obj.value(forKey: "kind") as? String) ?? RecentActivity.Kind.files.rawValue
            let kind = RecentActivity.Kind(rawValue: kindRaw) ?? .files
            let oldTitle = (obj.value(forKey: "title") as? String) ?? display
            let oldSource = obj.value(forKey: "sourcePath") as? String

            var updatedSource = oldSource

            // If it's a file URL, attempt to rename the file on disk to match new title
            if let sp = oldSource, !sp.isEmpty, FileManager.default.fileExists(atPath: sp) {
                let oldURL = URL(fileURLWithPath: sp)
                let ext = oldURL.pathExtension
                let dir = oldURL.deletingLastPathComponent()
                let newFileName = display + (ext.isEmpty ? "" : ".\(ext)")
                let newURL = dir.appendingPathComponent(newFileName)
                if oldURL != newURL {
                    do {
                        // If a file with target name exists, remove it first
                        if FileManager.default.fileExists(atPath: newURL.path) {
                            try FileManager.default.removeItem(at: newURL)
                        }
                        try FileManager.default.moveItem(at: oldURL, to: newURL)
                        updatedSource = newURL.path
                    } catch {
                        // If rename fails, keep original sourcePath and just update title
                        updatedSource = oldSource
                    }
                }
            }

            // Update Core Data object
            obj.setValue(display, forKey: "title")
            obj.setValue(updatedSource, forKey: "sourcePath")

            // Re-apply dedupe semantics: remove any other items that now conflict with this (kind, sourcePath/title)
            // Delete duplicates except this id
            let dupFetch: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "RecentActivityEntity")
            if let sp = updatedSource, !sp.isEmpty {
                dupFetch.predicate = NSPredicate(format: "kind == %@ AND sourcePath == %@ AND id != %@", kind.rawValue, sp, id as CVarArg)
            } else {
                dupFetch.predicate = NSPredicate(format: "kind == %@ AND title ==[c] %@ AND id != %@", kind.rawValue, display, id as CVarArg)
            }
            let dups = try context.fetch(dupFetch) as? [NSManagedObject] ?? []
            for d in dups { context.delete(d) }

            try context.save()
            load()
        } catch {
            // handle error if needed
        }
    }

    // Delete activity; optionally remove underlying file
    func deleteItem(id: UUID, removeFile: Bool = false) {
        let fr = NSFetchRequest<NSManagedObject>(entityName: "RecentActivityEntity")
        fr.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fr.fetchLimit = 1
        do {
            if let obj = try context.fetch(fr).first {
                if removeFile, let sp = obj.value(forKey: "sourcePath") as? String, !sp.isEmpty, FileManager.default.fileExists(atPath: sp) {
                    do { try FileManager.default.removeItem(atPath: sp) } catch { /* ignore */ }
                }
                context.delete(obj)
                try context.save()
                load()
            }
        } catch {
            // ignore
        }
    }

    // MARK: - Private helpers

    private func sanitizeTitle(_ raw: String) -> String {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return "Untitled" }
        let words = s.split(whereSeparator: { $0.isNewline || $0.isWhitespace })
        let limitedWords = words.prefix(8)
        let candidate = limitedWords.joined(separator: " ")
        if candidate.count > 40 {
            let idx = candidate.index(candidate.startIndex, offsetBy: 40, limitedBy: candidate.endIndex) ?? candidate.endIndex
            return String(candidate[..<idx]) + "…"
        }
        return candidate
    }

    private func dedupAndInsert(_ activity: RecentActivity) {
        // Delete duplicates according to sourcePath if present, else by (kind,title)
        let fetch: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "RecentActivityEntity")
        if let sp = activity.sourcePath, !sp.isEmpty {
            fetch.predicate = NSPredicate(format: "kind == %@ AND sourcePath == %@", activity.kind.rawValue, sp)
        } else {
            fetch.predicate = NSPredicate(format: "kind == %@ AND title ==[c] %@", activity.kind.rawValue, activity.title)
        }

        do {
            let dups = try context.fetch(fetch) as? [NSManagedObject] ?? []
            for obj in dups { context.delete(obj) }

            // Insert new object
            let entity = NSEntityDescription.entity(forEntityName: "RecentActivityEntity", in: context)!
            let obj = NSManagedObject(entity: entity, insertInto: context)
            obj.setValue(activity.id, forKey: "id")
            obj.setValue(activity.title, forKey: "title")
            obj.setValue(activity.sourcePath, forKey: "sourcePath")
            obj.setValue(activity.kind.rawValue, forKey: "kind")
            obj.setValue(activity.createdAt, forKey: "createdAt")
            obj.setValue(activity.thumbnailData, forKey: "thumbnailData")
            obj.setValue(activity.bookmarkData, forKey: "bookmarkData")

            // Trim to maxItems by deleting older ones beyond limit
            try context.save()
            trimIfNeeded()
            load() // refresh published items
        } catch {
            // Handle error as needed
        }
    }

    private func trimIfNeeded() {
        // Fetch count and delete older items beyond maxItems
        let fr = NSFetchRequest<NSManagedObject>(entityName: "RecentActivityEntity")
        fr.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        do {
            let all = try context.fetch(fr)
            if all.count > maxItems {
                let extras = all.suffix(from: maxItems)
                for obj in extras { context.delete(obj) }
                try context.save()
            }
        } catch {
            // ignore
        }
    }

    private func load() {
        let fr = NSFetchRequest<NSManagedObject>(entityName: "RecentActivityEntity")
        fr.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        fr.fetchLimit = maxItems
        do {
            let managed = try context.fetch(fr)
            let mapped: [RecentActivity] = managed.compactMap { obj in
                let id = (obj.value(forKey: "id") as? UUID) ?? UUID()
                let title = (obj.value(forKey: "title") as? String) ?? "Untitled"
                let sourcePath = obj.value(forKey: "sourcePath") as? String
                let kindRaw = (obj.value(forKey: "kind") as? String) ?? RecentActivity.Kind.files.rawValue
                let kind = RecentActivity.Kind(rawValue: kindRaw) ?? .files
                let createdAt = (obj.value(forKey: "createdAt") as? Date) ?? Date()
                let thumb = obj.value(forKey: "thumbnailData") as? Data
                let bookmarkData = obj.value(forKey: "bookmarkData") as? Data
                return RecentActivity(id: id, title: title, sourcePath: sourcePath, kind: kind, createdAt: createdAt, thumbnailData: thumb, bookmarkData: bookmarkData)
            }
            DispatchQueue.main.async {
                self.items = mapped
            }
        } catch {
            DispatchQueue.main.async { self.items = [] }
        }
    }
}

