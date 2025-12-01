//
//  HomeBannerView.swift
//  TTS
//
//  Created by Doniel Tripura on 12/2/25.
//

import SwiftUI


struct HomeBannerView: View {
    var onScan: (() -> Void)?
    var onPasteLink: (() -> Void)?
    var onTypeText: (() -> Void)?
    
    // Store items in @State so they're only created once
    @State private var items: [BannerItem] = []
    
    var body: some View {
        HeaderPager(items: items)
            .frame(height: 160)
            .padding(.top, 8)
            .onAppear {
                // Only create items once when view appears
                if items.isEmpty {
                    items = [
                        BannerItem(
                            id: BannerAssets.scan_banner_img,
                            imageName: BannerAssets.scan_banner_img,
                            buttonTitle: "Try Now",
                            onTap: { onScan?() }
                        ),
                        BannerItem(
                            id: BannerAssets.link_banner_img,
                            imageName: BannerAssets.link_banner_img,
                            buttonTitle: "Listen Now",
                            onTap: { onPasteLink?() }
                        ),
                        BannerItem(
                            id: BannerAssets.text_banner_img,
                            imageName: BannerAssets.text_banner_img,
                            buttonTitle: "Try Now",
                            onTap: { onTypeText?() }
                        )
                    ]
                }
            }
    }
}
