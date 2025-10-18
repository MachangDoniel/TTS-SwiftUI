import SwiftUI

struct ImportSectionView: View {
    var onAction: (ImportSource) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Import & listen")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.top, 20)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 16) {
                ForEach(ImportSource.defaultOrder) { source in
                    ImportTile(icon: source.systemIcon, title: source.title, tint: source.tint) {
                        onAction(source)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color(red: 0.10, green: 0.10, blue: 0.11))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 16)
    }
}

#Preview {
    ZStack { Color.black.ignoresSafeArea(); ImportSectionView { _ in } }
}
