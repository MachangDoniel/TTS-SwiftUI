//
//  ShareSheet.swift
//  TTS
//
//  Created by Doniel Tripura on 10/19/25.
//

import SwiftUI

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
