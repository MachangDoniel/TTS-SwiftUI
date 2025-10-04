//
//  BottomSheet.swift
//  TTS
//
//  Created by Doniel Tripura on 10/4/25.
//

import SwiftUI

struct BottomSheet: View {
    @Binding var showBottomSheet: Bool
    
    var onDocumentTap: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Spacer()
                Text("Add")
                    .font(.title2)
                    .bold()
                Spacer()
                Button(action: { showBottomSheet = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            .padding(.top, 50)
            
            Divider()
            
            // Options
            VStack(alignment: .leading, spacing: 16) {
                BottomSheetOptionRow(
                    icon: "doc.text",
                    title: "Document",
                    description: "Upload or create a document"
                )
                .onTapGesture {
                    showBottomSheet = false
                    onDocumentTap?()
                }
                BottomSheetOptionRow(
                    icon: "textformat",
                    title: "Text",
                    description: "Write plain text notes"
                )
                BottomSheetOptionRow(
                    icon: "photo.on.rectangle",
                    title: "Image",
                    description: "Add or upload an image"
                )
                BottomSheetOptionRow(
                    icon: "camera.fill",
                    title: "Camera",
                    description: "Take a photo using your camera"
                )
                BottomSheetOptionRow(
                    icon: "link",
                    title: "Webpage URL",
                    description: "Attach a website link"
                )
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
}

struct BottomSheetOptionRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }
}
