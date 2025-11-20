//
//  DocumentPicker.swift
//  TTS
//
//  Created by Doniel Tripura on 10/4/25.
//

import SwiftUI
import UniformTypeIdentifiers

/// A simple, type-safe wrapper for picking a single document from the Files app.
struct DocumentPicker: UIViewControllerRepresentable {
    /// Supported content types (defaults to PDF, text, image)
    var supportedTypes: [UTType] = [
        .pdf,
        .text,
        .plainText,
        .image,
        .png,
        .jpeg
    ]
    
    /// Callback when a file is successfully picked
    var onPick: (URL) -> Void
    
    /// Optional callback if user cancels the picker
    var onCancel: (() -> Void)? = nil

}

extension DocumentPicker {
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}

extension DocumentPicker {
    // MARK: - Coordinator
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Request security scoped access
            if url.startAccessingSecurityScopedResource() {
                parent.onPick(url)
                url.stopAccessingSecurityScopedResource()
            } else {
                // Still call if access fails (for temporary files)
                parent.onPick(url)
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onCancel?()
            Logger.log("DocumentPicker was cancelled by user")
        }
    }
}
