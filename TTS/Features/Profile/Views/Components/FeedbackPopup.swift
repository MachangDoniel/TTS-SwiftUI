//
//  FeedbackPopup.swift
//  TTS
//
//  Created by Doniel Tripura on 11/29/25.
//


import SwiftUI

struct FeedbackPopup: View {
    @Binding var isPresented: Bool
    var title: String
    @State private var text: String = ""
    var onSubmit: (String) -> Void

    var body: some View {
        if isPresented {
            ZStack {
                // Dimmed background
                Color.black.opacity(0.45)
                    .ignoresSafeArea()

                // Alert card
                VStack(spacing: 0) {

                    // MARK: Title
                    Text(title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.top, 20)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)

                    // MARK: Text box
                    ZStack(alignment: .topLeading) {
                        // Background
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.12, green: 0.12, blue: 0.13)) // darker field bg
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1) // slightly brighter border

                        // Placeholder
                        if text.isEmpty {
                            Text("Write Here...")
                                .foregroundColor(Color.white.opacity(0.35))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                        }

                        // Editor
                        TextEditor(text: $text)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .foregroundColor(.white)
                            .background(Color.white.opacity(0.05))
                    }
                    .frame(height: 150)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                    // MARK: Divider above buttons
                    Divider()
                        .background(Color.white.opacity(0.2))

                    // MARK: Button row
                    HStack(spacing: 0) {
                        Button {
                            isPresented = false
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 17))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .foregroundColor(.myPrimaryColor)

                        Divider()
                            .background(Color.white.opacity(0.2))

                        Button {
                            onSubmit(text)
                            isPresented = false
                        } label: {
                            Text("Submit")
                                .font(.system(size: 17, weight: .semibold))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .foregroundColor(.myPrimaryColor)
                    }
                    .frame(height: 50)
                }
                .frame(width: 320)
                .background(Color(red: 0.11, green: 0.11, blue: 0.13)) // card bg
                .cornerRadius(22)
                .shadow(radius: 25)
            }
            .transition(.opacity)
        }
    }
}

