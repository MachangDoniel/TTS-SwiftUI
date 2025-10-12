//
//  FileViewer.swift
//  TTS
//
//  Created by Doniel Tripura on 10/5/25.
//

import SwiftUI
import PDFKit

struct FileViewer: View {
    
    let fileURL: URL
    @StateObject private var tts = TTSPlayer()
    @State private var extractedText: String = ""
    
    var body: some View {
        VStack {
            if fileURL.pathExtension.lowercased() == "pdf" {
                PDFKitView(url: fileURL, tts: tts)
            } else if ["txt"].contains(fileURL.pathExtension.lowercased()) {
                ScrollView {
                    if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
                        VStack(alignment: .leading) {
                            ForEach(tts.sentences.indices, id: \.self) { i in
                                Text(tts.sentences[i])
                                    .foregroundColor(tts.currentIndex == i ? .blue : .primary)
                            }
                        }
                        .padding()
                        .onAppear {
                            extractedText = content
                            tts.startReading(content)
                        }
                    }
                }
            } else {
                Text("File type not supported")
            }
            
            if !extractedText.isEmpty || fileURL.pathExtension.lowercased() == "pdf" {
                TTSControlsView(tts: tts, text: extractedText)
            }
        }
        .onAppear {
            if fileURL.pathExtension.lowercased() == "pdf" {
                extractedText = extractText(from: fileURL)
                tts.startReading(extractedText)
            }
        }
        .onDisappear {
            tts.stop()
        }
        .navigationTitle(fileURL.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    func extractText(from url: URL) -> String {
        guard let pdf = PDFDocument(url: url) else { return "" }
        var text = ""
        for i in 0..<pdf.pageCount {
            if let page = pdf.page(at: i) {
                text += page.string ?? ""
                text += "\n"
            }
        }
        return text
    }
}


//#Preview {
//    FileViewer(fileURL: URL(fileURLWithPath: "/path/to/sample.pdf"), tts: <#TTSPlayer#>)
//}
