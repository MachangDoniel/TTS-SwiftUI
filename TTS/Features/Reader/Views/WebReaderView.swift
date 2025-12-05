//
//  WebReaderView.swift
//  TTS
//
//  Created by Doniel Tripura on 10/25/25.
//

import SwiftUI
import WebKit

struct WebReaderView: View {
    let url: URL
    var onExtracted: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var tts: TTSPlayer

    @State private var webView = WKWebView()
    @State private var isLoading = true
    @State private var pageTitle: String = ""

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                WebViewContainer(webView: $webView, url: url, isLoading: $isLoading, pageTitle: $pageTitle)
                    .ignoresSafeArea(edges: .bottom)

                if isLoading {
                    ProgressView("Loading...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            Button(action: extractTextAndListen) {
                Label("Save & Listen", systemImage: "play.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.myPrimaryColor.cornerRadius(12))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
            }
            .background(Color.black)
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

extension WebReaderView {
    // MARK: - Extract and Listen
    private func extractTextAndListen() {
        webView.evaluateJavaScript("document.title") { result, _ in
            if let title = result as? String {
                pageTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        webView.evaluateJavaScript("document.body.innerText") { result, error in
            guard error == nil, let text = result as? String, !text.isEmpty else {
                Logger.error(error ?? NSError(domain: "WebReader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to extract web text"]))
                return
            }

            DispatchQueue.main.async {
                self.dismiss()
                // Stop any ongoing playback and prepare the new content without auto-start
                tts.prepareNewFileOnly(text: text, url: self.url, title: self.pageTitle)
                onExtracted(text)
                Logger.log("✅ Extracted text from web page (\(text.count) chars) — title: \(self.pageTitle)")
            }
        }
    }
}
