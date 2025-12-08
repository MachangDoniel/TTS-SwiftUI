//
//  RecentRow.swift
//  TTS
//
//  Created by Doniel Tripura on 10/19/25.
//

import SwiftUI

struct RecentRow: View {
    let item: RecentActivity

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.15, green: 0.15, blue: 0.16))
                .frame(width: 64, height: 64)
                .overlay(thumbnailOrIcon)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 16, design: .default))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(formattedTime())
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer(minLength: 0)
        }
    }
    
    private func formattedTime() -> String {
        guard let wordCount = item.wordCount, wordCount > 0 else {
            return "00.00"
        }
        
        // Calculate time: 0.4 seconds per word
        let totalSeconds = Int(0.4 * Double(wordCount))
        
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            // Format as hh.mm.ss
            return String(format: "%02d.%02d.%02d", hours, minutes, seconds)
        } else {
            // Format as mm.ss
            return String(format: "%02d.%02d", minutes, seconds)
        }
    }

    
    private func formatTimeToComplete() -> String {
        guard let wordCount = item.wordCount, wordCount > 0 else {
            return "0 sec"
        }
        
        // Calculate time: 0.4 seconds per word
        let totalSeconds = 0.4 * Double(wordCount)
        let minutes = Int(totalSeconds) / 60
        let seconds = Int(totalSeconds) % 60
        
        if minutes > 0 {
            if seconds > 0 {
                return "\(minutes) min \(seconds) sec"
            } else {
                return "\(minutes) min"
            }
        } else {
            return "\(seconds) sec"
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
