//
//  PDFKitView.swift
//  TTS
//
//  Created by Doniel Tripura on 10/7/25.
//

import SwiftUI
import PDFKit
import Combine

struct PDFKitView: UIViewRepresentable {
    
    let url: URL
    @ObservedObject var tts: TTSPlayer
    
    init(url: URL, tts: TTSPlayer) {
        self.url = url
        self.tts = tts
    }
    
    // Keep current highlight
    class Coordinator {
        var currentHighlight: PDFAnnotation?
        var cancellables = Set<AnyCancellable>()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.document = PDFDocument(url: url)
        
        // Observe sentence changes
        tts.$currentIndex.sink { index in
            highlightSentence(in: pdfView, index: index, coordinator: context.coordinator)
        }.store(in: &context.coordinator.cancellables)
        
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {}
    
    // Store subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    private func highlightSentence(in pdfView: PDFView, index: Int, coordinator: Coordinator) {
        guard tts.sentences.indices.contains(index) else { return }
        let sentence = tts.sentences[index]
        
        // Remove previous highlight
        if let previous = coordinator.currentHighlight {
            previous.page?.removeAnnotation(previous)
            coordinator.currentHighlight = nil
        }
        
        // Search sentence in PDF pages
        guard let doc = pdfView.document else { return }
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            if let selection = page.selection(for: NSRange(location: 0, length: page.string?.count ?? 0)) {
                if let range = selection.string?.range(of: sentence) {
                    let nsRange = NSRange(range, in: selection.string!)
                    if let sentenceSelection = page.selection(for: nsRange) {
                        let bounds = sentenceSelection.bounds(for: page)
                        let highlight = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
                        highlight.color = UIColor.yellow.withAlphaComponent(0.4)
                        page.addAnnotation(highlight)
                        coordinator.currentHighlight = highlight
                        pdfView.go(to: sentenceSelection)
                        break
                    }
                }
            }
        }
    }
}


//#Preview {
//    PDFKitView()
//}
