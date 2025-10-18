import SwiftUI

enum ImportSource: CaseIterable, Identifiable {
    case files
    case gdrive
    case photos
    case scan
    case dropbox
    case book
    case typeText
    case link

    var id: String { title }

    var title: String {
        switch self {
        case .files: return "Files"
        case .gdrive: return "GDrive"
        case .photos: return "Photo"
        case .scan: return "Scan"
        case .dropbox: return "Dbox"
        case .book: return "Book"
        case .typeText: return "Type"
        case .link: return "Link"
        }
    }

    var systemIcon: String {
        switch self {
        case .files: return "folder.fill"
        case .gdrive: return "triangle.fill" // placeholder icon
        case .photos: return "photo.fill.on.rectangle.fill"
        case .scan: return "camera.fill"
        case .dropbox: return "shippingbox.fill"
        case .book: return "book"
        case .typeText: return "textformat"
        case .link: return "link"
        }
    }

    var tint: Color {
        switch self {
        case .files: return .white
        case .gdrive: return .green
        case .photos: return .yellow
        case .scan: return .white
        case .dropbox: return .blue
        case .book: return .white
        case .typeText: return .white
        case .link: return .white
        }
    }

    static var defaultOrder: [ImportSource] {
        return [.files, .gdrive, .photos, .scan, .dropbox, .book, .typeText, .link]
    }
}
