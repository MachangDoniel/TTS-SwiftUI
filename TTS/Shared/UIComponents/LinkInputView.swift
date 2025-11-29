//
//  LinkInputView.swift
//  TTS
//
//  Created by Doniel Tripura on 10/25/25.
//


import SwiftUI

struct LinkInputView: View {
    @Binding var isPresented: Bool
    @Binding var linkText: String
    var onLinkConfirmed: (URL) -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack {
            // MARK: - Drag handle
            Capsule()
                .fill(Color.gray.opacity(0.5))
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            Spacer(minLength: 140)

            // MARK: - Input Field
            TextField("any-website.com/...", text: $linkText)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .focused($isFocused)
                .padding()
                .background(Color(.systemGray6).opacity(0.2))
                .cornerRadius(12)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        isFocused = true
                    }
                }

            Spacer()

            // MARK: - Listen Button
            Button(action: {
                let trimmed = linkText.trimmingCharacters(in: .whitespacesAndNewlines)

                // ✅ Accept both full and partial URLs (auto-append https:// if missing)
                var finalString = trimmed
                if !trimmed.hasPrefix("http://") && !trimmed.hasPrefix("https://") {
                    finalString = "https://\(trimmed)"
                }

                guard let url = URL(string: finalString) else {
                    Logger.log("❌ Invalid link: \(finalString)")
                    return
                }

                isPresented = false
                onLinkConfirmed(url)
            }) {
                Text("Listen")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.myPrimaryColor)
                    .cornerRadius(12)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
            .disabled(linkText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

#Preview {
    LinkInputView(
        isPresented: .constant(true),
        linkText: .constant(""),
        onLinkConfirmed: { _ in }
    )
}
