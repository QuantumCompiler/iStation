// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import DataLibrary
import Foundation
import PresentationStyles

/// The words the library says, as the design's `html/main.html` has them at the Today level (boards
/// `Mac-LibraryEmpty`, `Mac-TodayLibrary`, `Mac-LibraryInspector`, `Mac-LibraryMissing`,
/// `Mac-RemoveConfirm`, `Mac-Rename`, the scan's and the opening's), and the helpers the view-models write
/// their figures with. Until 5h reads discs, a disc's console and serial are "Unknown" and only a PS-EXE
/// plays.
enum LibraryText {
    // MARK: The toolbar

    /// The sidebar button while the sidebar shows, and its tooltip.
    static let hideSidebar = "Hide the sidebar"
    static let hideSidebarHelp = "Hide the sidebar (⌃⌘S)"
    /// The sidebar button while it's hidden, and its tooltip.
    static let showSidebar = "Show the sidebar"
    static let showSidebarHelp = "Show the sidebar (⌃⌘S)"
    /// The toolbar's Add Games button, and its tooltip.
    static let addGamesButton = "Add Games"
    static let addGamesHelp = "Add Games (⌘O)"
    /// The toolbar's Add Folder button, and its tooltip.
    static let addFolderButton = "Add Folder"
    static let addFolderHelp = "Add Folder (⇧⌘O)"
    /// The view buttons.
    static let showAsList = "Show as list"
    static let showAsGrid = "Show as grid"
    /// The Game info button, and its tooltip.
    static let gameInfo = "Game info"
    static let gameInfoHelp = "Game info (⌘I)"
    /// The search field's placeholder, which VoiceOver names it by: SwiftUI's toolbar search field takes
    /// no other name, so the design's "Search games" label isn't drawn.
    static let search = "Search"
    /// The list and grid buttons' name for VoiceOver, as a group.
    static let view = "View"
    /// The table's and the grid's name for VoiceOver.
    static let gamesLabel = "Games"

    // MARK: The menus (the Layout page's)

    /// The View menu's list and grid.
    static let asList = "as List"
    static let asGrid = "as Grid"
    /// The View menu's sidebar item, while the sidebar is hidden and while it shows.
    static let showSidebarItem = "Show Sidebar"
    static let hideSidebarItem = "Hide Sidebar"
    /// The View menu's Game info item, while it is hidden and while it shows.
    static let showGameInfo = "Show Game Info"
    static let hideGameInfo = "Hide Game Info"

    // MARK: An empty library (Mac-LibraryEmpty)

    /// Its heading.
    static let addYourGames = "Add your games"
    /// What can be added.
    static let whatCanBeAdded = "Add disc images you made from your own discs: a .cue with its .bin tracks, an .iso, an .m3u for a game on several discs, or a PS-EXE."
    /// Its buttons, which open the file chooser and the folder chooser.
    static let addGames = "Add Games…"
    static let addFolder = "Add Folder…"
    /// Its closing caption (contract row C47).
    static let readsWhereTheyAre = "iStation reads your files where they are. It never copies, uploads or downloads games."

    // MARK: The list

    /// The note above the games while discs can't be read (Mac-TodayLibrary).
    static let todayBanner = "This version lists your disc images but can’t read or play them yet. Discs play from v0.2.0."
    /// A place that lists no games, though the library keeps some.
    static let noGamesHere = "No games here yet."
    /// The button that empties the search.
    static let clearSearch = "Clear Search"
    /// What a game's console, serial, size and last played say when they aren't known.
    static let unknown = "Unknown"
    /// A PS-EXE's serial in the table: it has none.
    static let none = "None"
    /// A game never played.
    static let never = "Never"
    /// A game whose file can't be found, flagged beside its name.
    static let fileMissing = "File missing"
    /// A PS-EXE's format.
    static let psexe = "PS-EXE"

    /// The search that found nothing: "No games match “zebra”.".
    static func noGamesMatch(_ query: String) -> String {
        "No games match “\(query)”."
    }

    /// How many games a place shows, the window's subtitle: "No games", "1 game", "6 games".
    static func games(_ count: Int) -> String {
        switch count {
        case 0: "No games"
        case 1: "1 game"
        default: "\(Figures.grouped(count)) games"
        }
    }

    // MARK: Game info (Mac-LibraryInspector, Mac-LibraryMissing)

    /// A disc's console until 5h reads it.
    static let consoleUntilRead = "Unknown until discs can be read"
    /// A PS-EXE's serial: homebrew has none.
    static let noSerial = "None (homebrew)"
    /// What Game info says of a file the library can't find.
    static let cantFindFile = "iStation can’t find this file. It may have been moved, renamed or deleted."
    /// Game info's buttons and their tooltips.
    static let play = "Play"
    static let playHelp = "Play (↩)"
    static let locate = "Locate…"
    static let locateHelp = "Find the file"
    static let showInFinder = "Show in Finder"
    static let removeFromLibrary = "Remove from Library…"
    static let removeFromLibraryHelp = "Remove from Library (⌘⌫)"
    static let rename = "Rename"
    /// Why a disc's Play is off until v0.2.0.
    static let discsPlayLater = "Discs play from v0.2.0."
    /// Why a missing file's Play is off.
    static let cantFindShort = "iStation can’t find this file."

    // MARK: Rename (Mac-Rename)

