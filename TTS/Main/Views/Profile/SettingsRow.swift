//
//  SettingsRow.swift
//  TTS
//
//  Created by Doniel Tripura on 10/19/25.
//

import SwiftUI

struct SettingsRow: View {
    let title: String
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.horizontal)
            .frame(height: 48)
        }
    }
}
