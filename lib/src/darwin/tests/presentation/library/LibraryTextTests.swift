// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import DataLibrary
import Foundation
@testable import PresentationLibrary
import PresentationStyles
import Testing

/// The library's words are the design's own: every sentence it shows is in the prototype
/// (`html/main.html`) as it is written, read here by its repository path, read-only; its figures are
/// written as the prototype's `fmtBytes`, its dates as its "Today, 9:41" and "Nov 12", and the places of
/// its sidebar as the Today level draws them.
@Suite struct LibraryTextTests {
    /// html/main.html, located from this file (lib/src/darwin/tests/presentation/library/LibraryTextTests.swift).
    static let prototype = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("documentation/design/darwin/html/main.html")

    @Test func everySentenceIsTheDesignsOwn() throws {
        let design = try String(contentsOf: Self.prototype, encoding: .utf8)
        let sentences = [
            // The window, the toolbar and the sidebar.
            "'\(LibraryText.hideSidebar)'", "'\(LibraryText.showSidebar)'", "'\(LibraryText.addGamesButton)'", "'\(LibraryText.addFolderButton)'",
            "'\(LibraryText.showAsList)'", "'\(LibraryText.showAsGrid)'", "'\(LibraryText.gameInfo)'", "'⌃⌘S'", "'⌘O'", "'⇧⌘O'", "'⌘I'",
            "placeholder=\"\(LibraryText.search)\"",
            // The empty library, the list and its search.
            LibraryText.addYourGames, LibraryText.whatCanBeAdded, LibraryText.addGames, LibraryText.addFolder,
            LibraryText.readsWhereTheyAre, LibraryText.todayBanner, LibraryText.noGamesHere, LibraryText.clearSearch,
            "'No games match “'", "'No games'", "'1 game'", "' games'",
            "'\(LibraryText.unknown)'", "'\(LibraryText.none)'", "'\(LibraryText.never)'", "'\(LibraryText.fileMissing)'",
            "'\(LibraryText.psexe)'", "'Never played'", "'Played '",
            // Game info.
            LibraryText.consoleUntilRead, LibraryText.noSerial, LibraryText.cantFindFile, "'\(LibraryText.play)'", LibraryText.playHelp,
            LibraryText.locate, LibraryText.locateHelp, LibraryText.showInFinder, LibraryText.removeFromLibrary,
            LibraryText.removeFromLibraryHelp, "aria-label=\"\(LibraryText.rename)\"", LibraryText.discsPlayLater, LibraryText.cantFindShort,
            "'Cue sheet with '", "' track'", "' tracks'", "'Playlist of '", "' discs'", "'PS-EXE program'", "'ISO image'",
            // The rename sheet and the choosers.
            LibraryText.renameNote, "'\(LibraryText.cancel)'",
            LibraryText.addGamesMessage, "ok: '\(LibraryText.addGamesConfirmation)'",
            LibraryText.addFolderMessage, "ok: '\(LibraryText.addFolderConfirmation)'",
            LibraryText.locateMessage, "ok: '\(LibraryText.locateConfirmation)'",
            // The remove confirmation and the missing file's dialog.
            "'Remove “'", "'” from your library?'", "The disc image stays on your Mac", "You can add it again any time.",
            "'Deletes its entry and bookmark from library.json in iStation’s container.\\nLeaves '", "' untouched.'",
            "'iStation can’t find “'", "'It was in '", "'. It may have been moved, renamed or deleted.'", "'Remove from Library'",
            // The scan.
            "'Adding games from '", "'Looking for .cue, .iso, .m3u and .exe files'", "' found'", "'Discs read'", "'Reading '",
            "'Already in your library'", "'Added · '", "'PS-EXE · no serial'", "'Nothing added yet.'",
            "'Stopped before reading any disc. Scan Again starts over.'", "' Scan Again skips the games already added.'",
            "'Stopped after '", "' already in your library.'", "' couldn’t be added.'", "'iStation couldn’t open this file.'",
            "'Done'", "'Scan Again'", "'Stop'",
            // The opening job.
            "'Opening '", "'Once the BIOS reaches its shell'",
        ]
            + ScanViewModel.Step.allCases.map { "'\($0.name)'" }
            + OpeningViewModel.Step.allCases.map { "'\($0.name)'" }
            + LibraryPlace.allCases.flatMap { ["'\($0.title)'", "'\($0.shortcut)'"] }
            + LibraryPlace.Section.allCases.map { "title: '\($0.title)'" }
            + LibraryLayout.Column.allCases.map { "label: '\($0.title)'" }
        for sentence in sentences {
            #expect(design.contains(sentence), "html/main.html doesn't say \(sentence)")
        }
    }

