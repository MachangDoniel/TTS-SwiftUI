//
//  ImageReaderView.swift
//  TTS
//
//  Created by Doniel Tripura on 10/22/25.
//

import SwiftUI
import Vision
import AVFAudio
import UIKit
import Mantis
import Combine

enum ImageSourceType {
    case camera, gallery
}

struct ImageReaderView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var tts: TTSPlayer
    var source: ImageSourceType
    var onSaved: ((URL) -> Void)? = nil

    @State private var image: UIImage? = nil
    @State private var croppedImage: UIImage? = nil
    @State private var wordBoxes: [OCRWordBox] = []
    @State private var recognizedText = ""
    @State private var isProcessing = false
    @State private var didStartPicker = false
    @State private var showImagePicker = false
    @State private var showCropper = false

    var body: some View {
        VStack(spacing: 0) {
            FileViewerHeader(
                title: tts.currentTitle ?? "Image Reader",
                isEditing: false,
                onClose: { dismiss() },
                onTextSettings: { /* placeholder for Aa */ },
                onEdit: { /* no-op: ImageReaderView has no editor */ },
                onSave: { /* no-op */ }
            )
            .frame(height: 60)

            // MARK: - Image + OCR Highlight
            if let img = croppedImage ?? image {
                ZStack {
                    GeometryReader { geo in
                        ZStack {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                                .position(x: geo.size.width / 2, y: geo.size.height / 2)

                            ForEach(wordBoxes, id: \.id) { box in
                                if !tts.disableHighlighting && isCurrentWord(box.text) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.myPrimaryColor.opacity(0.4))
                                        .frame(
                                            width: box.rect.width * geo.size.width,
                                            height: box.rect.height * geo.size.height
                                        )
                                        .position(
                                            x: box.rect.midX * geo.size.width,
                                            y: (1 - box.rect.midY) * geo.size.height
                                        )
                                        .animation(.easeInOut(duration: 0.12), value: tts.currentWordInSentence)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .overlay {
                        if isProcessing {
                            ZStack {
                                Color.black.opacity(0.6)
                                    .ignoresSafeArea()
                                VStack(spacing: 12) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .myPrimaryColor))
                                    Text("Analyzing text...")
                                        .foregroundColor(.white)
                                        .font(.callout)
                                }
                                .padding(20)
                                .background(Color.black.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.2), value: isProcessing)
                        }
                    }
                }
            } else {
                Color.black
                    .onAppear {
                        if !didStartPicker {
                            didStartPicker = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showImagePicker = true
                            }
                        }
                    }
            }

            if !recognizedText.isEmpty {
                Divider().background(Color.white.opacity(0.2))
                FullPlayerView(tts: tts, text: recognizedText)
                    .background(Color.black)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)

        // MARK: - Pick Image → Crop → OCR Flow
        .sheet(isPresented: $showImagePicker, onDismiss: {
            if let img = image { showCropper = true }
            else { dismiss() }
        }) {
            NativeImagePicker(source: source == .camera ? .camera : .photoLibrary) { img in
                image = img
            }
        }
        .sheet(isPresented: $showCropper) {
            if let img = image {
                MantisCropperView(image: img) { cropped in
                    croppedImage = cropped
                    showCropper = false
                    processImage(cropped)
                }
            }
        }
    }

    // MARK: - OCR
    private func processImage(_ img: UIImage) {
        isProcessing = true
        DispatchQueue.main.async { tts.state = .loading }
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
                    tts.state = .paused
                    saveImageToDisk()
                }
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "bn-BD", "hi-IN"]

            guard let cg = img.cgImage else { return }
            try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([request])
        }
    }

    // MARK: - Helpers
    private func isCurrentWord(_ text: String) -> Bool {
        tts.isSpeaking &&
        text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ==
        tts.currentWordInSentence.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveImageToDisk() {
        guard let img = croppedImage ?? image else { return }
        do {
            let docs = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let dir = docs.appendingPathComponent("SavedImages", isDirectory: true)
            if !FileManager.default.fileExists(atPath: dir.path) {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }

            let name = "Image-\(Int(Date().timeIntervalSince1970)).jpg"
            let fileURL = dir.appendingPathComponent(name)
            if let data = img.jpegData(compressionQuality: 0.9) {
                try data.write(to: fileURL)
                tts.currentTitle = name
                tts.currentURL = fileURL
                onSaved?(fileURL)
                // Close the sheet; parent will open FileViewer for this URL
                dismiss()
            }
        } catch {
            Logger.log("❌ Save failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Mantis Cropper
struct MantisCropperView: UIViewControllerRepresentable {
    let image: UIImage
    var onCropped: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> CropViewController {
        var config = Mantis.Config()
        config.presetFixedRatioType = .canUseMultiplePresetFixedRatio(defaultRatio: 0)
        config.ratioOptions = [.original, .custom]
        let cropVC = Mantis.cropViewController(image: image, config: config)
        cropVC.delegate = context.coordinator
        cropVC.modalPresentationStyle = .fullScreen
        return cropVC
    }

    func updateUIViewController(_ uiViewController: CropViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, CropViewControllerDelegate {
        let parent: MantisCropperView
        init(_ parent: MantisCropperView) { self.parent = parent }

        func cropViewControllerDidCrop(
            _ cropViewController: CropViewController,
            cropped: UIImage,
            transformation: Transformation,
            cropInfo: CropInfo
        ) {
            cropViewController.dismiss(animated: true) {
                self.parent.onCropped(cropped)
            }
        }

        func cropViewControllerDidCancel(_ cropViewController: CropViewController, original: UIImage) {
            cropViewController.dismiss(animated: true) {
                self.parent.dismiss()
            }
        }

        func cropViewControllerDidFailToCrop(_ cropViewController: CropViewController, original: UIImage) {
            cropViewController.dismiss(animated: true) {
                self.parent.dismiss()
            }
        }

        func cropViewControllerDidBeginResize(_ cropViewController: CropViewController) {}
        func cropViewControllerDidEndResize(
            _ cropViewController: CropViewController,
            original: UIImage,
            cropInfo: CropInfo
        ) {}
    }
}

// MARK: - Image Picker
struct NativeImagePicker: UIViewControllerRepresentable {
    var source: UIImagePickerController.SourceType
    var onPicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = source
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: NativeImagePicker
        init(_ parent: NativeImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            picker.dismiss(animated: true)
            if let img = info[.originalImage] as? UIImage {
                DispatchQueue.main.async { self.parent.onPicked(img) }
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            parent.dismiss()
        }
    }
}

// MARK: - Word Box Model
struct OCRWordBox: Identifiable, Hashable {
    let id: UUID
    let text: String
    let rect: CGRect
}
