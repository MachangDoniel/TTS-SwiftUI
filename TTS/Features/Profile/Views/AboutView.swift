//
//  AboutView.swift
//  TTS
//
//  Created by Doniel Tripura on 10/19/25.
//


import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                
                // MARK: - App Info
                HStack(alignment: .center, spacing: 16) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 70, height: 70)
                        .overlay(
                            Image(systemName: "app.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white.opacity(0.7))
                        )
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TTS")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        Text("Version: \(displayVersion)")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                        HStack(spacing: 4) {
                            Text("Developed by:")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.5))
                            Text("Neural Sound")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    Spacer()
                }
                .padding()
                .background(Color(red: 0.13, green: 0.13, blue: 0.14))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                // MARK: - Customer Support
                VStack(alignment: .leading, spacing: 8) {
                    Text("Customer Support")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Email:")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                            if let emailURL = URL(string: "mailto:\(AppURLs.support)") {
                                Link(AppURLs.support.absoluteString, destination: emailURL)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.9))
                            } else {
                                Text(AppURLs.support.absoluteString)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                        HStack {
                            Text("Website:")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                            if let url = URL(string: AppURLs.website.absoluteString) {
                                Link(AppURLs.website.absoluteString, destination: url)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.9))
                            } else {
                                Text(AppURLs.website.absoluteString)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.13, green: 0.13, blue: 0.14))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                // MARK: - Third Party Library
                VStack(alignment: .leading, spacing: 10) {
                    Text("Third Party Library")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("""
                    It is a long established fact that a reader will be distracted by the readable content of a page when looking at its layout. The point of using Lorem Ipsum is that it has a more-or-less normal distribution of letters, as opposed to using 'Content here, content here', making it look like readable English. Many desktop publishing packages and web pages...
                    """)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.leading)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.13, green: 0.13, blue: 0.14))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension AboutView {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }
    private var displayVersion: String {
        #if DEBUG
        return buildNumber.isEmpty ? appVersion : "\(appVersion)(\(buildNumber))"
        #else
        return appVersion
        #endif
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
    .preferredColorScheme(.dark)
}
