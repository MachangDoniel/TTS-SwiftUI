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
