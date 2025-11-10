//
//  ImportSource.swift
//  TTS
//
//  Created by Doniel Tripura on 10/5/25.
//

import SwiftUI

enum InputSource: String, CaseIterable, Identifiable, Codable {
    case files, gdrive, photos, scan, dbox, book, text, link

    var id: String { rawValue }

    var title: String {
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

    var systemIcon: String {
        switch self {
        case .files: return "folder.fill"
        case .gdrive: return "triangle.fill"
        case .photos: return "photo.fill.on.rectangle.fill"
        case .scan: return "camera.fill"
        case .dbox: return "shippingbox.fill"
        case .book: return "book"
        case .text: return "textformat"
        case .link: return "link"
        }
    }

    var tint: Color {
        switch self {
        case .files: return .white
        case .gdrive: return .green
        case .photos: return .yellow
        case .scan: return .white
        case .dbox: return .blue
        case .book: return .white
        case .text: return .white
        case .link: return .white
        }
    }

    static var defaultOrder: [InputSource] {
        return [.files, .gdrive, .photos, .scan, .dbox, .book, .text, .link]
    }
    
    var fileCategory: FileCategory {
           switch self {
           case .text:
               return .text
           case .photos:
               return .image
           case .files, .book, .dbox:
               return .pdf  // assuming most imported documents are PDFs
           case .scan:
               return .image
           case .gdrive, .link:
               return .all  // these can contain mixed types
           }
       }
}
