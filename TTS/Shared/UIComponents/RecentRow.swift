//
//  RecentRow.swift
//  TTS
//
//  Created by Doniel Tripura on 10/19/25.
//

import SwiftUI

struct RecentRow: View {
    let item: RecentActivity
    let timeFormatter: DateFormatter

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.15, green: 0.15, blue: 0.16))
                .frame(width: 64, height: 64)
                .overlay(thumbnailOrIcon)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 14, design: .default))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(timeFormatter.string(from: item.createdAt))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer(minLength: 0)
        }
    }

    private var icon: some View {
        iconImage
            .resizable()
            .scaledToFit()
            .frame(width: 30, height: 30)
            .foregroundColor(Color.white.opacity(0.9))
    }

    private var thumbnailOrIcon: AnyView {
        if let data = item.thumbnailData, let uiImage = UIImage(data: data) {
            return AnyView(
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            )
        } else {
            return AnyView(icon)
        }
    }

    private var iconImage: Image {
        switch item.kind {
        case .files: return Image(systemName: "folder.fill")
        case .gdrive: return Image(systemName: "externaldrive.fill")
        case .photos: return Image(systemName: "photo.fill.on.rectangle.fill")
        case .scan: return Image(systemName: "camera.fill")
        case .dbox: return Image(systemName: "shippingbox.fill")
        case .book: return Image(systemName: "book.fill")
        case .text: return Image(systemName: "textformat")
        case .link: return Image(systemName: "link")
        }
    }
}
