//
//  EmptyLibraryView.swift
//  TTS
//
//  Created by Doniel Tripura on 10/19/25.
//

import SwiftUI

// MARK: - Empty State View
struct EmptyLibraryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)
            Image(systemName: "tray.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 90, height: 90)
                .foregroundColor(.gray.opacity(0.7))
                .padding(.bottom, 10)

            Text("Add your first book to get started!")
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .medium))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}
