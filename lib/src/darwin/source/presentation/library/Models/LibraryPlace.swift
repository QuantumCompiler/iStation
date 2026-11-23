// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import PresentationStyles

/// A place in the library window's sidebar, as the design's Today level draws it: under Library, All
/// Games (⌘1) and Recently Played (⌘4); under Console, the BIOS (⌘6). The PS1 and PS2 filters (⌘2, ⌘3)
/// come with 5h, Memory Cards (⌘5) with 5k, and the personal build's Tools (⌘7) with 5f.
public enum LibraryPlace: String, Sendable, CaseIterable, Identifiable {
    /// Every game the library keeps.
    case allGames
    /// The games played, the most recent first.
    case recentlyPlayed
    /// The BIOS pane: the BIOS the library keeps.
    case bios

    /// A heading the sidebar lists its places under.
    public enum Section: String, Sendable, CaseIterable, Identifiable {
        /// The games: All Games and Recently Played.
        case library
        /// The console's own files: the BIOS.
        case console

        /// The heading's title: "Library", "Console".
        public var title: String {
            switch self {
            case .library: "Library"
            case .console: "Console"
            }
        }

        /// The places under it, in the sidebar's order.
        public var places: [LibraryPlace] {
            LibraryPlace.allCases.filter { $0.section == self }
        }

        /// The section itself.
        public var id: Self { self }
    }

    /// The place itself.
    public var id: Self { self }

    /// The heading it sits under.
    public var section: Section {
        switch self {
        case .allGames, .recentlyPlayed: .library
        case .bios: .console
        }
    }

    /// Its name in the sidebar, and the window's title while it shows: "All Games".
    public var title: String {
        switch self {
        case .allGames: "All Games"
        case .recentlyPlayed: "Recently Played"
        case .bios: "BIOS"
        }
    }

    /// The SF Symbol beside its name.
    public var symbol: String {
        switch self {
        case .allGames: Symbols.allGames
        case .recentlyPlayed: Symbols.recentlyPlayed
        case .bios: Symbols.bios
        }
    }

    /// The digit ⌘ goes with to show it: 1, 4 and 6, as the design numbers every place it will have.
    public var shortcutKey: Character {
        switch self {
        case .allGames: "1"
        case .recentlyPlayed: "4"
        case .bios: "6"
        }
    }

    /// Its shortcut as the design writes it: "⌘1".
    public var shortcut: String { "⌘\(shortcutKey)" }

    /// Its tooltip, naming its shortcut: "All Games (⌘1)".
    public var help: String { "\(title) (\(shortcut))" }

    /// Whether it lists games, so the table, the grid, search and Game info show.
    public var listsGames: Bool { self != .bios }
}
