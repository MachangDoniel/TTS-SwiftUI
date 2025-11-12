import SwiftUI

struct LoadingOverlay: ViewModifier {
    @Binding var isLoading: Bool
    var message: String

    func body(content: Content) -> some View {
        ZStack {
            content
            if isLoading {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(.circular)
                    Text(message)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

extension View {
    func loadingOverlay(_ isLoading: Binding<Bool>, message: String = "Please wait…") -> some View {
        modifier(LoadingOverlay(isLoading: isLoading, message: message))
    }
}
