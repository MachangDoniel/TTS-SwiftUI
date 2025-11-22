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
    @Environment(\.dismiss) private var dismiss
    
    // Default to read-only mode for text files
    @State private var extractedText: String = ""
    @State private var isImage: Bool = false
    @State private var uiImage: UIImage? = nil
    @State private var editedText: String = ""
    @State private var hasUnsavedChanges: Bool = false
    @State private var isReadOnly: Bool = true
    @FocusState private var isTextEditorFocused: Bool
    @State private var backgroundColor: Color = .black
    
    @StateObject private var highlightCoordinator = HighlightCoordinator()

    init(fileURL: URL, tts: TTSPlayer) {
        self.fileURL = fileURL
        self._tts = ObservedObject(initialValue: tts)
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // MARK: - Custom Header (fixed at top)
                FileViewerHeader(
                    title: fileURL.lastPathComponent,
                    isEditing: !isReadOnly,
                    onClose: {
                        // Dismiss without stopping TTS
                        dismiss()
                    },
                    onTextSettings: {
                        // Toggle background color to red
                        backgroundColor = backgroundColor == .black ? .red : .black
                    },
                    onEdit: {
                        // Enable editing for all file types
                        enableEditing()
                    },
                    onSave: {
                        // Save and exit edit mode
                        saveFile()
                        isReadOnly = true
                    }
                )
                .frame(height: 60)
                
                // MARK: - File Content (fills middle space)
                fileContentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(backgroundColor)
                
                // MARK: - Controls (fixed at bottom)
                FileViewerTTSControlWrapper(
                    tts: tts,
                    text: editedText.isEmpty ? extractedText : editedText,
                    fileURL: fileURL
                )
            }
        }
        .background(backgroundColor.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear {
            handleFileOpening()
        }
    }
    
    private func handleFileOpening() {
        // Check TTS state: if stopped (idle/finished), stop it; if playing/paused, let it continue
        if tts.state == .idle || tts.state == .finished {
            // Previous TTS is stopped, so stop it to prepare for new file
            if let current = tts.currentURL, current != fileURL {
                tts.stop()
            }
        }
        // If playing/paused, let it continue - we'll prepare new file but won't interrupt
        
        // Always prepare the new file
        tts.currentTitle = fileURL.lastPathComponent
        self.editedText = ""
        
        let ext = fileURL.pathExtension.lowercased()
        let alreadyPreparedForThisURL = (tts.currentURL == fileURL) && !tts.sentences.isEmpty
        
        switch ext {
        case "pdf":
            if !alreadyPreparedForThisURL {
                tts.state = .loading
                let text = extractText(from: fileURL)
                extractedText = text
                editedText = text
                tts.prepareNewFileOnly(text: text, url: fileURL, title: fileURL.lastPathComponent)
                tts.state = .paused
            } else {
                // Already prepared; do nothing to avoid fake loading
            }
            
        case "txt":
            if !alreadyPreparedForThisURL {
                tts.state = .loading
                loadText() // prepares inside loadText
            } else {
                loadText()
                // Already prepared; do nothing
            }
            self.isReadOnly = true
            
        default:
            // Images and others
            if alreadyPreparedForThisURL {
                // We’re already prepared for this file; avoid fake loading even if extractedText is empty due to view recreation
                Logger.log("[FileViewer] Image already prepared for this URL; skipping detect/OCR.")
            } else if extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Not prepared and no text yet → perform detect/OCR
                tts.state = .loading
                detectFileType() // loadImage -> OCR will set paused when done
            } else {
                // We have text but TTS not prepared for this URL → prepare and pause
                tts.state = .loading
                tts.prepareNewFileOnly(text: extractedText, url: fileURL, title: fileURL.lastPathComponent)
                tts.state = .paused
            }
        }
        
        // Monitor TTS state changes to ensure new file plays when user clicks play
        // If user clicks play and currentURL matches fileURL but TTS is playing old file, stop and start new
        observeTTSState()
    }
    
    private func observeTTSState() {
        // This is handled by FileViewerTTSControlWrapper
    }
    
    private var fileContentView: some View {
        ZStack {
            // Black background fills the space
            backgroundColor
            
            Group {
                if isReadOnly {
                    // Read-only view
                    if fileURL.pathExtension.lowercased() == "pdf" {
                        PDFKitView(url: fileURL, tts: tts)
                            .onAppear {
                                if let doc = PDFDocument(url: fileURL) {
                                    highlightCoordinator.setDocument(.pdf(document: doc))
                                }
                            }
                    } else if ["png", "jpg", "jpeg", "heic"].contains(fileURL.pathExtension.lowercased()) {
                        Group {
                            if let img = uiImage {
                                GeometryReader { geo in
                                    ScrollView(.vertical, showsIndicators: true) {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: geo.size.width)
                                            .clipped()
                                    }
                                    .frame(width: geo.size.width, height: geo.size.height)
                                }
                                .onAppear { performOCRIfNeeded() }
                            } else {
                                ProgressView("Loading image...")
                                    .foregroundColor(.white)
                                    .onAppear { loadImage() }
                            }
                        }
                    } else if fileURL.pathExtension.lowercased() == "txt" {
                        ReadOnlyAccurateHighlight(fullText: editedText.isEmpty ? extractedText : editedText, tts: tts)
                    } else {
                        Text("Unsupported file type")
                            .foregroundColor(.gray)
                            .padding()
                    }
                } else {
                    // Editable view - show text editor for all file types
                    TextEditor(text: $editedText)
                        .focused($isTextEditorFocused)
                        .padding()
                        .background(backgroundColor)
                        .foregroundColor(.white)
                        .font(.system(size: 18))
                        .onChange(of: editedText) { newValue in
                            hasUnsavedChanges = (newValue != extractedText)
                        }
                        .onAppear {
                            isTextEditorFocused = true
                            // Initialize editedText if empty
                            if editedText.isEmpty && !extractedText.isEmpty {
                                editedText = extractedText
                            }
                        }
                }
            }
        }
    }
}

