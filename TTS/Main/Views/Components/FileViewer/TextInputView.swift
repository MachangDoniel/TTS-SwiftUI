//
//  TextInputView.swift
//  TTS
//
//  Created by Doniel Tripura on 10/20/25.
//


import SwiftUI

struct TextInputView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var tts: TTSPlayer
    var prefilledText: String? = nil
    var onSaved: ((URL) -> Void)? = nil

    @State private var inputText = ""
    @State private var isReadOnly: Bool = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - Top Bar (only show in editable mode)
            if !isReadOnly {
                HStack {
                    Button("Cancel") {
                        cancelAndDismiss()
                    }
                    .foregroundColor(.white)

                    Spacer()

                    Button("Save File") {
                        saveAndConvertToReadOnly()
                    }
                    .foregroundColor(.blue)
                }
                .padding()
                .background(Color.black)
            }

            // MARK: - Content Area
            if isReadOnly {
                // Read-only mode: Show accurate word + sentence highlighting
                ReadOnlyAccurateHighlight(fullText: inputText, tts: tts)
            } else {
                // Editable mode: Show TextEditor with sentence-only highlighting
                ZStack(alignment: .topLeading) {
                    if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Write anything")
                            .foregroundColor(.gray)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .zIndex(1)
                    }

                    TextEditor(text: $inputText)
                        .focused($focused)
                        .scrollContentBackground(.hidden)
                        .foregroundColor(.white)
                        .font(.system(size: 18))
                        .padding(.horizontal, 10)
                        .background(Color.black)
                    
                    // Sentence highlighting overlay (only when playing)
                    if !tts.sentences.isEmpty && tts.isSpeaking && !inputText.isEmpty {
                        EditableSentenceHighlight(fullText: inputText, tts: tts)
                            .allowsHitTesting(false)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                    }
                }
            }

            // MARK: - TTS Controls
            TTSControlView(tts: tts, text: inputText)
                .background(Color.black)
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .navigationBarHidden(true)
        .onAppear {
            // 👇 if text came from web extraction, set and start reading immediately
            if let prefilled = prefilledText, inputText.isEmpty {
                inputText = prefilled
                tts.stop()
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
//                    tts.startReading(prefilled)
//                }
            }
        }
    }

    // MARK: - Cancel Handler
    private func cancelAndDismiss() {
        tts.stop()
        dismiss()
    }

    // MARK: - Save Handler
    private func saveAndConvertToReadOnly() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Prepare TTS with the text
        tts.prepare(text: trimmed, url: nil, title: nil)
        
        // Convert to read-only mode
        isReadOnly = true
        saveTextToFile()
    }
    
    private func saveTextToFile() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            let docs = try FileManager.default.url(for: .documentDirectory,
                                                   in: .userDomainMask,
                                                   appropriateFor: nil,
                                                   create: true)
            let dir = docs.appendingPathComponent("SavedTexts", isDirectory: true)
            if !FileManager.default.fileExists(atPath: dir.path) {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }

            let name = "Text-\(Int(Date().timeIntervalSince1970)).txt"
            let fileURL = dir.appendingPathComponent(name)
            try trimmed.write(to: fileURL, atomically: true, encoding: .utf8)

            tts.currentTitle = name
            tts.currentURL = fileURL

            onSaved?(fileURL)
            dismiss()

        } catch {
            Logger.log("❌ Save failed: \(error.localizedDescription)")
        }
    }
}


#Preview {
    TextInputView(tts: TTSPlayer(), prefilledText: "Example prefilled text from a link...")
        .preferredColorScheme(.dark)
}