    @Test func sizesAreWrittenAsTheDesignWritesThem() {
        #expect(LibraryText.size(-1) == "Unknown")
        #expect(LibraryText.size(0) == "0 bytes")
        #expect(LibraryText.size(999) == "999 bytes")
        #expect(LibraryText.size(1_000) == "1.0 KB")
        #expect(LibraryText.size(34_816) == "34.8 KB")
        #expect(LibraryText.size(99_950) == "100.0 KB", "a half rounds up, as toFixed does")
        #expect(LibraryText.size(398_458_880) == "398 MB")
        #expect(LibraryText.size(402_653_184) == "403 MB")
        #expect(LibraryText.size(487_915_520) == "488 MB")
        #expect(LibraryText.size(512_340_096) == "512 MB")
        #expect(LibraryText.size(1_953_021_952) == "2.0 GB")
        #expect(LibraryText.size(3_912_040_448) == "3.9 GB")
        #expect(LibraryText.size(1_500_000_000_000) == "1500 GB", "gigabytes are the largest unit")
    }

    @Test func datesAreWrittenAsTheDesignWritesThem() {
        #expect(LibraryText.played(moment(2026, 11, 22, 9, 30), in: utc, today: today) == "Today, 9:30")
        #expect(LibraryText.played(moment(2026, 11, 22, 0, 5), in: utc, today: today) == "Today, 0:05")
        #expect(LibraryText.played(moment(2026, 11, 21, 21, 10), in: utc, today: today) == "Yesterday, 21:10")
        #expect(LibraryText.played(moment(2026, 11, 12), in: utc, today: today) == "Nov 12")
        #expect(LibraryText.played(moment(2025, 10, 30), in: utc, today: today) == "Oct 30, 2025")
        #expect(LibraryText.played(nil, in: utc, today: today) == "Never")
        #expect(LibraryText.added(moment(2026, 11, 22, 8), in: utc, today: today) == "Today")
        #expect(LibraryText.added(moment(2026, 11, 14), in: utc, today: today) == "Nov 14")
        #expect(LibraryText.added(.distantPast, in: utc, today: today) == "Unknown", "a record that didn't keep it")
    }

    @Test func aGamesInitialsStandInForArtwork() {
        #expect(LibraryText.initials("Harbor Lights (USA)") == "HL")
        #expect(LibraryText.initials("Glass Orchard (Europe)") == "GO")
        #expect(LibraryText.initials("gpu-test") == "GT")
        #expect(LibraryText.initials("Tidepool") == "TI")
        #expect(LibraryText.initials("x") == "X")
        #expect(LibraryText.initials("(USA)") == "?")
    }

    @Test func aGamesFormatIsWrittenAtTheTodayLevel() {
        #expect(LibraryText.formatCell(.cue) == ".cue")
        #expect(LibraryText.formatCell(.iso) == ".iso")
        #expect(LibraryText.formatCell(.m3u) == ".m3u")
        #expect(LibraryText.formatCell(.psexe) == "PS-EXE")
        #expect(LibraryText.formatCell(.unknown("chd")) == ".chd", "a later format by its extension")
        #expect(LibraryText.formatCell(.unknown("")) == "Unknown")
        #expect(LibraryText.formatFact(game(Files.orchard, tracks: ["a.bin"])) == "Cue sheet with 1 track")
        #expect(LibraryText.formatFact(game(Files.harbor, tracks: ["a.bin", "b.bin"])) == "Cue sheet with 2 tracks")
        #expect(LibraryText.formatFact(game(Files.tidepool, discs: ["1.cue", "2.cue", "3.cue"])) == "Playlist of 3 discs")
        #expect(LibraryText.formatFact(game(Files.tidepool, discs: ["1.cue"])) == "Playlist of 1 disc")
        #expect(LibraryText.formatFact(game(Files.gpuTest)) == "PS-EXE program")
        #expect(LibraryText.formatFact(game(Files.moonbase)) == "ISO image")
    }

    @Test func aPlaceCountsItsGamesInWords() {
        #expect(LibraryText.games(0) == "No games")
        #expect(LibraryText.games(1) == "1 game")
        #expect(LibraryText.games(6) == "6 games")
        #expect(LibraryText.games(1_234) == "1,234 games")
    }

    @Test func theSidebarHasTheTodayLevelsPlacesAndKeys() {
        #expect(LibraryPlace.Section.allCases.map(\.title) == ["Library", "Console"])
        #expect(LibraryPlace.Section.library.places == [.allGames, .recentlyPlayed])
        #expect(LibraryPlace.Section.console.places == [.bios])
        #expect(LibraryPlace.allCases.map(\.help) == ["All Games (⌘1)", "Recently Played (⌘4)", "BIOS (⌘6)"])
        #expect(LibraryPlace.allCases.map(\.shortcutKey) == ["1", "4", "6"])
        #expect(LibraryPlace.allCases.map(\.symbol) == [Symbols.allGames, Symbols.recentlyPlayed, Symbols.bios])
        #expect(LibraryPlace.allCases.map(\.listsGames) == [true, true, false])
    }
}
