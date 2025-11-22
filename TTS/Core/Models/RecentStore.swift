//
//  RecentStore.swift
//  TTS
//
//  Created by Doniel Tripura on 10/19/25.
//

import SwiftUI
import Combine
import CoreData
import PDFKit
import UIKit

// MARK: - Store (Core Data persistence)
final class RecentStore: ObservableObject {
    @Published private(set) var items: [RecentActivity] = []
    
    private let maxItems = 50
    
    // MARK: - Core Data stack (programmatic model)
    private let container: NSPersistentContainer
    private let context: NSManagedObjectContext
    
    // MARK: - Entity + Attribute KeyString
       private struct KeyString {
           static let entity = "RecentActivityEntity"
           static let id = "id"
           static let modelName = "RecentModel"
           static let objectName = "NSManagedObject"
           static let title = "title"
           static let sourcePath = "sourcePath"
           static let kind = "kind"
           static let createdAt = "createdAt"
           static let thumbnailData = "thumbnailData"
           static let bookmarkData = "bookmarkData"
       }
    
    init() {
        let model = Self.buildModel()
        container = NSPersistentContainer(name: KeyString.modelName, managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        let storeURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("\(KeyString.modelName).sqlite")
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
        entity.name = KeyString.entity
        entity.managedObjectClassName = KeyString.objectName
        
        // Attributes
        let idAttr = NSAttributeDescription()
        idAttr.name = KeyString.id
        idAttr.attributeType = .UUIDAttributeType
        idAttr.isOptional = false
        
        let titleAttr = NSAttributeDescription()
        titleAttr.name = KeyString.title
        titleAttr.attributeType = .stringAttributeType
        titleAttr.isOptional = false
        
        let sourcePathAttr = NSAttributeDescription()
        sourcePathAttr.name = KeyString.sourcePath
        sourcePathAttr.attributeType = .stringAttributeType
        sourcePathAttr.isOptional = true
        
        let kindAttr = NSAttributeDescription()
        kindAttr.name = KeyString.kind
        kindAttr.attributeType = .stringAttributeType
        kindAttr.isOptional = false
        
        let createdAtAttr = NSAttributeDescription()
        createdAtAttr.name = KeyString.createdAt
        createdAtAttr.attributeType = .dateAttributeType
        createdAtAttr.isOptional = false
        
        let thumbAttr = NSAttributeDescription()
        thumbAttr.name = KeyString.thumbnailData
        thumbAttr.attributeType = .binaryDataAttributeType
        thumbAttr.isOptional = true
        
        let bookmarkAttr = NSAttributeDescription()
        bookmarkAttr.name = KeyString.bookmarkData
        bookmarkAttr.attributeType = .binaryDataAttributeType
        bookmarkAttr.isOptional = true
        
        entity.properties = [idAttr, titleAttr, sourcePathAttr, kindAttr, createdAtAttr, thumbAttr, bookmarkAttr]
        
        // No uniqueness constraints; we'll dedupe manually for flexible logic
        model.entities = [entity]
        return model
    }
    
    // MARK: - Public API (unchanged)
    
    func add(title: String, kind: InputSource) {
        let display = sanitizeTitle(title)
        let activity = RecentActivity(title: display, kind: kind)
        dedupAndInsert(activity)
    }
    
    func add(fileURL: URL, kind: InputSource) {
        let base = fileURL.deletingPathExtension().lastPathComponent
        let display = sanitizeTitle(base)
        var thumb: Data? = nil
        if fileURL.pathExtension.lowercased() == "pdf", let doc = PDFDocument(url: fileURL), let page = doc.page(at: 0) {
            let size = CGSize(width: 64, height: 64)
            let img = page.thumbnail(of: size, for: .cropBox)
            thumb = img.pngData()
        }
        // Also handle image/photo files: png, jpg, jpeg, heic
        else if ["png", "jpg", "jpeg", "heic"].contains(fileURL.pathExtension.lowercased()) {
            // Load image from fileURL
            if let image = UIImage(contentsOfFile: fileURL.path) {
                // Generate 64x64 thumbnail using UIGraphicsImageRenderer
                let size = CGSize(width: 64, height: 64)
                let renderer = UIGraphicsImageRenderer(size: size)
                let thumbnail = renderer.image { _ in
                    image.draw(in: CGRect(origin: .zero, size: size))
                }
                thumb = thumbnail.pngData()
            }
        }
        let activity = RecentActivity(title: display,
                                      sourcePath: fileURL.isFileURL ? fileURL.path : fileURL.absoluteString,
                                      kind: kind,
                                      thumbnailData: thumb)
        dedupAndInsert(activity)
    }
    
    func addExternal(fileURL: URL, bookmarkData: Data, kind: InputSource) {
        let base = fileURL.deletingPathExtension().lastPathComponent
        let display = sanitizeTitle(base)
        var thumb: Data? = nil
        if fileURL.pathExtension.lowercased() == "pdf", let doc = PDFDocument(url: fileURL), let page = doc.page(at: 0) {
            let size = CGSize(width: 64, height: 64)
            let img = page.thumbnail(of: size, for: .cropBox)
            thumb = img.pngData()
        }
        // Also handle image/photo files: png, jpg, jpeg, heic
        else if ["png", "jpg", "jpeg", "heic"].contains(fileURL.pathExtension.lowercased()) {
            // Load image from fileURL
            if let image = UIImage(contentsOfFile: fileURL.path) {
                // Generate 64x64 thumbnail using UIGraphicsImageRenderer
                let size = CGSize(width: 64, height: 64)
                let renderer = UIGraphicsImageRenderer(size: size)
                let thumbnail = renderer.image { _ in
                    image.draw(in: CGRect(origin: .zero, size: size))
                }
                thumb = thumbnail.pngData()
            }
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
        let fetch: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: KeyString.entity)
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
        let fetch: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: KeyString.entity)
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
        
        let fr = NSFetchRequest<NSManagedObject>(entityName: KeyString.entity)
        fr.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fr.fetchLimit = 1
        do {
            guard let obj = try context.fetch(fr).first else { return }
            let kindRaw = (obj.value(forKey: KeyString.kind) as? String) ?? InputSource.files.rawValue
            let kind = InputSource(rawValue: kindRaw) ?? .files
            let oldTitle = (obj.value(forKey: KeyString.title) as? String) ?? display
            let oldSource = obj.value(forKey: KeyString.sourcePath) as? String
            
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
            obj.setValue(display, forKey: KeyString.title)
            obj.setValue(updatedSource, forKey: KeyString.sourcePath)
            
            // Re-apply dedupe semantics: remove any other items that now conflict with this (kind, sourcePath/title)
            // Delete duplicates except this id
            let dupFetch: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: KeyString.entity)
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
        let fr = NSFetchRequest<NSManagedObject>(entityName: KeyString.entity)
        fr.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fr.fetchLimit = 1
        do {
            if let obj = try context.fetch(fr).first {
                if removeFile, let sp = obj.value(forKey: KeyString.sourcePath) as? String, !sp.isEmpty, FileManager.default.fileExists(atPath: sp) {
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
        let fetch: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: KeyString.entity)
        if let sp = activity.sourcePath, !sp.isEmpty {
            fetch.predicate = NSPredicate(format: "kind == %@ AND sourcePath == %@", activity.kind.rawValue, sp)
        } else {
            fetch.predicate = NSPredicate(format: "kind == %@ AND title ==[c] %@", activity.kind.rawValue, activity.title)
        }
        
        do {
            let dups = try context.fetch(fetch) as? [NSManagedObject] ?? []
            for obj in dups { context.delete(obj) }
            
            // Insert new object
            let entity = NSEntityDescription.entity(forEntityName: KeyString.entity, in: context)!
            let obj = NSManagedObject(entity: entity, insertInto: context)
            obj.setValue(activity.id, forKey: KeyString.id)
            obj.setValue(activity.title, forKey: KeyString.title)
            obj.setValue(activity.sourcePath, forKey: KeyString.sourcePath)
            obj.setValue(activity.kind.rawValue, forKey: KeyString.kind)
            obj.setValue(activity.createdAt, forKey: KeyString.createdAt)
            obj.setValue(activity.thumbnailData, forKey: KeyString.thumbnailData)
            obj.setValue(activity.bookmarkData, forKey: KeyString.bookmarkData)
            
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
        let fr = NSFetchRequest<NSManagedObject>(entityName: KeyString.entity)
        fr.sortDescriptors = [NSSortDescriptor(key: KeyString.createdAt, ascending: false)]
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
        let fr = NSFetchRequest<NSManagedObject>(entityName: KeyString.entity)
        fr.sortDescriptors = [NSSortDescriptor(key: KeyString.createdAt, ascending: false)]
        fr.fetchLimit = maxItems
        do {
            let managed = try context.fetch(fr)
            let mapped: [RecentActivity] = managed.compactMap { obj in
                let id = (obj.value(forKey: KeyString.id) as? UUID) ?? UUID()
                let title = (obj.value(forKey: KeyString.title) as? String) ?? "Untitled"
                let sourcePath = obj.value(forKey: KeyString.sourcePath) as? String
                let kindRaw = (obj.value(forKey: KeyString.kind) as? String) ?? InputSource.files.rawValue
                let kind = InputSource(rawValue: kindRaw) ?? .files
                let createdAt = (obj.value(forKey: KeyString.createdAt) as? Date) ?? Date()
                let thumb = obj.value(forKey: KeyString.thumbnailData) as? Data
                let bookmarkData = obj.value(forKey: KeyString.bookmarkData) as? Data
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

