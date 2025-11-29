//
//  HeaderPager.swift
//  TTS
//
//  Created by Doniel Tripura on 10/5/25.
//

import SwiftUI

enum BannerAssets {
    static let scan_banner_img = "voice_banner"
    static let link_banner_img = "voice_banner_x2"
    static let text_banner_img = "voice_banner_x3"
}

struct BannerItem: Identifiable {
    let id = UUID()
    let imageName: String
    let buttonTitle: String
    let onTap: () -> Void
}

struct HeaderPager: View {
    var items: [BannerItem]

    var body: some View {
        TabView {

            ForEach(items) { item in
                BannerSlide(
                    imageName: item.imageName,
                    buttonTitle: item.buttonTitle,
                    onTap: item.onTap
                )
            }
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .never))
    }
}

#Preview {
    HeaderPager(items: [
        BannerItem(
            imageName: BannerAssets.scan_banner_img,
            buttonTitle: "Try Now",
            onTap: { print("Scan tapped") }
        ),
        BannerItem(
            imageName: BannerAssets.link_banner_img,
            buttonTitle: "Listen Now",
            onTap: { print("Link tapped") }
        ),
        BannerItem(
            imageName: BannerAssets.text_banner_img,
            buttonTitle: "Try Now",
            onTap: { print("Text tapped") }
        )
    ])
    .background(Color.black.ignoresSafeArea())
}
