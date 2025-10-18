import SwiftUI

struct ImportTile: View {
    var icon: String
    var title: String
    var tint: Color = .white
    var action: (() -> Void)?

    var body: some View {
        Button(action: { action?() }) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.14, green: 0.14, blue: 0.15))
                VStack(spacing: 6) {
                    if let uiImage = UIImage(named: icon) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .foregroundColor(tint)
                    }
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(10)
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
    }
}


#Preview {
    ZStack {
        Color.black.ignoresSafeArea();
        VStack {
            HStack {
                ImportTile(icon: "folder.fill", title: "Files")
                ImportTile(icon: "folder.fill", title: "Files")
                ImportTile(icon: "folder.fill", title: "Files")
                ImportTile(icon: "folder.fill", title: "Files")
            }
            HStack {
                ImportTile(icon: "folder.fill", title: "Files")
                ImportTile(icon: "folder.fill", title: "Files")
                ImportTile(icon: "folder.fill", title: "Files")
                ImportTile(icon: "folder.fill", title: "Files")
            }
            HStack {
                ImportTile(icon: "folder.fill", title: "Files")
                ImportTile(icon: "folder.fill", title: "Files")
                ImportTile(icon: "folder.fill", title: "Files")
                ImportTile(icon: "folder.fill", title: "Files")
            }
            HStack {
                ImportTile(icon: "folder.fill", title: "Files")
                ImportTile(icon: "folder.fill", title: "Files")
                ImportTile(icon: "folder.fill", title: "Files")
                ImportTile(icon: "folder.fill", title: "Files")
            }
            
        }
    }
}
