//
//  InAppBrowserView.swift
//  TTS
//
//  Created on 11/23/25.
//

import SwiftUI
import WebKit
import Combine

struct InAppBrowserView: View {
    let url: URL
    let title: String
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var webView = WKWebView()
    @State private var isLoading = true
    @State private var pageTitle: String = ""
    @State private var canGoBack = false
    @State private var canGoForward = false
    @StateObject private var coordinator = WebViewNavigationCoordinator()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                ZStack {
                    WebViewContainer(
                        webView: $webView,
                        url: url,
                        isLoading: $isLoading,
                        pageTitle: $pageTitle
                    )
                    .ignoresSafeArea(edges: .bottom)
                    
                    if isLoading {
                        ProgressView("Loading...")
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .onAppear {
                    setupWebView()
                }
                .onReceive(coordinator.$navigationStateChanged) { _ in
                    updateNavigationState()
                    pageTitle = webView.title ?? pageTitle
                    isLoading = webView.isLoading
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(pageTitle.isEmpty ? title : pageTitle)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        if canGoBack {
                            webView.goBack()
                        } else {
                            dismiss()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text(canGoBack ? "Back" : "Done")
                        }
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func setupWebView() {
        coordinator.configure(for: webView)
        updateNavigationState()
    }
    
    private func updateNavigationState() {
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
    }
}

// MARK: - Navigation Coordinator
private class WebViewNavigationCoordinator: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var navigationStateChanged = false
    private weak var webView: WKWebView?
    
    func configure(for webView: WKWebView) {
        self.webView = webView
        webView.navigationDelegate = self
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        navigationStateChanged.toggle()
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if let view = self.webView, view == webView {
            // Trigger loading state start
            navigationStateChanged.toggle()
        } else {
            navigationStateChanged.toggle()
        }
    }
    
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        navigationStateChanged.toggle()
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        navigationStateChanged.toggle()
    }
}

#Preview {
    InAppBrowserView(
        url: URL(string: "https://apple.com")!,
        title: "Apple"
    )
}
