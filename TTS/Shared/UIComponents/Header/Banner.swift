//
//  Banner.swift
//  TTS
//
//  Created by Doniel Tripura on 12/8/25.
//

import SwiftUI

struct Banner: View {
    var imageName: String
    var buttonTitle: String?
    var onTap: (() -> Void)?

    var body: some View {
        ZStack {
            // Full–width banner image
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
                .padding(.horizontal, 16)
                .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)

            if let buttonTitle = buttonTitle {
                VStack {
                    Spacer()   // Push to bottom

                    HStack {
                        Button(action: { onTap?() }) {
                            Text(buttonTitle)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Color.white.opacity(0.95))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }

                        Spacer()   // Push button to the left
                    }
                    .padding(.leading, 32)
                    .padding(.bottom, 20)
                }
            }
        }
        .frame(height: 140)
        .contentShape(Rectangle()) // entire banner tappable
        .onTapGesture {
            onTap?()
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        Banner(imageName: "voice_banner", buttonTitle: "Try now", onTap: {})
    }
}
