//
//  BackendChunkStore.swift
//  TTS
//
//  Created by Assistant on 6/11/26.
//

import Foundation
import CoreData

struct BackendChunkRecord {
    let documentRequestId: String
    let chunkIndex: Int
    let text: String?
    let remoteTextURL: String?
    let remoteAudioURL: String?
    let localAudioPath: String?
}

final class BackendChunkStore {
    static let shared = BackendChunkStore()

    private let container: NSPersistentContainer
    private let context: NSManagedObjectContext

    private init() {
        let model = Self.buildModel()
        container = NSPersistentContainer(name: "BackendChunkStore", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        let storeURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("BackendChunkStore.sqlite")
        description.url = storeURL
        description.type = NSSQLiteStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            assertionFailure("Failed to load backend chunk store: \(loadError)")
        }

        context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func saveChunk(
        documentRequestId: String,
        chunkIndex: Int,
        text: String? = nil,
        remoteTextURL: String? = nil,
        remoteAudioURL: String? = nil,
        localAudioPath: String? = nil
    ) {
        context.performAndWait {
            let object = fetchOrCreate(documentRequestId: documentRequestId, chunkIndex: chunkIndex)
            object.setValue(documentRequestId, forKey: "documentRequestId")
            object.setValue(Int64(chunkIndex), forKey: "chunkIndex")
            if let text { object.setValue(text, forKey: "text") }
            if let remoteTextURL { object.setValue(remoteTextURL, forKey: "remoteTextURL") }
            if let remoteAudioURL { object.setValue(remoteAudioURL, forKey: "remoteAudioURL") }
            if let localAudioPath { object.setValue(localAudioPath, forKey: "localAudioPath") }
            try? context.save()
        }
    }

    func fetchChunk(documentRequestId: String, chunkIndex: Int) -> BackendChunkRecord? {
        var record: BackendChunkRecord?
        context.performAndWait {
            let fetch = NSFetchRequest<NSManagedObject>(entityName: "BackendChunkEntity")
            fetch.fetchLimit = 1
            fetch.predicate = NSPredicate(
                format: "documentRequestId == %@ AND chunkIndex == %lld",
                documentRequestId,
                Int64(chunkIndex)
            )
            if let object = try? context.fetch(fetch).first {
                record = map(object)
            }
        }
        return record
    }

    func fetchAllChunks(documentRequestId: String) -> [BackendChunkRecord] {
        var records: [BackendChunkRecord] = []
        context.performAndWait {
            let fetch = NSFetchRequest<NSManagedObject>(entityName: "BackendChunkEntity")
            fetch.predicate = NSPredicate(format: "documentRequestId == %@", documentRequestId)
            fetch.sortDescriptors = [NSSortDescriptor(key: "chunkIndex", ascending: true)]
            let objects = (try? context.fetch(fetch)) ?? []
            records = objects.map(map)
        }
        return records
    }

    func clearDocument(documentRequestId: String) {
        context.performAndWait {
            let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "BackendChunkEntity")
            fetch.predicate = NSPredicate(format: "documentRequestId == %@", documentRequestId)
            let delete = NSBatchDeleteRequest(fetchRequest: fetch)
            _ = try? context.execute(delete)
            try? context.save()
        }
    }

    private func fetchOrCreate(documentRequestId: String, chunkIndex: Int) -> NSManagedObject {
        if let existing = fetchChunkObject(documentRequestId: documentRequestId, chunkIndex: chunkIndex) {
            return existing
        }

        let entity = NSEntityDescription.entity(forEntityName: "BackendChunkEntity", in: context)!
        return NSManagedObject(entity: entity, insertInto: context)
    }

    private func fetchChunkObject(documentRequestId: String, chunkIndex: Int) -> NSManagedObject? {
        let fetch = NSFetchRequest<NSManagedObject>(entityName: "BackendChunkEntity")
        fetch.fetchLimit = 1
        fetch.predicate = NSPredicate(
            format: "documentRequestId == %@ AND chunkIndex == %lld",
            documentRequestId,
            Int64(chunkIndex)
        )
        return try? context.fetch(fetch).first
    }

    private func map(_ object: NSManagedObject) -> BackendChunkRecord {
        BackendChunkRecord(
            documentRequestId: object.value(forKey: "documentRequestId") as? String ?? "",
            chunkIndex: Int(object.value(forKey: "chunkIndex") as? Int64 ?? 0),
            text: object.value(forKey: "text") as? String,
            remoteTextURL: object.value(forKey: "remoteTextURL") as? String,
            remoteAudioURL: object.value(forKey: "remoteAudioURL") as? String,
            localAudioPath: object.value(forKey: "localAudioPath") as? String
        )
    }

    private static func buildModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let entity = NSEntityDescription()
        entity.name = "BackendChunkEntity"
        entity.managedObjectClassName = "NSManagedObject"

        let documentRequestId = NSAttributeDescription()
        documentRequestId.name = "documentRequestId"
        documentRequestId.attributeType = .stringAttributeType
        documentRequestId.isOptional = false

        let chunkIndex = NSAttributeDescription()
        chunkIndex.name = "chunkIndex"
        chunkIndex.attributeType = .integer64AttributeType
        chunkIndex.isOptional = false

        let text = NSAttributeDescription()
        text.name = "text"
        text.attributeType = .stringAttributeType
        text.isOptional = true

        let remoteTextURL = NSAttributeDescription()
        remoteTextURL.name = "remoteTextURL"
        remoteTextURL.attributeType = .stringAttributeType
        remoteTextURL.isOptional = true

        let remoteAudioURL = NSAttributeDescription()
        remoteAudioURL.name = "remoteAudioURL"
        remoteAudioURL.attributeType = .stringAttributeType
        remoteAudioURL.isOptional = true

        let localAudioPath = NSAttributeDescription()
        localAudioPath.name = "localAudioPath"
        localAudioPath.attributeType = .stringAttributeType
        localAudioPath.isOptional = true

        entity.properties = [documentRequestId, chunkIndex, text, remoteTextURL, remoteAudioURL, localAudioPath]
        entity.uniquenessConstraints = [["documentRequestId", "chunkIndex"]]

        model.entities = [entity]
        return model
    }
}