// MARK: - TTS Control Wrapper
struct FileViewerTTSControlWrapper: View {
    @ObservedObject var tts: TTSPlayer
    let text: String
    let fileURL: URL
    
    var body: some View {
        FullPlayerView(tts: tts, text: text)
        // Removed .onChange(of: tts.state) to avoid unintended re-prepare when state flips to playing
    }
}

extension FileViewer {
    // MARK: - Editing Functions
    
    private func enableEditing() {
        // For PDFs and images, ensure we have extracted text
        let ext = fileURL.pathExtension.lowercased()
        if ext == "pdf" {
            if extractedText.isEmpty {
                let text = extractText(from: fileURL)
                extractedText = text
                editedText = text
            }
        } else if ["png", "jpg", "jpeg", "heic"].contains(ext) {
            // For images, use OCR text if available
            if extractedText.isEmpty && uiImage != nil {
                performOCRIfNeeded()
            }
            // Wait a bit for OCR if needed, or use existing extractedText
            if editedText.isEmpty && !extractedText.isEmpty {
                editedText = extractedText
            }
        } else if ext == "txt" {
            // For text files, ensure editedText is set
            if editedText.isEmpty && !extractedText.isEmpty {
                editedText = extractedText
            }
        }
        
        isReadOnly = false
        isTextEditorFocused = true
    }
    
    private func saveFile() {
        let ext = fileURL.pathExtension.lowercased()
        
        if ext == "txt" {
            saveTextToFile()
        } else if ext == "pdf" {
            // For PDFs, save as text file (since we can't edit PDF structure)
            savePDFAsText()
        } else if ["png", "jpg", "jpeg", "heic"].contains(ext) {
            // For images, save OCR text as text file
            saveImageTextAsFile()
        } else {
            // For other types, try to save as text
            saveTextToFile()
        }
    }
    
    private func savePDFAsText() {
        let trimmed = editedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let fm = FileManager.default
        let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let name = fileURL.deletingPathExtension().lastPathComponent + ".txt"
        let destinationURL = docsURL.appendingPathComponent(name)
        
        do {
            try trimmed.write(to: destinationURL, atomically: true, encoding: .utf8)
            hasUnsavedChanges = false
            extractedText = trimmed
            editedText = trimmed
            
            tts.prepareNewFileOnly(text: trimmed, url: destinationURL, title: destinationURL.lastPathComponent)
            tts.currentURL = destinationURL
            highlightCoordinator.setDocument(.plainText(text: trimmed))
            
            Logger.log("✅ Saved PDF text to file: \(destinationURL.lastPathComponent)")
        } catch {
            Logger.log("❌ Save failed: \(error.localizedDescription)")
        }
    }
    
