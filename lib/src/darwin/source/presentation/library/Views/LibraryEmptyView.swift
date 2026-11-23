// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

#if os(macOS)
import PresentationStyles
import SwiftUI

/// The empty library, as the design's `Mac-LibraryEmpty` draws it, where the BIOS check's Continue lands:
/// what can be added, Add Games… and Add Folder…, and that iStation reads the files where they are.
struct LibraryEmptyView: View {
    let viewModel: LibraryViewModel

    var body: some View {
        VStack(spacing: Metrics.space3) {
            Image(systemName: Symbols.disc)
                .font(Typography.screenSymbol)
                .foregroundStyle(Palette.secondaryText)
                .accessibilityHidden(true)
            Text(LibraryText.addYourGames)
                .textStyle(.title2, weight: .bold)
                .accessibilityAddTraits(.isHeader)
            Text(LibraryText.whatCanBeAdded)
                .foregroundStyle(Palette.secondaryText)
            HStack(spacing: Metrics.space2) {
                Button(LibraryText.addGames) { viewModel.chooseGames() }
                    .buttonStyle(SheetButtonStyle(.primary))
                    .help(LibraryText.addGamesHelp)
                    .disabled(!viewModel.canAct)
                Button(LibraryText.addFolder) { viewModel.chooseFolder() }
                    .buttonStyle(SheetButtonStyle(.bordered))
                    .help(LibraryText.addFolderHelp)
                    .disabled(!viewModel.canAct)
            }
            Text(LibraryText.readsWhereTheyAre)
                .textStyle(.caption)
                .foregroundStyle(Palette.secondaryText)
        }
        .multilineTextAlignment(.center)
        .textStyle(.body)
        .foregroundStyle(Palette.text)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: Metrics.layout.emptyWidth)
        .padding(Metrics.space10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A place or a search that shows no games, though the library keeps some, as the design's
/// `Mac-LibrarySearchEmpty` draws it: what it found, and Clear Search.
struct NoResultsView: View {
    /// What it says: "No games match “zebra”.", or "No games here yet.".
    let text: String
    /// Empties the search.
    let clearSearch: () -> Void

    var body: some View {
        VStack(spacing: Metrics.space3) {
            Text(text)
                .foregroundStyle(Palette.secondaryText)
                .multilineTextAlignment(.center)
            Button(LibraryText.clearSearch, action: clearSearch)
                .buttonStyle(SheetButtonStyle(.bordered))
        }
        .textStyle(.body)
        // The design's 60 points above it: the largest space, and half of it again.
        .padding(.top, Metrics.space10 + Metrics.space5)
        .padding(.horizontal, Metrics.space5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

#if DEBUG
#Preview("Empty library") {
    LibraryEmptyView(viewModel: PreviewLibrary.empty())
        .frame(width: Metrics.layout.windowWidth - Metrics.layout.sidebar, height: Metrics.layout.windowHeight - Metrics.layout.toolbar)
        .background(Palette.content)
}

#Preview("No results") {
    let library = PreviewLibrary.searchEmpty()
    if case .noResults(let text) = library.content {
        NoResultsView(text: text) { library.clearSearch() }
            .frame(width: Metrics.layout.windowWidth - Metrics.layout.sidebar, height: Metrics.layout.windowHeight - Metrics.layout.toolbar)
            .background(Palette.content)
    }
}
#endif
#endif
