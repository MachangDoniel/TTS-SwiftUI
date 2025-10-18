import SwiftUI

struct HeaderSlide: View {
    var onTryForFree: (() -> Void)?

    var body: some View {
        ZStack(alignment: .leading) {
            // Background stack: gradient + glow + sheen
            ZStack {
                // 1) Base gradient (multi-stop for smoother blend)
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(red: 0.38, green: 0.32, blue: 0.98), location: 0.0),
                        .init(color: Color(red: 0.33, green: 0.61, blue: 0.99), location: 1.0)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // 2) Soft radial glow toward the center-right
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.20),
                        Color.white.opacity(0.00)
                    ]),
                    center: .init(x: 0.75, y: 0.35),
                    startRadius: 10,
                    endRadius: 260
                )

                // 3) Subtle top sheen
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.10),
                        Color.white.opacity(0.00)
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.top, 0)
            .ignoresSafeArea(edges: .top)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Listen with the most\nadvanced AI Voices")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: { onTryForFree?() }) {
                        Text("Try for free")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                Spacer()
                Image(systemName: "book.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .foregroundColor(Color.white.opacity(0.9))
                    .padding(.top, 12)
                    .padding(.trailing, 24)
            }
            .padding(.horizontal, 32)
        }
    }
}

#Preview {
    ZStack { Color.black.ignoresSafeArea(); HeaderSlide(onTryForFree: {}) }
}
