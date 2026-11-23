// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

#if os(macOS)
import PresentationStyles
import SwiftUI

/// The library window's sidebar at the Today level, as the design draws it: under Library, All Games and
/// Recently Played with how many games each holds; under Console, the BIOS. Each row names its shortcut
/// in its help (⌘1, ⌘4, ⌘6); choosing one shows that place, and does nothing under a sheet or an alert.
struct LibrarySidebar: View {
    let viewModel: LibraryViewModel

    var body: some View {
        List(selection: place) {
            ForEach(LibraryPlace.Section.allCases) { section in
                Section(section.title) {
                    ForEach(section.places) { place in
                        PlaceRow(place: place, count: viewModel.count(of: place))
                            .tag(place)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Palette.sidebar)
        .textStyle(.body)
    }

    /// The place shown; choosing a row goes there.
    private var place: Binding<LibraryPlace?> {
        Binding(
            get: { viewModel.place },
            set: { if let place = $0 { viewModel.go(to: place) } }
        )
    }
}

/// One place: its symbol in the accent's text color, its name, and how many games it holds.
private struct PlaceRow: View {
    let place: LibraryPlace
    let count: Int?

    var body: some View {
        Label {
            Text(place.title)
                .foregroundStyle(Palette.text)
        } icon: {
            Image(systemName: place.symbol)
                .foregroundStyle(Palette.accentText)
        }
        .badge(count.map { Text(Figures.grouped($0)) })
        .help(place.help)
    }
}

#if DEBUG
#Preview("Sidebar") {
    LibrarySidebar(viewModel: PreviewLibrary.listed())
        .frame(width: Metrics.layout.sidebar, height: Metrics.layout.windowMinHeight)
}

#Preview("Sidebar, empty library") {
    LibrarySidebar(viewModel: PreviewLibrary.empty())
        .frame(width: Metrics.layout.sidebar, height: Metrics.layout.windowMinHeight)
}
#endif
#endif
