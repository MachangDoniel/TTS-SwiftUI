//
//  FileViewerHeader.swift
//  TTS
//
//  Created by Assistant on 11/11/25.
//

import SwiftUI

struct FileViewerHeader: View {
    let title: String
    let isEditing: Bool
    let onClose: () -> Void
    let onTextSettings: () -> Void
    let onEdit: () -> Void
    let onSave: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Back/Close button (chevron down)
            Button(action: onClose) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
            
            Spacer()
            
            // Title
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer()
            
            // Right-aligned buttons
            HStack(spacing: 0) {
                // Aa button (text settings)
                Button(action: onTextSettings) {
                    Text("Aa")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
                
                // Edit/Save button
                Button(action: isEditing ? onSave : onEdit) {
                    Image(systemName: isEditing ? "checkmark" : "pencil")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color.black)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        FileViewerHeader(
            title: "Sample Document.pdf",
            isEditing: false,
            onClose: {},
            onTextSettings: {},
            onEdit: {},
            onSave: {}
        )
    }
}

