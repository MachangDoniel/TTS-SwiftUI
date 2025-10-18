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
        .frame(height: 220)
    }
}

#Preview {
    ZStack { Color.black.ignoresSafeArea(); HeaderPager(onTryForFree: {}) }
}
