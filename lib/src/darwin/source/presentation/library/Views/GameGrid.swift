// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

#if os(macOS)
import PresentationStyles
import SwiftUI

/// The games as a grid of tiles, as the design's `Mac-LibraryGrid` draws it: each tile its game's initials
/// in place of artwork, its console's chip (PS1, or "?" while a disc can't be read), a PS-EXE's mark, its
/// name and when it was last played. A click selects a tile, ringed in the accent; a double-click plays it.
struct GameGrid: View {
    @Bindable var viewModel: LibraryViewModel

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: Metrics.layout.tile, maximum: Metrics.layout.tile), spacing: Metrics.space5, alignment: .leading)],
                alignment: .leading, spacing: Metrics.space5
            ) {
                ForEach(viewModel.rows) { row in
                    Button { viewModel.select(row.id) } label: {
                        GameTile(row: row, isSelected: row.id == viewModel.selection)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture(count: 2).onEnded { viewModel.play(row.id) })
                    .accessibilityLabel(row.accessibilityLabel)
                    .accessibilityAddTraits(row.id == viewModel.selection ? .isSelected : [])
                }
            }
            .padding(Metrics.space5)
        }
        .background(Palette.content)
        .accessibilityLabel(LibraryText.gamesLabel)
    }
}

/// One game's tile: the box of initials with its chips, then the name and the line under it.
private struct GameTile: View {
    let row: GameRow
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.space1) {
            art
            Text(row.name)
                .textStyle(.body, weight: .semibold)
                .lineLimit(1)
            Text(row.tileCaption)
                .textStyle(.caption)
                .foregroundStyle(Palette.secondaryText)
                .lineLimit(1)
        }
        .foregroundStyle(Palette.text)
        .frame(width: Metrics.layout.tile, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// The box standing in for artwork: the initials, the console's chip at its top corner and a known
    /// serial, or a PS-EXE's mark, at its bottom.
    private var art: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.radiusCard)
        return shape.fill(Palette.raised)
            .overlay {
                if isSelected {
                    // The design's ring: two points of the accent, the hairline's width doubled.
                    shape.strokeBorder(Palette.accent, lineWidth: Metrics.space1 / 2)
                } else {
                    shape.strokeBorder(Palette.separator)
                }
            }
            .overlay {
                Text(row.initials)
                    .font(Typography.screenSymbol)
                    .bold()
                    .foregroundStyle(Palette.secondaryText)
            }
            .overlay(alignment: .topTrailing) {
                Chip(row.consoleBadge)
                    .padding(Metrics.space2)
            }
            .overlay(alignment: .bottomLeading) {
                Text(row.serialBadge)
                    .textStyle(.caption, monospaced: true)
                    .foregroundStyle(Palette.secondaryText)
                    .padding(.horizontal, Metrics.space3)
                    .padding(.bottom, Metrics.space2)
            }
            .frame(width: Metrics.layout.tile, height: Metrics.layout.tile)
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("Grid") {
    GameGrid(viewModel: PreviewLibrary.grid())
        .frame(width: Metrics.layout.windowWidth - Metrics.layout.sidebar, height: Metrics.layout.windowHeight - Metrics.layout.toolbar)
}
#endif
#endif
