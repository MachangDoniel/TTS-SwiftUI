//
//  HeaderPager.swift
//  TTS
//
//  Created by Doniel Tripura on 10/5/25.
//

import SwiftUI
import Combine

struct BannerItem: Identifiable {
    let id: String
    let imageName: String
    let buttonTitle: String
    let onTap: () -> Void
}

struct HeaderPager: View {
    var items: [BannerItem]
    
    private var loopItems: [BannerItem] {
        guard let first = items.first else { return items }
        return items + [first]
    }
    
    @State private var selection: Int = 0
    let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    var body: some View {
        TabView(selection: $selection) {
            ForEach(Array(loopItems.enumerated()), id: \.offset) { index, item in
                BannerSlide(
                    imageName: item.imageName,
                    buttonTitle: item.buttonTitle,
                    onTap: item.onTap
                )
                .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .overlay(
            HStack(spacing: 8) {
                ForEach(0..<items.count, id: \.self) { i in
                    Circle()
                        .fill((selection % max(items.count, 1)) == i ? Color.white : Color.white.opacity(0.4))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.bottom, 24)
            , alignment: .bottom
        )
        .onReceive(timer) { _ in
            guard items.count > 1 else { return }
            let lastIndex = loopItems.count - 1
            withAnimation {
                if selection < lastIndex {
                    selection += 1
                } else {
                    // We are on the extra (cloned) last page. Advance to it with animation, then jump back to 0 without animation.
                    selection = lastIndex
                }
            }
            // If we've reached the extra page, immediately reset to 0 without animation to keep rightward direction.
            if selection == loopItems.count - 1 {
                DispatchQueue.main.async {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        selection = 0
                    }
                }
            }
        }
        .onAppear {
            selection = 0
        }
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
