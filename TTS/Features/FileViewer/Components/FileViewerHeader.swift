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
    let isTextFile: Bool
    let onClose: () -> Void
    let onTextSettings: () -> Void
    let onEdit: () -> Void
    let onSave: () -> Void
    var backgroundColor: Color = .black
    
    init(
        title: String,
        isEditing: Bool,
        isTextFile: Bool = false,
        onClose: @escaping () -> Void,
        onTextSettings: @escaping () -> Void,
        onEdit: @escaping () -> Void,
        onSave: @escaping () -> Void,
        backgroundColor: Color = .black
    ) {
        self.title = title
        self.isEditing = isEditing
        self.isTextFile = isTextFile
        self.onClose = onClose
        self.onTextSettings = onTextSettings
        self.onEdit = onEdit
        self.onSave = onSave
        self.backgroundColor = backgroundColor
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Back/Close button (chevron down)
            Button(action: onClose) {
                Image(systemName: SFSymbols.dismiss)
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
                if isTextFile {
                    Button(action: isEditing ? onSave : onEdit) {
//                        Image(systemName: isEditing ? SFSymbols.edit : SFSymbols.save)
//                            .font(.system(size: 16, weight: .medium))
//                            .foregroundColor(.white)
//                            .frame(width: 44, height: 44)
                        Text(isEditing ? "Save" : "Edit")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                }
            }
            .padding(.trailing, 10)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(backgroundColor)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var isAlt = false
        var body: some View {
            ZStack {
                (isAlt ? Color.gray : Color.black).ignoresSafeArea()
                FileViewerHeader(
                    title: "Sample Document.pdf",
                    isEditing: false,
                    onClose: {},
                    onTextSettings: { isAlt.toggle() },
                    onEdit: {},
                    onSave: {},
                    backgroundColor: isAlt ? .gray : .black
                )
            }
        }
    }
    return PreviewWrapper()
}
