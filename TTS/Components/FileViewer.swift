//
//  FileViewer.swift
//  TTS
//
//  Created by Doniel Tripura on 10/5/25.
//

import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct FileViewer: View {
    let fileURL: URL
    
    var body: some View {
        VStack {
            if fileURL.pathExtension.lowercased() == "pdf" {
                PDFKitView(url: fileURL)
            } else if ["png", "jpg", "jpeg", "heic", "heif"].contains(fileURL.pathExtension.lowercased()) {
                if let image = UIImage(contentsOfFile: fileURL.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding()
                } else {
                    Text("Cannot load image")
                }
            } else if fileURL.pathExtension.lowercased() == "txt" {
                ScrollView {
                    if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                        Text(content)
                            .padding()
                    } else {
                        Text("Cannot read text file")
                    }
                }
            } else {
                Text("File type not supported")
                    .padding()
            }
        }
    }
}

// PDFKit wrapper
struct PDFKitView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.document = PDFDocument(url: url)
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {}
}
