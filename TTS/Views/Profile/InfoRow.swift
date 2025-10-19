//
//  InfoRow.swift
//  TTS
//
//  Created by Doniel Tripura on 10/19/25.
//

import SwiftUI

// MARK: - Reusable Components

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.white.opacity(0.9))
            Spacer()
            Text(value)
                .foregroundColor(.white.opacity(0.7))
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.horizontal)
        .frame(height: 48)
    }
}
