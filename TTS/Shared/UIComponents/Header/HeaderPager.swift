//
//  HeaderPager.swift
//  TTS
//
//  Created by Doniel Tripura on 10/5/25.
//

import SwiftUI

struct BannerItem: Identifiable {
    let id: String
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
            id: "scan-banner",
            imageName: BannerAssets.scan_banner_img,
            buttonTitle: "Try Now",
            onTap: { print("Scan tapped") }
        ),
        BannerItem(
            id: "link-banner",
            imageName: BannerAssets.link_banner_img,
            buttonTitle: "Listen Now",
            onTap: { print("Link tapped") }
        ),
        BannerItem(
            id: "text-banner",
            imageName: BannerAssets.text_banner_img,
            buttonTitle: "Try Now",
            onTap: { print("Text tapped") }
        )
    ])
    .background(Color.black.ignoresSafeArea())
}
