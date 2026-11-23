// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

#if os(macOS)
import PresentationStyles
import SwiftUI

/// The games as a table, as the design's `Mac-TodayLibrary` draws it: Name, with its symbol and a missing
/// file's chip, then Console, Serial, Format, Size and Last played — the columns the width leaves
/// (`LibraryLayout`). A row is selected with a click or the arrow keys, and a double-click or Return
/// plays it. At the Today level a disc's console and serial read "Unknown".
struct GameTable: View {
    @Bindable var viewModel: LibraryViewModel
    /// The columns the width leaves, in order.
    let columns: [LibraryLayout.Column]

    var body: some View {
        // A column is left out by drawing the table without it: a table's columns can be chosen by a
        // condition only from macOS 14.4, and the window's least width drops Format and Last played.
        if columns.contains(.format) {
            table { name; console; serial; format; size; lastPlayed }
        } else if columns.contains(.lastPlayed) {
            table { name; console; serial; size; lastPlayed }
        } else {
            table { name; console; serial; size }
        }
    }

    /// The table of the games shown with `columns`, its selection the library's, a double-click or Return
    /// playing the row.
    private func table<Columns: TableColumnContent>(
        @TableColumnBuilder<GameRow, Never> _ columns: () -> Columns
    ) -> some View where Columns.TableRowValue == GameRow, Columns.TableColumnSortComparator == Never {
        Table(viewModel.rows, selection: $viewModel.selection, columns: columns)
            .contextMenu(forSelectionType: GameRow.ID.self) { _ in
                // The design draws no context menu: a row's double-click and Return play it.
            } primaryAction: { ids in
                viewModel.play(ids.first)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: false))
            .scrollContentBackground(.hidden)
            .background(Palette.content)
            .textStyle(.body)
            .accessibilityLabel(LibraryText.gamesLabel)
    }

    private var name: some TableColumnContent<GameRow, Never> {
        TableColumn(LibraryLayout.Column.name.title) { row in
            NameCell(row: row)
        }
        .width(min: Metrics.layout.nameColumn)
    }

    private var console: some TableColumnContent<GameRow, Never> {
        TableColumn(LibraryLayout.Column.console.title) { row in
            Text(row.console)
                .foregroundStyle(row.consoleEmphasis == .muted ? Palette.secondaryText : Palette.text)
        }
        .width(Metrics.layout.consoleColumn)
    }

    private var serial: some TableColumnContent<GameRow, Never> {
        TableColumn(LibraryLayout.Column.serial.title) { row in
            Text(row.serial)
                .textStyle(.body, monospaced: true)
                .foregroundStyle(row.serialEmphasis == .muted ? Palette.secondaryText : Palette.text)
        }
        .width(Metrics.layout.serialColumn)
    }

    private var format: some TableColumnContent<GameRow, Never> {
        TableColumn(LibraryLayout.Column.format.title) { row in
            Text(row.format)
                .foregroundStyle(Palette.secondaryText)
        }
        .width(Metrics.layout.formatColumn)
    }

    private var size: some TableColumnContent<GameRow, Never> {
        TableColumn(LibraryLayout.Column.size.title) { row in
            Text(row.size)
                .monospacedDigit()
                .foregroundStyle(Palette.secondaryText)
        }
        .width(Metrics.layout.sizeColumn)
    }

    private var lastPlayed: some TableColumnContent<GameRow, Never> {
        TableColumn(LibraryLayout.Column.lastPlayed.title) { row in
            Text(row.lastPlayed)
                .foregroundStyle(Palette.secondaryText)
        }
        .width(Metrics.layout.lastPlayedColumn)
    }
}

/// A row's name: a disc's or a program's symbol, the name on one line, and a missing file's chip.
private struct NameCell: View {
    let row: GameRow

    var body: some View {
        HStack(spacing: Metrics.space2) {
            Image(systemName: row.symbol)
                .foregroundStyle(Palette.secondaryText)
                .accessibilityHidden(true)
            Text(row.name)
                .lineLimit(1)
                .truncationMode(.tail)
            if let flag = row.flag {
                Chip(flag, tone: row.flagTone ?? .warning)
            }
        }
        .frame(minHeight: Metrics.layout.row - Metrics.space2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.accessibilityLabel)
    }
}

#if DEBUG
#Preview("Table") {
    GameTable(viewModel: PreviewLibrary.listed(), columns: LibraryLayout.Column.allCases)
        .frame(width: Metrics.layout.windowWidth - Metrics.layout.sidebar, height: Metrics.layout.windowMinHeight)
}

#Preview("Table beside Game info") {
    let layout = LibraryLayout(windowWidth: Metrics.layout.windowWidth, wantsSidebar: true, showsInfo: true)
    GameTable(viewModel: PreviewLibrary.today(), columns: layout.columns)
        .frame(width: layout.contentWidth, height: Metrics.layout.windowMinHeight)
}

#Preview("Table at the least width") {
    let layout = LibraryLayout(windowWidth: Metrics.layout.windowMinWidth, wantsSidebar: true, showsInfo: false)
    GameTable(viewModel: PreviewLibrary.listed(), columns: layout.columns)
        .frame(width: layout.contentWidth, height: Metrics.layout.windowMinHeight)
}
#endif
#endif