    /// What the rename sheet's field is for.
    static let renameNote = "Name in your library. The file keeps its own name."
    /// The sheet's buttons.
    static let cancel = "Cancel"

    // MARK: The choosers

    // SwiftUI's file chooser takes no title, so the design's "Add Games", "Add a Folder" and
    // "Locate “Lantern Street.cue”" aren't drawn: each chooser shows its message and its button.

    /// Add Games…'s chooser: its message and button.
    static let addGamesMessage = "Choose a .cue (its .bin tracks come with it), an .iso, an .m3u or a PS-EXE. iStation reads them where they are."
    static let addGamesConfirmation = "Add"
    /// Add Folder…'s chooser: its message and button.
    static let addFolderMessage = "iStation looks inside this folder and its subfolders for disc images."
    static let addFolderConfirmation = "Add Folder"
    /// Locate…'s chooser: its message and button.
    static let locateMessage = "iStation updates its bookmark to the file you choose."
    static let locateConfirmation = "Choose"
    /// Why a file chosen through Add Games… or Locate… isn't kept: its extension isn't a game's.
    static let onlyGameFiles = "iStation’s library keeps .cue, .iso, .m3u and .exe files."

    // MARK: What a game's file is

    /// The Format column at the Today level: ".cue", ".iso", ".m3u", "PS-EXE"; another kind by its
    /// extension, or "Unknown" without one.
    static func formatCell(_ format: GameFormat) -> String {
        switch format {
        case .psexe: psexe
        case .unknown(let value) where value.isEmpty: unknown
        default: "." + format.rawValue
        }
    }

    /// The format as Game info writes it: "Cue sheet with 2 tracks", "Playlist of 3 discs", "PS-EXE
    /// program", "ISO image".
    static func formatFact(_ game: GameRecord) -> String {
        switch game.format {
        case .cue: "Cue sheet with " + count(game.tracks.count, "track", "tracks")
        case .m3u: "Playlist of " + count(game.discs.count, "disc", "discs")
        case .psexe: "PS-EXE program"
        case .iso: "ISO image"
        case .unknown: unknown
        }
    }

    /// `n` and its noun, singular for one: "1 track", "3 discs".
    static func count(_ n: Int, _ one: String, _ many: String) -> String {
        "\(Figures.grouped(n)) " + (n == 1 ? one : many)
    }

    // MARK: Figures

    /// A size as the design writes one (html/main.html's `fmtBytes`): bytes under 1,000, then KB, MB and
    /// GB by thousands, one decimal under 100 and none from 100: "34.8 KB", "512 MB", "2.0 GB".
    static func size(_ bytes: Int) -> String {
        guard bytes >= 0 else { return unknown }
        guard bytes >= 1_000 else { return "\(bytes) bytes" }
        let units = ["KB", "MB", "GB"]
        var value = Double(bytes)
        var unit = -1
        while value >= 1_000 && unit < units.count - 1 {
            value /= 1_000
            unit += 1
        }
        return fixed(value, places: value >= 100 ? 0 : 1) + " " + units[unit]
    }

    /// `value` with `places` decimals, a half rounded away from zero, as JavaScript's `toFixed` does.
    private static func fixed(_ value: Double, places: Int) -> String {
        let scale = places == 0 ? 1.0 : 10.0
        let rounded = (value * scale).rounded(.toNearestOrAwayFromZero) / scale
        return String(format: "%.\(places)f", rounded)
    }

    /// When a game was added: "Today", "Nov 14", "Nov 14, 2025"; "Unknown" for a record that didn't keep it.
    static func added(_ date: Date, in calendar: Calendar, today: Date) -> String {
        date == .distantPast ? unknown : Dates.day(date, in: calendar, today: today)
    }

    /// When a game was last played: "Today, 9:41" and "Yesterday, 21:10" with the time, then "Nov 12" or
    /// "Oct 30, 2025"; "Never" for a game not played.
    static func played(_ date: Date?, in calendar: Calendar, today: Date) -> String {
        guard let date else { return never }
        let time = calendar.dateComponents([.hour, .minute], from: date)
        let clock = "\(time.hour ?? 0):" + (time.minute.map { $0 < 10 ? "0\($0)" : "\($0)" } ?? "00")
        if calendar.isDate(date, inSameDayAs: today) { return "Today, " + clock }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today), calendar.isDate(date, inSameDayAs: yesterday) {
            return "Yesterday, " + clock
        }
        return Dates.day(date, in: calendar, today: today)
    }

    /// The two letters a game's tile and Game info draw in place of artwork (html/main.html's `initials`):
    /// the first letters of its first two words, what's in brackets left out — "HL" for "Harbor Lights
    /// (USA)", "GT" for "gpu-test" — or the first two of a single word, "TI" for "Tidepool".
    static func initials(_ name: String) -> String {
        var plain = ""
        var depth = 0
        for character in name {
            if character == "(" { depth += 1; continue }
            if character == ")" && depth > 0 { depth -= 1; continue }
            if depth == 0 { plain.append(character) }
        }
        let words = plain.split { $0.isWhitespace || $0 == "-" }.map(String.init)
        guard let first = words.first else { return "?" }
        let second = words.count > 1 ? words[1].prefix(1) : first.dropFirst().prefix(1)
        return (first.prefix(1) + second).uppercased()
    }
}
