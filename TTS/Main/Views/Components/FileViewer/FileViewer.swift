//
//  FileViewer.swift
//  TTS
//
//  Created by Doniel Tripura on 10/5/25.
//

import SwiftUI
import PDFKit
import Vision
import AVFAudio
import UIKit

struct FileViewer: View {
    let fileURL: URL
    @ObservedObject var tts: TTSPlayer
    
    init(fileURL: URL, tts: TTSPlayer) {
        self.fileURL = fileURL
        self._tts = ObservedObject(initialValue: tts)
    }
    
    @State private var extractedText: String = ""
    @State private var isImage: Bool = false
    @State private var uiImage: UIImage? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - File Content
            if fileURL.pathExtension.lowercased() == "pdf" {
                PDFKitView(url: fileURL, tts: tts)
                
            } else if ["png", "jpg", "jpeg", "heic"].contains(fileURL.pathExtension.lowercased()) {
                if let img = uiImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .background(Color.black)
                        .onAppear { performOCRIfNeeded() }
                } else {
                    ProgressView("Loading image...")
                        .onAppear { loadImage() }
                }
                
            } else if fileURL.pathExtension.lowercased() == "txt" {
                ScrollView {
                    if tts.sentences.isEmpty {
                        // Before reading starts, show raw text
                        Text(extractedText.isEmpty ? "Loading..." : extractedText)
                            .font(.system(size: 18))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    } else {
                        // During speech, show per-sentence highlights
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(tts.sentences.enumerated()), id: \.offset) { index, sentence in
                                SentenceLineView(
                                    sentence: sentence,
                                    isActive: index == tts.currentIndex,
                                    wordRange: index == tts.currentIndex ? tts.currentWordRange : nil
                                )
                            }
                        }
                        .padding()
                    }
                }
                .background(Color.black)
                .onAppear {
                    loadText()
                }
                
            } else {
                Text("Unsupported file type")
                    .foregroundColor(.gray)
                    .padding()
            }
            
            // MARK: - Controls
            TTSControlView(tts: tts, text: extractedText)
        }
        .onAppear {
            // If switching to a different file, stop the old one; otherwise keep speaking
            if let current = tts.currentURL, current != fileURL {
                tts.stop()
            }

            tts.currentTitle = fileURL.lastPathComponent
            let ext = fileURL.pathExtension.lowercased()

            switch ext {
            case "pdf":
                let text = extractText(from: fileURL)
                extractedText = text
                // Only start if not already speaking this file
                if tts.currentURL != fileURL || !tts.isSpeaking {
                    startSpeech(with: text)
                }

            case "txt":
                loadText() // startSpeech is gated inside loadText

            default:
                detectFileType()
                // For images/others, OCR will trigger start if needed
            }
        }
        .navigationTitle(fileURL.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
    
    // MARK: - File Handlers
    
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
    
    private func loadText() {
        DispatchQueue.global(qos: .userInitiated).async {
            if let data = try? Data(contentsOf: fileURL),
               let content = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.extractedText = content
                    if self.tts.currentURL != self.fileURL || !self.tts.isSpeaking {
                        self.startSpeech(with: content)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.extractedText = "⚠️ Unable to load text."
                }
            }
        }
    }
    
    private func loadImage() {
        if let img = UIImage(contentsOfFile: fileURL.path) {
            uiImage = img
            isImage = true
            performOCRIfNeeded()
        } else {
            extractedText = "⚠️ Unable to load image."
        }
    }
    
    private func detectFileType() {
        let ext = fileURL.pathExtension.lowercased()
        if ["png", "jpg", "jpeg", "heic"].contains(ext) {
            isImage = true
            loadImage()
        } else if ext == "txt" {
            loadText()
        }
    }
    
    private func startSpeech(with text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        if tts.currentURL == fileURL && tts.isSpeaking {
            // Already speaking this file; do not restart
            return
        }
        
        if tts.currentURL != fileURL {
            // New file: reset synthesizer and reading state
            tts.synthesizer.delegate = nil
            tts.synthesizer = AVSpeechSynthesizer()
            tts.synthesizer.delegate = tts
            tts.currentURL = fileURL
            tts.currentIndex = 0
            tts.currentWordRange = nil
            tts.currentWordInSentence = ""
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            tts.startReading(text)
        }
    }
    
    private func performOCRIfNeeded() {
        guard isImage, let img = uiImage else { return }
        if !extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return }

        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.extractedText = "⚠️ OCR failed: \(error.localizedDescription)"
                }
                return
            }
            let observations = request.results as? [VNRecognizedTextObservation] ?? []
            let lines: [String] = observations.compactMap { $0.topCandidates(1).first?.string }
            let text = lines.joined(separator: "\n")
            DispatchQueue.main.async {
                self.extractedText = text.isEmpty ? "No text detected." : text
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.startSpeech(with: text)
                }
            }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        DispatchQueue.global(qos: .userInitiated).async {
            guard let cgImage = img.cgImage else {
                DispatchQueue.main.async { self.extractedText = "⚠️ Unable to read image." }
                return
            }
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    self.extractedText = "⚠️ OCR error: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Highlight View for Sentences
import SwiftUI

struct SentenceLineView: View {
    let sentence: String
    let isActive: Bool
    let wordRange: NSRange?

    @State private var wordFrame: CGRect = .zero
    @State private var shouldAnimate = false

    var body: some View {
        ZStack(alignment: .leading) {
            // Base text
            Text(sentence)
                .font(.system(size: 18))
                .foregroundColor(isActive ? .white : .white.opacity(0.7))
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: WordFramePreferenceKey.self,
                            value: calculateWordFrame(in: geo.size)
                        )
                    }
                )

            // Blue overlay (precise highlight)
            if isActive && wordFrame != .zero {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.blue.opacity(0.7))
                    .frame(width: wordFrame.width, height: wordFrame.height)
                    .offset(x: wordFrame.minX, y: wordFrame.minY)
                    .animation(.easeInOut(duration: 0.12), value: wordFrame)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onPreferenceChange(WordFramePreferenceKey.self) { newFrame in
            // Safely update state outside render phase
            DispatchQueue.main.async {
                if newFrame != self.wordFrame {
                    self.wordFrame = newFrame
                }
            }
        }
    }

    // MARK: - Calculate Highlight Frame
    private func calculateWordFrame(in size: CGSize) -> CGRect {
        guard isActive,
              let range = wordRange,
              let swiftRange = Range(range, in: sentence) else {
            return .zero
        }

        // Use UILabel to measure the exact range of the word
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 18)
        label.text = sentence
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.frame = CGRect(origin: .zero, size: size)

        let textStorage = NSTextStorage(string: sentence, attributes: [.font: label.font!])
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: size)
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = 0
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        let nsRange = NSRange(swiftRange, in: sentence)
        return layoutManager.boundingRect(forGlyphRange: nsRange, in: textContainer)
    }
}

// MARK: - Preference Key
private struct WordFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
