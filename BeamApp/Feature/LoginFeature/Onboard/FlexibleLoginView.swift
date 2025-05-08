//
//  FlexibleView2.swift
//  BeamApp
//
//  Created by anonymous on 5/7/25.
//

import SwiftUI

struct FlexibleView<Data: Collection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    let content: (Data.Element) -> Content

    init(data: Data, spacing: CGFloat, alignment: HorizontalAlignment, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.spacing = spacing
        self.alignment = alignment
        self.content = content
    }

    var body: some View {
        VStack(alignment: alignment, spacing: spacing) {
            var width: CGFloat = 0
            var rows: [[Data.Element]] = [[]]
            GeometryReader { geometry in
                ForEach(computeRows(in: geometry.size.width), id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(row, id: \.self) { item in
                            content(item)
                        }
                    }
                }
            }
        }
    }

    private func computeRows(in totalWidth: CGFloat) -> [[Data.Element]] {
        var rows: [[Data.Element]] = [[]]
        var currentRowWidth: CGFloat = 0
        for item in data {
            let itemWidth: CGFloat = 80 // 대략적인 Chip/Tag의 최소 너비
            if currentRowWidth + itemWidth + spacing > totalWidth {
                rows.append([item])
                currentRowWidth = itemWidth + spacing
            } else {
                rows[rows.count - 1].append(item)
                currentRowWidth += itemWidth + spacing
            }
        }
        return rows
    }
}

struct WrapHStack<Item: Hashable, Content: View>: View {
    let items: [Item]
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    let content: (Item) -> Content

    var body: some View {
        FlexibleView(data: items, spacing: spacing, alignment: alignment, content: content)
    }
}

/*
// 사용 예시:
WrapHStack(items: artists, spacing: 8, alignment: .leading) { artist in
    Text(artist)
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(selectedArtists.contains(artist) ? Color.purple.opacity(0.8) : Color.white.opacity(0.2))
        .foregroundColor(selectedArtists.contains(artist) ? .white : .white.opacity(0.8))
        .cornerRadius(16)
        .onTapGesture {
            if selectedArtists.contains(artist) {
                selectedArtists.remove(artist)
            } else {
                selectedArtists.insert(artist)
            }
        }
}
*/ 
