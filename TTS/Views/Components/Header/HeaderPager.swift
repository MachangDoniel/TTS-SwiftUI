//
//  HeaderPager.swift
//  TTS
//
//  Created by Doniel Tripura on 10/5/25.
//

import SwiftUI

struct HeaderPager: View {
    var onTryForFree: (() -> Void)?

    var body: some View {
        TabView {
            HeaderSlide(onTryForFree: onTryForFree)
            HeaderSlide(onTryForFree: onTryForFree)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .never))
    }
}

#Preview {
    ZStack { Color.black.ignoresSafeArea(); HeaderPager(onTryForFree: {}) }
}
