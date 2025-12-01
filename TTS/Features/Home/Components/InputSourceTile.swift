//
//  ImportTile.swift
//  TTS
//
//  Created by Doniel Tripura on 10/19/25.
//

import SwiftUI

enum TileStatus {
    case active
    case comingSoon
    case disabled
}

struct InputSourceTile: View {
    var icon: String
    var title: String
    var tint: Color = .white
    var status: TileStatus = .active
    var action: (() -> Void)?

    var body: some View {
        if status == .disabled {
            EmptyView()
        } else {
            ZStack(alignment: .topTrailing) {

                Button(action: {
                    if status == .active {
                        action?()
                    }
                }) {
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
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(10)
                    }
                    .opacity(status == .comingSoon ? 0.8 : 1.0)
                }
                .buttonStyle(.plain)
                .disabled(status != .active)

                // Coming Soon badge
                if status == .comingSoon {
                    Text("Coming Soon")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(alignment: .trailing)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.myPrimaryColor)
                        .cornerRadius(10)
                        .offset(y: 0)
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
    }
}


#Preview {
    ZStack {
        Color.black.ignoresSafeArea();
        VStack {
            HStack {
                InputSourceTile(icon: "folder.fill", title: "Files")
                InputSourceTile(icon: "folder.fill", title: "Files")
                InputSourceTile(icon: "folder.fill", title: "Files")
                InputSourceTile(icon: "folder.fill", title: "Files")
            }
            HStack {
                InputSourceTile(icon: "folder.fill", title: "Files")
                InputSourceTile(icon: "folder.fill", title: "Files")
                InputSourceTile(icon: "folder.fill", title: "Files")
                InputSourceTile(icon: "folder.fill", title: "Files")
            }
            HStack {
                InputSourceTile(icon: "folder.fill", title: "Files", status: .comingSoon)
                InputSourceTile(icon: "folder.fill", title: "Files")
                InputSourceTile(icon: "folder.fill", title: "Files")
                InputSourceTile(icon: "folder.fill", title: "Files")
            }
            HStack {
                InputSourceTile(icon: "folder.fill", title: "Files")
                InputSourceTile(icon: "folder.fill", title: "Files")
                InputSourceTile(icon: "folder.fill", title: "Files")
                InputSourceTile(icon: "folder.fill", title: "Files")
            }
            
        }
    }
}
