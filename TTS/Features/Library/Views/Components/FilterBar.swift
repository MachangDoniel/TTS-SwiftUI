//
//  FilterBar.swift
//  TTS
//
//  Created by Doniel Tripura on 10/19/25.
//

import SwiftUI


// MARK: - Filter Bar
struct FilterBar: View {
    @Binding var selected: FileCategory

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(FileCategory.allCases, id: \.self) { filter in
                    Button {
                        selected = filter
                    } label: {
                        Text(filter.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 14)
                            .background(
                                selected == filter ?
                                Color.blue.opacity(0.9) :
                                Color.white.opacity(0.1)
                            )
                            .clipShape(Capsule())
                            .foregroundColor(selected == filter ? .white : .white.opacity(0.8))
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }
}
