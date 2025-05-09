//
//  OnboardTasteView2.swift
//  BeamApp
//
//  Created by anonymous on 5/7/25.
//

import SwiftUI

struct OnboardTasteView: View {
    let onNext: () -> Void
    @State private var selectedArtists: Set<String> = []
    @State private var selectedGenres: Set<String> = []
    let artists = ["정진태", "Coldplay", "Bruno Mars", "Lenny", "Taylor Swift", "The 1975", "SZA", "ADOY"]
    let genres = ["발라드", "댄스", "힙합", "록"]

    let chipHorizontalPadding: CGFloat = 16
    let chipVerticalPadding: CGFloat = 8
    let chipHeight: CGFloat = 32
    let chipSpacing: CGFloat = 8
    let rowSpacing: CGFloat = 8

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 20) {
                Spacer(minLength: 80)
                VStack(spacing: 16) {
                    Text("특별한 당신의 취향,\n소곤소곤 들려주세요.")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, 0)
                .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 16) {
                    Text("가수로 찾기")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                    ChipGridView(
                        data: artists.map { ChipItem(id: $0, name: $0) },
                        selectedItems: $selectedArtists,
                        chipHorizontalPadding: chipHorizontalPadding,
                        chipVerticalPadding: chipVerticalPadding,
                        chipHeight: chipHeight,
                        chipSpacing: chipSpacing,
                        rowSpacing: rowSpacing
                    )
                }
                .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 16) {
                    Text("장르로 찾기")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                    ChipGridView(
                        data: genres.map { ChipItem(id: $0, name: $0) },
                        selectedItems: $selectedGenres,
                        chipHorizontalPadding: chipHorizontalPadding,
                        chipVerticalPadding: chipVerticalPadding,
                        chipHeight: chipHeight,
                        chipSpacing: chipSpacing,
                        rowSpacing: rowSpacing
                    )
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 100)
            }
            Button("다음 →", action: onNext)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 32)
                .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(gradient: Gradient(colors: [Color(red: 155/255, green: 78/255, blue: 166/255), Color(red: 224/255, green: 122/255, blue: 175/255)]), startPoint: .top, endPoint: .bottom))
        .ignoresSafeArea()
    }
}

struct ChipItem: ChipData, Identifiable {
    public let id: String
    public let name: String

    var description: String { name }

    func chipWidth(horizontalPadding: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 14)
        let attributes = [NSAttributedString.Key.font: font]
        let size = (name as NSString).size(withAttributes: attributes)
        return size.width + horizontalPadding * 2
    }
}

struct ChipGridView<Item: ChipData, Data: RandomAccessCollection>: View where Data.Element == Item {
    let data: Data
    @Binding var selectedItems: Set<Item.ID>
    let chipHorizontalPadding: CGFloat
    let chipVerticalPadding: CGFloat
    let chipHeight: CGFloat
    let chipSpacing: CGFloat
    let rowSpacing: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let rows = computeRows(in: totalWidth)

            VStack(alignment: .leading, spacing: rowSpacing) {
                ForEach(rows, id: \.self) { row in
                    HStack(spacing: chipSpacing) {
                        ForEach(row) { item in
                            chip(for: item)
                        }
                    }
                }
            }
            .frame(height: CGFloat(rows.count) * (chipHeight + rowSpacing) - rowSpacing)
        }
    }

    private func computeRows(in totalWidth: CGFloat) -> [[Item]] {
        var rows: [[Item]] = [[]]
        var currentRowWidth: CGFloat = 0

        for item in data {
            let itemWidth = item.chipWidth(horizontalPadding: chipHorizontalPadding)
            if currentRowWidth + itemWidth + chipSpacing > totalWidth {
                rows.append([item])
                currentRowWidth = itemWidth + itemWidth + chipSpacing
            } else {
                if let lastRow = rows.last {
                    rows[rows.count - 1].append(item)
                    currentRowWidth += itemWidth + chipSpacing
                }
            }
        }
        return rows
    }

    @ViewBuilder
    private func chip(for item: Item) -> some View {
        Text(item.description)
            .padding(.horizontal, chipHorizontalPadding)
            .padding(.vertical, chipVerticalPadding)
            .frame(height: chipHeight, alignment: .center)
            .background(selectedItems.contains(item.id) ? Color.purple.opacity(0.8) : Color.white.opacity(0.2))
            .foregroundColor(selectedItems.contains(item.id) ? .white : .white.opacity(0.8))
            .cornerRadius(16)
            .onTapGesture {
                if selectedItems.contains(item.id) {
                    selectedItems.remove(item.id)
                } else {
                    selectedItems.insert(item.id)
                }
            }
    }
}

protocol ChipData: Hashable, Identifiable {
    var id: String { get }
    func chipWidth(horizontalPadding: CGFloat) -> CGFloat
    var description: String { get }
}