    private func saveImageTextAsFile() {
        let trimmed = editedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let fm = FileManager.default
        let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let name = fileURL.deletingPathExtension().lastPathComponent + ".txt"
        let destinationURL = docsURL.appendingPathComponent(name)
        
        do {
            try trimmed.write(to: destinationURL, atomically: true, encoding: .utf8)
            hasUnsavedChanges = false
            extractedText = trimmed
            editedText = trimmed
            
            tts.prepareNewFileOnly(text: trimmed, url: destinationURL, title: destinationURL.lastPathComponent)
            tts.currentURL = destinationURL
            highlightCoordinator.setDocument(.plainText(text: trimmed))
            
            Logger.log("✅ Saved image text to file: \(destinationURL.lastPathComponent)")
        } catch {
            Logger.log("❌ Save failed: \(error.localizedDescription)")
        }
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
                    self.editedText = content
                    self.hasUnsavedChanges = false
                    self.isReadOnly = true  // Start in read-only mode
                    
                    let alreadyPrepared = (self.tts.currentURL == self.fileURL) && !self.tts.sentences.isEmpty
                    if !alreadyPrepared {
                        self.tts.prepareNewFileOnly(
                            text: content,
                            url: self.fileURL,
                            title: self.fileURL.lastPathComponent
                        )
                        self.tts.currentURL = self.fileURL
                    }
                    self.tts.state = .paused  // Set ready state after content assigned
                }
            } else {
                DispatchQueue.main.async {
                    self.extractedText = "⚠️ Unable to load text."
                    self.editedText = "⚠️ Unable to load text."
                }
            }
        }
    }
    
    private func saveTextToFile() {
        let trimmed = editedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Determine a writable destination URL. Prefer the existing fileURL if it's in Documents and writable.
        let fm = FileManager.default
        let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first!

        var destinationURL = fileURL
        // If the current URL is not in Documents, redirect to Documents with same lastPathComponent
        if !destinationURL.path.hasPrefix(docsURL.path) {
            destinationURL = docsURL.appendingPathComponent(fileURL.lastPathComponent)
        }

        // Ensure .txt extension
        if destinationURL.pathExtension.lowercased() != "txt" {
            destinationURL.deletePathExtension()
            destinationURL.appendPathExtension("txt")
        }

        do {
            // Create file if it doesn't exist
            if !fm.fileExists(atPath: destinationURL.path) {
                let created = fm.createFile(atPath: destinationURL.path, contents: nil, attributes: nil)
                if !created {
                    throw NSError(domain: "FileViewer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create file at destination."])
                }
            }
            // Write contents
            try trimmed.write(to: destinationURL, atomically: true, encoding: .utf8)

            // Update state to reflect saved file and new URL
            hasUnsavedChanges = false
            extractedText = trimmed
            editedText = trimmed

            // Prepare TTS with the saved text
            tts.prepareNewFileOnly(text: trimmed, url: destinationURL, title: destinationURL.lastPathComponent)
            tts.currentURL = destinationURL

            // Convert to read-only mode and update highlights
            isReadOnly = true
            highlightCoordinator.setDocument(.plainText(text: trimmed))

            Logger.log("✅ Saved text to file: \(destinationURL.lastPathComponent)")
        } catch {
            Logger.log("❌ Save failed: \(error.localizedDescription)")
        }
    }
    
    private func loadImage() {
        if let img = UIImage(contentsOfFile: fileURL.path) {
            uiImage = img
            isImage = true
            // Leave tts.state as loading, OCR will update to paused on completion.
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
                self.editedText = self.extractedText // Initialize editedText for editing
//                self.tts.state = .paused  // Set ready state after OCR completes
                
                let alreadyPrepared = (self.tts.currentURL == self.fileURL) && !self.tts.sentences.isEmpty
                if !alreadyPrepared && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.tts.prepareNewFileOnly(
                        text: text,
                        url: self.fileURL,
                        title: self.fileURL.lastPathComponent
                    )
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

