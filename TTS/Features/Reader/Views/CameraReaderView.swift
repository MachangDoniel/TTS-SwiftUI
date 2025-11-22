//
//  CameraReaderView.swift
//  TTS
//
//  Created by Doniel Tripura on 10/22/25.
//

import SwiftUI
import Vision
import AVFAudio
import UIKit

struct CameraReaderView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var tts: TTSPlayer
    var onSaved: ((URL) -> Void)? = nil

    @State private var image: UIImage? = nil
    @State private var wordBoxes: [OCRWordBox] = []
    @State private var recognizedText: String = ""
    @State private var isShowingCamera = true
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top Bar
            HStack {
                Button("Cancel") {
                    tts.stop()
                    dismiss()
                }
                .foregroundColor(.white)

                Spacer()

                if image != nil {
                    Button("Save File") {
                        saveImageToDisk()
                    }
                    .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color.black)

            // MARK: - Image with TTS Highlight
            ZStack {
                if let img = image {
                    GeometryReader { geo in
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .overlay {
                                ForEach(wordBoxes, id: \.id) { box in
                                    if isCurrentWord(box.text) {
                                        Rectangle()
                                            .fill(Color.blue.opacity(0.35))
                                            .frame(
                                                width: box.rect.width * geo.size.width,
                                                height: box.rect.height * geo.size.height
                                            )
                                            .position(
                                                x: box.rect.midX * geo.size.width,
                                                y: (1 - box.rect.midY) * geo.size.height // flip Y
                                            )
                                            .animation(.easeInOut(duration: 0.12), value: tts.currentWordInSentence)
                                    }
                                }
                            }
                            .background(Color.black)
                    }
                    .padding(.horizontal)
                    .overlay {
                        if isProcessing {
                            ProgressView("Reading...")
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.5))
                        }
                    }
                } else {
                    Spacer()
                    Text("Capture or select an image to begin")
                        .foregroundColor(.gray)
                    Spacer()
                }
            }

            // MARK: - Player Bar Only
            if !recognizedText.isEmpty {
                Divider().background(Color.white.opacity(0.2))
                FullPlayerView(tts: tts, text: recognizedText)
                    .background(Color.black)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .sheet(isPresented: $isShowingCamera) {
            ImagePicker(source: .camera, selectedImage: $image) { img in
                processImage(img)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Word Match Helper
    private func isCurrentWord(_ text: String) -> Bool {
        tts.isSpeaking && text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            == tts.currentWordInSentence.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - OCR
    private func processImage(_ img: UIImage) {
        isProcessing = true
        recognizedText = ""
        wordBoxes = []

        DispatchQueue.global(qos: .userInitiated).async {
            let request = VNRecognizeTextRequest { req, err in
                guard err == nil else { return }
                let observations = req.results as? [VNRecognizedTextObservation] ?? []

                var boxes: [OCRWordBox] = []
                var words: [String] = []

                for obs in observations {
                    guard let top = obs.topCandidates(1).first else { continue }
                    let text = top.string
                    words.append(text)
                    boxes.append(OCRWordBox(id: UUID(), text: text, rect: obs.boundingBox))
                }

                let combined = words.joined(separator: " ")

                DispatchQueue.main.async {
                    isProcessing = false
                    recognizedText = combined
                    wordBoxes = boxes

                    tts.prepareNewFileOnly(text: combined, url: tts.currentURL, title: tts.currentTitle ?? "Camera Capture")
                }
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "bn-BD", "hi-IN"]

            guard let cg = img.cgImage else { return }
            try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([request])
        }
    }

    // MARK: - Save Image Only
    private func saveImageToDisk() {
        guard let img = image else { return }

        do {
            let docs = try FileManager.default.url(for: .documentDirectory,
                                                   in: .userDomainMask,
                                                   appropriateFor: nil,
                                                   create: true)
            let dir = docs.appendingPathComponent("SavedImages", isDirectory: true)
            if !FileManager.default.fileExists(atPath: dir.path) {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }

            let name = "Scan-\(Int(Date().timeIntervalSince1970)).jpg"
            let fileURL = dir.appendingPathComponent(name)

            if let data = img.jpegData(compressionQuality: 0.9) {
                try data.write(to: fileURL)
                tts.currentTitle = name
                tts.currentURL = fileURL
                onSaved?(fileURL)
                dismiss()
            }
        } catch {
            Logger.log("❌ Save failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - OCR Model
//struct OCRWordBox: Identifiable, Hashable {
//    let id: UUID
//    let text: String
//    let rect: CGRect // normalized 0–1 Vision bounding box
//}
