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
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - Top Bar
            HStack {
                Button("Cancel") {
                    cancelAndDismiss()
                }
                .foregroundColor(.white)

                Spacer()

                Button("Save File") {
                    saveTextToFile()
                }
                .foregroundColor(.blue)
            }
            .padding()
            .background(Color.black)

            // MARK: - Editable area
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    tts.startReading(prefilled)
                }
            }
        }
    }

    // MARK: - Cancel Handler
    private func cancelAndDismiss() {
        tts.stop()
        dismiss()
    }

    // MARK: - Save Handler
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

// MARK: - Read-only Highlighted Text
struct ReadOnlyHighlightedText: View {
    let text: String
    @ObservedObject var tts: TTSPlayer

    var body: some View {
        ScrollView {
            Text(makeHighlightedAttributedString())
                .font(.system(size: 18))
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.black)
    }

    private func makeHighlightedAttributedString() -> AttributedString {
        var attr = AttributedString(text)

        guard tts.isSpeaking,
              let sentenceRange = (text as NSString).range(of: tts.currentSentenceText).toRange(),
              let wordRange = tts.currentWordRange
        else { return attr }

        let globalStart = sentenceRange.lowerBound + wordRange.location
        let globalEnd = min(globalStart + wordRange.length, text.count)
        guard globalStart < globalEnd else { return attr }

        let charStart = attr.characters.index(attr.characters.startIndex, offsetBy: globalStart)
        let charEnd = attr.characters.index(attr.characters.startIndex, offsetBy: globalEnd)
        let highlightRange = charStart..<charEnd

        attr[highlightRange].backgroundColor = .blue
        attr[highlightRange].foregroundColor = .black
        attr[highlightRange].font = .system(size: 18)
        return attr
    }
}

private extension NSRange {
    func toRange() -> Range<Int>? {
        guard location != NSNotFound else { return nil }
        return location ..< location + length
    }
}

#Preview {
    TextInputView(tts: TTSPlayer(), prefilledText: "Example prefilled text from a link...")
        .preferredColorScheme(.dark)
}
