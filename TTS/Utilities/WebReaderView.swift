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

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                WebViewContainer(webView: $webView, url: url)
                if isLoading {
                    ProgressView("Loading...")
                        .tint(.white)
                        .foregroundColor(.white)
                }
            }

            Button(action: extractTextAndListen) {
                Text("Save & Listen")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
            }
            .background(Color.black)
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private func extractTextAndListen() {
        // run JS to extract visible text from body
        webView.evaluateJavaScript("document.body.innerText") { result, error in
            guard error == nil, let text = result as? String, !text.isEmpty else {
                Logger.log("❌ Failed to extract text: \(error?.localizedDescription ?? "unknown")")
                return
            }

            DispatchQueue.main.async {
                dismiss()
                // send extracted text to parent
                onExtracted(text)
                // optional: start speaking automatically
                tts.startReading(text)
            }
        }
    }
}

private struct WebViewContainer: UIViewRepresentable {
    @Binding var webView: WKWebView
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        let req = URLRequest(url: url)
        webView.load(req)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {}
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {}
    }
}

extension Notification.Name {
    static let extractWebText = Notification.Name("extractWebText")
}
