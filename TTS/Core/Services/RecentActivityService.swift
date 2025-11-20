//
//  RecentActivityService.swift
//  TTS
//
//  Created by Doniel Tripura on 11/20/25.
//


import Foundation

final class RecentActivityService {
    static func createTextActivity(title: String, text: String) throws -> RecentActivity {
        let sanitizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = sanitizedTitle.isEmpty ? "Text" : sanitizedTitle
        let uniqueName = "\(base) - \(UUID().uuidString.prefix(8)).txt"
        let fm = FileManager.default
        let docsURL = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let fileURL = docsURL.appendingPathComponent(uniqueName)
        try text.write(to: fileURL, atomically: true, encoding: .utf8)
        return RecentActivity(title: uniqueName, sourcePath: fileURL.path, kind: .text)
    }
}
