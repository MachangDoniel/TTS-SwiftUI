//
//  FileViewer.swift
//  TTS
//
//  Created by Doniel Tripura on 10/5/25.
//

import SwiftUI
import PDFKit
import AVFAudio

struct FileViewer: View {
    let fileURL: URL
    @ObservedObject var tts: TTSPlayer
    
    init(fileURL: URL, tts: TTSPlayer) {
        self.fileURL = fileURL
        self._tts = ObservedObject(initialValue: tts)
    }
    
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
                            tts.currentTitle = fileURL.lastPathComponent
                            if tts.currentURL != fileURL {
                                tts.stop()
                                tts.currentURL = fileURL
                                tts.currentIndex = 0
                                tts.currentWordRange = nil
                                tts.currentWordInSentence = ""
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    tts.startReading(content)
                                }
                            } else if tts.sentences.isEmpty || tts.currentSentenceText.isEmpty || !tts.isSpeaking {
                                tts.currentIndex = 0
                                tts.currentWordRange = nil
                                tts.currentWordInSentence = ""
                                tts.startReading(content)
                            }
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
            // Only hard-stop if we’re switching to a different file
            if tts.currentURL != fileURL {
                tts.stop()
            }
            if fileURL.pathExtension.lowercased() == "pdf" {
                let text = extractText(from: fileURL)
                extractedText = text
                tts.currentTitle = fileURL.lastPathComponent
                // Restart if a new file is selected (different URL)
                if tts.currentURL != fileURL {
                    // ✅ Hard reset: replace the AVSpeechSynthesizer to prevent leftover callbacks
                    tts.synthesizer.delegate = nil
                    tts.synthesizer = AVSpeechSynthesizer()
                    tts.synthesizer.delegate = tts

                    // Reset state before speaking
                    tts.currentURL = fileURL
                    tts.currentIndex = 0
                    tts.currentWordRange = nil
                    tts.currentWordInSentence = ""

                    // Give a short delay to allow any UI updates before speaking
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        tts.startReading(text)
                    }
                } else if tts.sentences.isEmpty || tts.currentSentenceText.isEmpty || !tts.isSpeaking {
                    // Start if nothing is currently speaking
                    tts.startReading(text)
                }
            }
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
//    FileViewer(fileURL: URL(fileURLWithPath: "/path/to/sample.pdf"), tts: TTSPlayer())
//}
