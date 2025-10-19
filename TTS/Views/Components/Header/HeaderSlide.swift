//
//  HeaderSlide.swift
//  TTS
//
//  Created by Doniel Tripura on 10/5/25.
//

import SwiftUI

struct HeaderSlide: View {
    var onTryForFree: (() -> Void)?

    var body: some View {
        ZStack(alignment: .leading) {
            // Background gradient with correct corner masking
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.42, green: 0.36, blue: 0.98),
                    Color(red: 0.36, green: 0.63, blue: 0.99)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, 16)
            .frame(height: 140)
            .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)

            // Overlay content (inside same rounded shape)
            HStack {
                // Left side: text + button
                VStack(alignment: .leading, spacing: 12) {
                    Text("Listen with the most advanced\nAI Voices uh")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                        .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 2)

                    Spacer()
                    
                    Button(action: { onTryForFree?() }) {
                        Text("Try now")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .padding(.leading, 20)
                .padding(.vertical, 20)

                Spacer()

                // Right side: stacked 3 portraits diagonally
                ZStack {
                    // Bottom small portrait
                    Image("person3")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 26, height: 26)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 0))
                        .shadow(radius: 3)
                        .offset(x: 0, y: 48)

                    // Middle portrait
                    Image("person2")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 38, height: 38)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 0))
                        .shadow(radius: 3)
                        .offset(x: -40, y: 30)

                    // Top main portrait
                    Image("person1")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 74, height: 74)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 0))
                        .shadow(radius: 4)
                        .offset(x: 10, y: -10)
                }
                .padding(.trailing, 24)
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 140)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        HeaderSlide(onTryForFree: {})
    }
}
