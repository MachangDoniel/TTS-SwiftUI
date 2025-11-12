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
                    .background(Color.blue.cornerRadius(12))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
            }
            .background(Color.black)
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

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
                dismiss()
                tts.stop() // ✅ stop current speech before new one
                onExtracted(text)
                tts.startReading(text, title: pageTitle)
                Logger.log("✅ Extracted text from web page (\(text.count) chars) — title: \(pageTitle)")
            }
        }
    }
}

private struct WebViewContainer: UIViewRepresentable {
    @Binding var webView: WKWebView
    let url: URL
    @Binding var isLoading: Bool
    @Binding var pageTitle: String

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, pageTitle: $pageTitle)
    }

    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool
        @Binding var pageTitle: String

        init(isLoading: Binding<Bool>, pageTitle: Binding<String>) {
            _isLoading = isLoading
            _pageTitle = pageTitle
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
            webView.evaluateJavaScript("document.title") { result, _ in
                if let title = result as? String {
                    self.pageTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            isLoading = false
            Logger.error(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            isLoading = false
            Logger.error(error)
        }
    }
}
