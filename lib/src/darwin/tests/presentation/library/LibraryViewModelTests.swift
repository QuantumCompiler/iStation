// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessPS1
import DataLibrary
import Foundation
@testable import PresentationLibrary
import PresentationStyles
import Testing

/// The library window over an in-memory library of made-up games and files: its places and search, the
/// table's and grid's words at the Today level, Game info, Play only for a PS-EXE, the missing file and
/// Locate…, removing (asked first), renaming, Add Games…, keys that do nothing under a sheet — the
/// library's own or another screen's — and the window's sidebar and Game menu. Every wait ends after two
/// seconds.
@MainActor
@Suite struct LibraryViewModelTests {
    func makeLibrary(
        _ storage: MemoryStorage = sampleStorage(), session: FakePowerSession = FakePowerSession(),
        onRun: @escaping @MainActor (GameRun) -> Void = { _ in }
    ) -> LibraryViewModel {
        LibraryViewModel(storage: storage, session: session, home: Files.home, calendar: utc, now: { today }, onRun: onRun)
    }

    /// The sample game kept by the file at `url`; one the library doesn't keep when it's gone, so the
    /// expectations on it fail rather than the run trapping.
    func sample(_ library: LibraryViewModel, _ url: URL) -> GameRecord {
        library.games.first { $0.fileName == url.lastPathComponent } ?? game(URL(fileURLWithPath: "/gone/\(url.lastPathComponent)"))
    }

    // MARK: Places, search and the empty library

    @Test func anEmptyLibraryAsksForGames() async {
        let library = makeLibrary(MemoryStorage(library: Library(bios: keptBIOS)))
        #expect(await settled(library))
        #expect(library.content == .empty)
        #expect(library.windowTitle == "All Games")
        #expect(library.windowSubtitle == "No games")
        #expect(!library.showsTodayBanner)
        #expect(library.selection == nil)
        #expect(!library.canToggleInfo)
        #expect(library.rows.isEmpty)
        #expect(library.count(of: .allGames) == 0)
    }

    @Test func theLibraryShowsItsGamesInTheOrderAddedTheFirstSelected() async {
        let library = makeLibrary()
        #expect(await settled(library))
        #expect(library.content == .games)
        #expect(library.rows.map(\.name) == ["Harbor Lights (USA)", "Moonbase Courier", "Tidepool", "Glass Orchard (Europe)", "gpu-test", "Lantern Street"])
        #expect(library.selection == library.games.first?.id)
        #expect(library.windowSubtitle == "6 games")
        #expect(library.showsTodayBanner, "discs are listed, and the note says they can't play yet")
        #expect(library.count(of: .allGames) == 6)
        #expect(library.count(of: .recentlyPlayed) == 5)
        #expect(library.count(of: .bios) == nil)
    }

    @Test func discsShowConsoleAndSerialUnknownAndAPSEXEItsOwn() async throws {
        let library = makeLibrary()
        #expect(await settled(library))
        let rows = library.rows
        try #require(rows.count == 6)
        #expect(rows[0].console == "Unknown")
        #expect(rows[0].consoleEmphasis == .muted)
        #expect(rows[0].serial == "Unknown")
        #expect(rows[0].serialEmphasis == .muted)
        #expect(rows[0].format == ".cue")
        #expect(rows[0].size == "512 MB")
        #expect(rows[0].lastPlayed == "Today, 9:30")
        #expect(rows[0].flag == nil)
        #expect(rows[0].symbol == Symbols.disc)
        #expect(rows[0].accessibilityLabel == "Harbor Lights (USA), Unknown")
        #expect(rows[1].lastPlayed == "Yesterday, 21:10")
        #expect(rows[1].size == "488 MB")
        #expect(rows[1].format == ".iso")
        #expect(rows[2].format == ".m3u")
        #expect(rows[2].size == "2.0 GB")
        #expect(rows[3].lastPlayed == "Never")
        let program = rows[4]
        #expect(program.console == "PS1")
        #expect(program.consoleEmphasis == .plain)
        #expect(program.serial == "None")
        #expect(program.format == "PS-EXE")
        #expect(program.size == "34.8 KB")
        #expect(program.lastPlayed == "Nov 18")
        #expect(program.symbol == Symbols.program)
        #expect(program.accessibilityLabel == "gpu-test, PS1")
    }

    @Test func theGridDrawsInitialsInPlaceOfArtwork() async throws {
        let library = makeLibrary()
        #expect(await settled(library))
        library.viewMode = .grid
        #expect(library.viewMode == .grid)
        let rows = library.rows
        try #require(rows.count == 6)
        #expect(rows[0].initials == "HL")
        #expect(rows[0].consoleBadge == "?")
        #expect(rows[0].serialBadge == "")
        #expect(rows[0].tileCaption == "Played Today, 9:30")
        #expect(rows[3].tileCaption == "Never played")
        #expect(rows[4].initials == "GT")
        #expect(rows[4].consoleBadge == "PS1")
        #expect(rows[4].serialBadge == "PS-EXE")
        #expect(rows[4].tileCaption == "Played Nov 18")
    }

    @Test func recentlyPlayedShowsThePlayedGamesTheMostRecentFirst() async {
        let library = makeLibrary()
        #expect(await settled(library))
        let first = library.selection
        library.go(to: .recentlyPlayed)
        #expect(library.place == .recentlyPlayed)
        #expect(library.windowTitle == "Recently Played")
        #expect(library.rows.map(\.name) == ["Harbor Lights (USA)", "Moonbase Courier", "gpu-test", "Tidepool", "Lantern Street"])
        #expect(library.windowSubtitle == "5 games")
        #expect(library.selection == first, "the selection is among them, so it stays")
    }

    @Test func aPlaceWithoutGamesSaysNoneAreHereYet() async {
        let library = makeLibrary(MemoryStorage(library: Library(bios: keptBIOS, games: [game(Files.orchard)])))
        #expect(await settled(library))
        library.go(to: .recentlyPlayed)
        #expect(library.content == .noResults("No games here yet."))
        #expect(library.windowSubtitle == "No games")
        #expect(library.showsTodayBanner)
    }

    @Test func choosingAPlaceSelectsItsFirstGameWhenTheSelectionIsntAmongThem() async {
        let library = makeLibrary()
        #expect(await settled(library))
        library.selection = sample(library, Files.orchard).id
        library.isShowingInfo = true
        library.go(to: .recentlyPlayed)
        #expect(library.selection == sample(library, Files.harbor).id)
        #expect(library.showsInfo)
        library.go(to: .bios)
        #expect(library.windowTitle == "BIOS")
        #expect(library.windowSubtitle == "")
        #expect(library.rows.isEmpty)
        #expect(!library.isShowingInfo, "the BIOS closes Game info")
        #expect(!library.showsTodayBanner)
    }

    @Test func searchFindsGamesByTheirNameInAnyCase() async {
        let library = makeLibrary()
        #expect(await settled(library))
        library.query = "moon"
        #expect(library.rows.map(\.name) == ["Moonbase Courier"])
        library.query = "HARBOR"
        #expect(library.rows.map(\.name) == ["Harbor Lights (USA)"])
        library.query = "  tide "
        #expect(library.rows.map(\.name) == ["Tidepool"])
        #expect(library.windowSubtitle == "1 game")
        library.query = ".cue"
        #expect(library.rows.isEmpty, "the name is searched, not the file's")
    }

    @Test func aSearchWithNoResultsSaysSoUntilItIsCleared() async {
        let library = makeLibrary()
        #expect(await settled(library))
        library.query = "zebra"
        #expect(library.content == .noResults("No games match “zebra”."))
        #expect(library.windowSubtitle == "No games")
        #expect(library.rows.isEmpty)
        library.clearSearch()
        #expect(library.query == "")
        #expect(library.content == .games)
        #expect(library.rows.count == 6)
    }

    @Test func aRenamedGameIsFoundByTheNameItWasGiven() async {
        var games = sampleGames()
        games[4].name = "Dawn Run"
        let library = makeLibrary(sampleStorage(games: games))
        #expect(await settled(library))
        library.query = "dawn"
        #expect(library.rows.map(\.name) == ["Dawn Run"])
    }

    // MARK: Game info and Play

    @Test func gameInfoShowsWhatTheLibraryKnowsAtTheTodayLevel() async {
        let library = makeLibrary()
        #expect(await settled(library))
        let tidepool = library.info(for: sample(library, Files.tidepool))
        #expect(tidepool.name == "Tidepool")
        #expect(tidepool.initials == "TI")
        #expect(tidepool.facts == [
            GameInfo.Fact("Console", "Unknown until discs can be read", style: .muted),
            GameInfo.Fact("Serial", "Unknown", style: .monospaced),
            GameInfo.Fact("Format", "Playlist of 3 discs"),
            GameInfo.Fact("Size", "2.0 GB"),
            GameInfo.Fact("File", "Tidepool.m3u", style: .monospaced),
            GameInfo.Fact("Folder", "~/Games/PS1/Tidepool", style: .monospaced),
            GameInfo.Fact("Added", "Nov 12"),
            GameInfo.Fact("Last played", "Nov 12"),
        ])
        #expect(tidepool.banner == nil)
        #expect(tidepool.canShowInFinder)
        #expect(library.info(for: sample(library, Files.harbor)).facts[2].value == "Cue sheet with 2 tracks")
        #expect(library.info(for: sample(library, Files.orchard)).facts[2].value == "Cue sheet with 1 track")
        #expect(library.info(for: sample(library, Files.orchard)).facts[7].value == "Never")
        #expect(library.info(for: sample(library, Files.moonbase)).facts[2].value == "ISO image")
        let program = library.info(for: sample(library, Files.gpuTest))
        #expect(program.facts[0] == GameInfo.Fact("Console", "PS1"))
        #expect(program.facts[1] == GameInfo.Fact("Serial", "None (homebrew)", style: .monospaced))
        #expect(program.facts[2].value == "PS-EXE program")
        #expect(program.facts[5].value == "~/Games/Homebrew")
    }

    @Test func gameInfoShowsWithAGameSelectedInAPlaceOfGames() async {
        let library = makeLibrary()
        #expect(await settled(library))
        #expect(!library.showsInfo)
        library.toggleInfo()
        #expect(library.isShowingInfo)
        #expect(library.showsInfo)
        #expect(library.info?.name == "Harbor Lights (USA)")
        library.selection = nil
        #expect(!library.showsInfo, "nothing to show")
        #expect(!library.canToggleInfo)
        library.toggleInfo()
        #expect(library.isShowingInfo, "⌘I does nothing without a game")
    }

    @Test func playIsOnOnlyForARecognizedPSEXE() async {
        var games = sampleGames()
        games.append(game(URL(fileURLWithPath: "/Users/you/Games/PS1/Night Ferry.chd")))
        let library = makeLibrary(sampleStorage(games: games))
        #expect(await settled(library))
        for url in [Files.harbor, Files.moonbase, Files.tidepool, Files.orchard, Files.lantern] {
            let disc = sample(library, url)
            #expect(library.playability(of: disc) == .init(canPlay: false, reason: "Discs play from v0.2.0."))
            let info = library.info(for: disc)
            #expect(info.action == .play)
            #expect(info.actionTitle == "Play")
            #expect(!info.isActionEnabled)
            #expect(info.reason == "Discs play from v0.2.0.")
        }
        #expect(!library.playability(of: library.games[6]).canPlay, "a format this build doesn't know doesn't play")
        let program = sample(library, Files.gpuTest)
        #expect(library.playability(of: program) == .init(canPlay: true, reason: nil))
        let info = library.info(for: program)
        #expect(info.isActionEnabled)
        #expect(info.actionHelp == "Play (↩)")
        #expect(info.reason == nil)
        library.selection = program.id
        #expect(library.canPlaySelected)
        library.selection = sample(library, Files.harbor).id
        #expect(!library.canPlaySelected)
    }

    @Test func playingADiscOpensNothing() async {
        let session = FakePowerSession()
        let library = makeLibrary(session: session)
        #expect(await settled(library))
        library.play(sample(library, Files.harbor).id)
        #expect(library.opening.state == .idle)
        #expect(library.alert == nil)
        #expect(await session.calls.isEmpty)
    }

    @Test func playingAPSEXEOpensItAndNotesItPlayed() async {
        let session = FakePowerSession()
        let handed = Handed()
        let library = makeLibrary(session: session) { handed.runs.append($0) }
        #expect(await settled(library))
        let program = sample(library, Files.gpuTest)
        library.play(program.id)
        #expect(library.selection == program.id)
        #expect(library.opening.isShowingJob)
        #expect(library.isShowingSheet)
        #expect(await followed(session))
        await session.run(to: 120, reachedShell: true)
        #expect(await eventually { !handed.runs.isEmpty })
        #expect(handed.runs.first.map { [$0.name, $0.fileName] } == ["gpu-test", "gpu-test.exe"])
        #expect(await eventually { library.game(program.id)?.lastPlayed == today.roundedDown })
        #expect(library.game(program.id).map { library.row(for: $0).lastPlayed } == "Today, 9:41")
        #expect(!library.isShowingSheet)
    }

    // MARK: A missing file and Locate…

    @Test func aGameWhoseFileIsGoneIsFlaggedMissingAndStays() async {
        let storage = sampleStorage()
        storage.delete(Files.lantern)
        let library = makeLibrary(storage)
        #expect(await settled(library))
        let lantern = sample(library, Files.lantern)
        #expect(library.isMissing(lantern))
        let row = library.row(for: lantern)
        #expect(row.flag == "File missing")
        #expect(row.flagTone == .warning)
        #expect(row.size == "Unknown")
        #expect(row.accessibilityLabel == "Lantern Street, Unknown, File missing")
        #expect(row.tileCaption == "File missing")
        let info = library.info(for: lantern)
        #expect(info.banner == "iStation can’t find this file. It may have been moved, renamed or deleted.")
        #expect(info.bannerTone == .warning)
        #expect(info.action == .locate)
        #expect(info.actionTitle == "Locate…")
        #expect(info.actionHelp == "Find the file")
        #expect(info.isActionEnabled)
        #expect(info.reason == nil)
        #expect(!info.canShowInFinder)
        #expect(info.facts[3] == GameInfo.Fact("Size", "Unknown"))
        #expect(library.games.count == 6, "a missing game is kept")
        #expect(!storage.calls.contains(.removeGames))
        #expect(!library.isMissing(sample(library, Files.harbor)))
    }

    @Test func aGameFoundSomewhereElseIsKeptQuietlyByWhereItIsNow() async {
        let storage = sampleStorage()
        let before = storage.saved.games[5]
        storage.move(Files.lantern, to: Files.lanternMoved)
        let library = makeLibrary(storage)
        #expect(await settled(library))
        let lantern = sample(library, Files.lantern)
        #expect(!library.isMissing(lantern))
        #expect(lantern.folder == "/Users/you/Games/PS1/Moved")
        #expect(lantern.bookmark == Data(Files.lanternMoved.path.utf8))
        #expect(lantern.id == before.id)
        #expect(lantern.added == before.added)
        #expect(lantern.lastPlayed == before.lastPlayed)
        #expect(storage.calls.contains(.relocateGames(["Lantern Street.cue"])))
        #expect(storage.saved.games[5].folder == "/Users/you/Games/PS1/Moved", "kept in the library itself")
    }

    @Test func gamesFoundSomewhereElseAreKeptAgainInOneChange() async {
        // A folder of games renamed: the look keeps every moved game again in one change to library.json —
        // one load and one save, not one a game, so the main actor isn't held for seconds by a large library.
        let storage = sampleStorage()
        let moved = "/Users/you/Games/PS1 Collection"
        for url in [Files.harbor, Files.moonbase, Files.lantern] {
            storage.move(url, to: URL(fileURLWithPath: moved).appendingPathComponent(url.lastPathComponent))
        }
        let library = makeLibrary(storage)
        #expect(await settled(library))
        let relocations = storage.calls.filter {
            switch $0 {
            case .relocateGame, .relocateGames: true
            default: false
            }
        }
        #expect(relocations == [.relocateGames(["Harbor Lights (USA).cue", "Moonbase Courier.iso", "Lantern Street.cue"])])
        #expect(storage.saved.games.map(\.folder) == [moved, moved, "/Users/you/Games/PS1/Tidepool", "/Users/you/Games/PS1", "/Users/you/Games/Homebrew", moved])
        #expect(library.games == storage.saved.games)
        #expect(!library.games.contains { library.isMissing($0) })
    }

    @Test func aLibraryLetGoEndsItsLookForTheFiles() async {
        let storage = sampleStorage()
        storage.holdResolves()
        var library: LibraryViewModel? = makeLibrary(storage)
        // The look waits at its first game's file; the window goes away meanwhile.
        #expect(await waiting(1, storage))
        #expect(library?.games.count == 6)
        library = nil
        storage.letAllGo()
        try? await Task.sleep(for: .milliseconds(200))
        #expect(storage.calls.count { $0 == .resolve } == 1, "the look ended with the library, at the game it was on")
    }

    @Test func playingAMissingGameAsksToLocateItOrRemoveIt() async {
        let storage = sampleStorage()
        storage.delete(Files.lantern)
        let session = FakePowerSession()
        let library = makeLibrary(storage, session: session)
        #expect(await settled(library))
        let lantern = sample(library, Files.lantern)
        library.play(lantern.id)
        let alert = library.alert
        #expect(alert?.title == "iStation can’t find “Lantern Street.cue”")
        #expect(alert?.message == "It was in ~/Games/PS1. It may have been moved, renamed or deleted.")
        #expect(alert?.details == #"KeptFile.resolve(_:) threw KeptFileError.cannotResolve(reason: "No such file.")"#)
        #expect(alert?.tone == .warning)
        #expect(alert?.buttons.map(\.title) == ["Remove from Library", "Locate…"])
        #expect(alert?.defaultButton?.choice == .locate)
        #expect(library.opening.state == .idle)
        #expect(!library.canAct)

        library.answer(.locate)
        #expect(library.alert == nil)
        #expect(library.isLocating)
        library.isLocating = false

        // Return asks too, as the design's Return plays the selection and a missing one asks: a disc's
        // doesn't play, a missing one's asks whatever its format.
        library.select(lantern.id)
        #expect(library.canPlaySelected)
        library.select(sample(library, Files.harbor).id)
        #expect(!library.canPlaySelected)

        library.play(lantern.id)
        library.answer(.remove)
        #expect(library.game(lantern.id) == nil, "Remove from Library takes it out at once")
        #expect(storage.saved.games.count == 5)
        #expect(library.alert == nil)
        #expect(await session.calls.isEmpty)
    }

    @Test func locatingAGameKeepsItByTheFileChosen() async {
        let storage = sampleStorage()
        storage.delete(Files.lantern)
        storage.put([1, 2, 3, 4], at: Files.lanternMoved)
        let library = makeLibrary(storage)
        #expect(await settled(library))
        let lantern = sample(library, Files.lantern)
        library.selection = lantern.id
        library.locate()
        #expect(library.isLocating)
        library.located(Files.lanternMoved)
        #expect(!library.isLocating)
        #expect(await settled(library))
        let found = sample(library, Files.lantern)
        #expect(!library.isMissing(found))
        #expect(found.folder == "/Users/you/Games/PS1/Moved")
        #expect(found.size == 4)
        #expect(found.id == lantern.id)
        #expect(found.added == lantern.added)
        #expect(found.lastPlayed == lantern.lastPlayed)
        #expect(library.info(for: found).action == .play)
        #expect(library.alert == nil)
        #expect(storage.saved.games[5].folder == "/Users/you/Games/PS1/Moved")
    }

    @Test func locatingAFileAnotherGameIsKeptByIsRefused() async {
        let storage = sampleStorage()
        storage.delete(Files.lantern)
        let library = makeLibrary(storage)
        #expect(await settled(library))
        let lantern = sample(library, Files.lantern)
        library.locate(lantern.id)
        library.located(Files.orchard)
        #expect(await settled(library))
        #expect(library.alert?.title == "That file is already in your library")
        #expect(library.alert?.message == "Your library keeps it as “Glass Orchard (Europe)”. Choose “Lantern Street.cue” where it is now.")
        #expect(library.alert?.details?.hasPrefix("LibraryStore.relocateGame(_:to:) threw LibraryStoreError.alreadyKept(path: ") == true)
        #expect(library.isMissing(lantern), "nothing changed")
        library.answer(.ok)
        #expect(library.alert == nil)
    }

    @Test func locatingAFileThatCantBeOpenedSaysSo() async {
        let storage = sampleStorage()
        storage.delete(Files.lantern)
        let library = makeLibrary(storage)
        #expect(await settled(library))
        library.locate(sample(library, Files.lantern).id)
        library.located(URL(fileURLWithPath: "/Users/you/Games/nowhere.cue"))
        #expect(await settled(library))
        #expect(library.alert?.title == "“nowhere.cue” couldn’t be opened")
        #expect(library.alert?.message == "iStation couldn’t open this file.")
        #expect(library.alert?.details == #"GameFiles.record(for:added:) threw KeptFileError.cannotRead(path: "/Users/you/Games/nowhere.cue", reason: "No such file.")"#)
    }

    @Test func locatingAFileThatIsntAGamesIsRefused() async {
        let stream = URL(fileURLWithPath: "/Users/you/Music/stream.m3u8")
        let storage = sampleStorage()
        storage.delete(Files.lantern)
        storage.put([7], at: stream)
        let library = makeLibrary(storage)
        #expect(await settled(library))
        let lantern = sample(library, Files.lantern)
        library.locate(lantern.id)
        library.located(stream)
        #expect(await settled(library))
        #expect(library.alert?.title == "“stream.m3u8” isn’t a game’s file")
        #expect(library.alert?.message == "iStation’s library keeps .cue, .iso, .m3u and .exe files. Choose “Lantern Street.cue” where it is now.")
        #expect(library.alert?.details == #"GameFormat(fileName: "stream.m3u8") returned nil"#)
        #expect(library.alert?.tone == .warning)
        #expect(!storage.calls.contains(.record("stream.m3u8")), "never recorded")
        #expect(!storage.calls.contains { if case .relocateGame = $0 { true } else { false } })
        #expect(library.isMissing(lantern), "nothing changed")
    }

    @Test func aLookThatEndsAfterALocateLeavesTheGameAsLocated() async {
        let storage = sampleStorage()
        storage.delete(Files.lantern)
        storage.put([1, 2, 3, 4], at: Files.lanternMoved)
        storage.holdResolves()
        // The library looks for its games' files as it opens: that look waits at its first file.
        let library = makeLibrary(storage)
        #expect(await waiting(1, storage))
        let lantern = sample(library, Files.lantern)
        library.locate(lantern.id)
        library.located(Files.lanternMoved)
        #expect(await eventually { library.game(lantern.id)?.folder == "/Users/you/Games/PS1/Moved" })
        storage.letAllGo()
        #expect(await settled(library))
        #expect(!library.isMissing(sample(library, Files.lantern)), "what the look found of the old file is passed over")
        #expect(library.info(for: sample(library, Files.lantern)).action == .play)
    }

    @Test func showInFinderFindsTheFileWhereItsBookmarkLeads() async {
        let storage = sampleStorage()
        let library = makeLibrary(storage)
        #expect(await settled(library))
        library.selection = sample(library, Files.gpuTest).id
        #expect(library.fileToShowInFinder() == Files.gpuTest)
        storage.delete(Files.gpuTest)
        #expect(library.fileToShowInFinder() == nil)
        #expect(library.isMissing(sample(library, Files.gpuTest)), "a file Show in Finder can't find is flagged")
    }

    // MARK: Removing

    @Test func removingAsksFirstWithWhatItDeletesUnderDetails() async {
        let storage = sampleStorage()
        let library = makeLibrary(storage)
        #expect(await settled(library))
        let orchard = sample(library, Files.orchard)
        library.selection = orchard.id
        #expect(library.canRemoveSelected)
        library.askToRemove()
        let alert = library.alert
        #expect(alert?.title == "Remove “Glass Orchard (Europe)” from your library?")
        #expect(alert?.message == "The disc image stays on your Mac. You can add it again any time.")
        #expect(alert?.details == "Deletes its entry and bookmark from library.json in iStation’s container.\nLeaves ~/Games/PS1/Glass Orchard (Europe).cue untouched.")
        #expect(alert?.tone == .info)
        #expect(alert?.buttons == [
            LibraryAlert.Button("Cancel", role: .cancel, choice: .cancel), LibraryAlert.Button("Remove", role: .primary, choice: .remove),
        ])
        #expect(!storage.calls.contains(.removeGames), "nothing is removed until the person says so")

        library.answer(.cancel)
        #expect(library.alert == nil)
        #expect(library.games.count == 6)

        library.askToRemove()
        library.answer(.remove)
        #expect(library.game(orchard.id) == nil)
        #expect(storage.saved.games.count == 5)
        #expect(library.selection == sample(library, Files.harbor).id, "the first game is selected")

        library.askToRemove(sample(library, Files.gpuTest).id)
        #expect(library.alert?.message == "The program stays on your Mac. You can add it again any time.")
    }

    @Test func aChangeTheLibraryCantSaveSaysSoAndChangesNothing() async {
        let storage = sampleStorage()
        let library = makeLibrary(storage)
        #expect(await settled(library))
        storage.fail(.init(write: .cannotWrite(path: "/x/library.json", reason: "The disk is full.")))
        library.askToRemove()
        library.answer(.remove)
        #expect(library.alert?.title == "The library couldn’t be saved")
        #expect(library.alert?.message == "iStation couldn’t write the change to its library. Your files are as they were.")
        #expect(library.alert?.details == #"LibraryStore.removeGames(_:) threw LibraryStoreError.cannotWrite(path: "/x/library.json", reason: "The disk is full.")"#)
        #expect(library.alert?.tone == .danger)
        #expect(library.alert?.buttons == [LibraryAlert.Button("OK", role: .primary, choice: .ok)])
        #expect(library.games.count == 6)
        library.answer(.ok)
        #expect(library.alert == nil)
    }

    // MARK: Renaming

    @Test func renamingNamesTheGameInTheLibraryAlone() async {
        let storage = sampleStorage()
        let library = makeLibrary(storage)
        #expect(await settled(library))
        let program = sample(library, Files.gpuTest)
        library.rename(program.id)
        #expect(library.renaming == program.id)
        #expect(library.renameDraft == "gpu-test")
        #expect(library.isShowingSheet)
        library.renameDraft = "  GPU Test  "
        #expect(library.canSaveRename)
        library.saveRename()
        #expect(library.renaming == nil)
        let renamed = library.game(program.id)
        #expect(renamed?.name == "GPU Test")
        #expect(renamed?.fileName == "gpu-test.exe", "the file keeps its own name")
        #expect(renamed.map { library.row(for: $0).name } == "GPU Test")
        #expect(storage.calls.contains(.renameGame("GPU Test")))
    }

    @Test func aBlankOrUnchangedNameChangesNothing() async {
        let storage = sampleStorage()
        let library = makeLibrary(storage)
        #expect(await settled(library))
        library.rename()
        library.renameDraft = "   "
        #expect(!library.canSaveRename)
        library.saveRename()
        #expect(library.renaming != nil, "Rename is off while the field is blank")
        library.cancelRename()
        #expect(library.renaming == nil)
        library.rename()
        library.saveRename()
        #expect(library.renaming == nil)
        #expect(!storage.calls.contains { if case .renameGame = $0 { true } else { false } })
    }

    @Test func renamingBackToTheFilesNameTakesTheLibrarysNameAway() async {
        var games = sampleGames()
        games[4].name = "GPU Test"
        let storage = sampleStorage(games: games)
        let library = makeLibrary(storage)
        #expect(await settled(library))
        let program = sample(library, Files.gpuTest)
        library.rename(program.id)
        #expect(library.renameDraft == "GPU Test")
        library.renameDraft = "gpu-test"
        library.saveRename()
        #expect(storage.calls.contains(.renameGame(nil)))
        #expect(library.game(program.id)?.name == nil)
        #expect(library.game(program.id)?.shownName == "gpu-test")
    }

    // MARK: Add Games…

    @Test func addingGamesKeepsThemAndSelectsTheLastChosen() async {
        let storage = MemoryStorage(library: Library(bios: keptBIOS), files: [Files.orchard: [1, 2, 3], Files.gpuTest: programImage])
        let library = makeLibrary(storage)
        #expect(await settled(library))
        library.chooseGames()
        #expect(library.isChoosingGames)
        library.add([Files.orchard, Files.gpuTest])
        #expect(!library.isChoosingGames)
        #expect(await settled(library))
        #expect(library.rows.map(\.name) == ["Glass Orchard (Europe)", "gpu-test"])
        #expect(library.selection == sample(library, Files.gpuTest).id)
        #expect(library.games.allSatisfy { $0.added == today.roundedDown })
        #expect(library.alert == nil)
        #expect(storage.calls.filter { if case .addGames = $0 { true } else { false } } == [.addGames(["Glass Orchard (Europe).cue", "gpu-test.exe"])])

        library.add([Files.orchard])
        #expect(await settled(library))
        #expect(library.games.count == 2, "a file kept already is passed over")
        #expect(library.selection == sample(library, Files.orchard).id)
        #expect(storage.calls.filter { if case .addGames = $0 { true } else { false } }.count == 1, "nothing new to add, nothing written")
    }

    @Test func filesChosenWhileAnAddIsRecordedAreAddedAfterIt() async {
        let storage = MemoryStorage(library: Library(bios: keptBIOS), files: [Files.orchard: [1, 2, 3], Files.gpuTest: programImage])
        let library = makeLibrary(storage)
        #expect(await settled(library))
        storage.holdRecords()
        library.add([Files.orchard])
        #expect(await waiting(1, storage))
        #expect(library.isAdding)
        library.chooseGames()
        #expect(library.isChoosingGames, "the chooser opens again while the first choice is recorded")
        library.add([Files.gpuTest, Files.orchard])
        storage.letAllGo()
        #expect(await settled(library))
        #expect(!library.isAdding)
        #expect(library.rows.map(\.name) == ["Glass Orchard (Europe)", "gpu-test"], "the second choice is added after the first, a file both chose once")
        #expect(library.selection == sample(library, Files.orchard).id, "the second choice's last file")
        #expect(library.alert == nil)
    }

    @Test func aFileThatIsntAGamesIsRefusedAndNeverRecorded() async {
        let stream = URL(fileURLWithPath: "/Users/you/Music/stream.m3u8")
        let storage = MemoryStorage(library: Library(bios: keptBIOS), files: [Files.orchard: [1, 2, 3], stream: [7]])
        let library = makeLibrary(storage)
        #expect(await settled(library))
        library.add([Files.orchard, stream])
        #expect(await settled(library))
        #expect(library.rows.map(\.name) == ["Glass Orchard (Europe)"])
        #expect(!storage.calls.contains(.record("stream.m3u8")), "never recorded")
        #expect(library.alert?.title == "“stream.m3u8” couldn’t be added")
        #expect(library.alert?.message == "iStation’s library keeps .cue, .iso, .m3u and .exe files.")
        #expect(library.alert?.details == #"GameFormat(fileName: "stream.m3u8") returned nil"#)
        library.answer(.ok)

        let nowhere = URL(fileURLWithPath: "/Users/you/Games/nowhere.iso")
        library.add([stream, nowhere])
        #expect(await settled(library))
        #expect(library.alert?.title == "2 files couldn’t be added")
        #expect(library.alert?.message == "iStation couldn’t open these files.")
        #expect(library.alert?.details == [
            #"GameFormat(fileName: "stream.m3u8") returned nil"#,
            #"GameFiles.record(for:added:) threw KeptFileError.cannotRead(path: "/Users/you/Games/nowhere.iso", reason: "No such file.")"#,
        ].joined(separator: "\n"))
    }

    @Test func aFileThatCantBeAddedIsNamedAndTheRestAreAdded() async {
        let storage = MemoryStorage(library: Library(bios: keptBIOS), files: [Files.orchard: [1, 2, 3]])
        let library = makeLibrary(storage)
        #expect(await settled(library))
        let nowhere = URL(fileURLWithPath: "/Users/you/Games/nowhere.iso")
        library.add([Files.orchard, nowhere])
        #expect(await settled(library))
        #expect(library.rows.map(\.name) == ["Glass Orchard (Europe)"])
        #expect(library.alert?.title == "“nowhere.iso” couldn’t be added")
        #expect(library.alert?.message == "iStation couldn’t open this file.")
        #expect(library.alert?.details == #"GameFiles.record(for:added:) threw KeptFileError.cannotRead(path: "/Users/you/Games/nowhere.iso", reason: "No such file.")"#)
        library.answer(.ok)
        library.add([nowhere, URL(fileURLWithPath: "/Users/you/Games/elsewhere.cue")])
        #expect(await settled(library))
        #expect(library.alert?.title == "2 files couldn’t be added")
        #expect(library.alert?.message == "iStation couldn’t open these files.")
    }

    // MARK: Keys, the toolbar and the layout

    @Test func keysAndButtonsDoNothingUnderASheetOrAlert() async {
        let session = FakePowerSession()
        let storage = sampleStorage()
        let library = makeLibrary(storage, session: session)
        #expect(await settled(library))
        library.selection = sample(library, Files.gpuTest).id
        library.rename()
        #expect(!library.canAct)
        #expect(!library.canPlaySelected)
        #expect(!library.canRemoveSelected)
        library.play()
        library.askToRemove()
        library.chooseGames()
        library.chooseFolder()
        library.go(to: .bios)
        #expect(library.opening.state == .idle)
        #expect(library.alert == nil)
        #expect(!library.isChoosingGames)
        #expect(!library.scan.isChoosingFolder)
        #expect(library.place == .allGames)
        library.cancelRename()
        #expect(library.canAct)
        library.chooseFolder()
        #expect(library.scan.isChoosingFolder)
        #expect(!library.canAct, "the folder chooser is open")
        #expect(await session.calls.isEmpty)
    }

    @Test func nothingActsWhileAnotherScreensSheetCoversTheLibrary() async {
        let cover = Cover()
        let session = FakePowerSession()
        let library = LibraryViewModel(
            storage: sampleStorage(), session: session, home: Files.home, calendar: utc, now: { today },
            isCovered: { cover.isOn }, onRun: { _ in }
        )
        #expect(await settled(library))
        library.select(sample(library, Files.gpuTest).id)
        #expect(library.canAct)
        cover.isOn = true
        #expect(!library.canAct, "the BIOS check's chooser or sheet, or the BIOS pane's alert, is over the window")
        #expect(!library.canPlaySelected)
        #expect(!library.canRemoveSelected)
        library.chooseGames()
        library.chooseFolder()
        library.play()
        library.askToRemove()
        library.rename()
        library.locate()
        library.go(to: .recentlyPlayed)
        #expect(!library.isChoosingGames)
        #expect(!library.scan.isChoosingFolder)
        #expect(library.opening.state == .idle)
        #expect(library.alert == nil)
        #expect(library.renaming == nil)
        #expect(!library.isLocating)
        #expect(library.place == .allGames)
        cover.isOn = false
        #expect(library.canAct)
        #expect(library.canPlaySelected)
        library.chooseGames()
        #expect(library.isChoosingGames)
        #expect(await session.calls.isEmpty)
    }

    @Test func playAndRemoveKeysGiveWayToTheSearchField() async {
        let library = makeLibrary()
        #expect(await settled(library))
        library.select(sample(library, Files.gpuTest).id)
        #expect(library.canPlaySelected)
        #expect(library.canRemoveSelected)
        library.isSearchFocused = true
        #expect(!library.canPlaySelected, "Return is the search field's")
        #expect(!library.canRemoveSelected, "⌘⌫ is the search field's")
        #expect(library.canAct, "Game info's buttons and the toolbar still act")
        library.isSearchFocused = false
        #expect(library.canPlaySelected)
        #expect(library.canRemoveSelected)
    }

    @Test func aSelectionASearchAndAViewAreThePersonsToMake() async {
        let library = makeLibrary()
        #expect(await settled(library))
        let tidepool = sample(library, Files.tidepool)
        library.select(tidepool.id)
        #expect(library.selectedGame == tidepool)
        library.search(for: "TIDE")
        #expect(library.rows.map(\.name) == ["Tidepool"])
        library.showGames(as: .grid)
        #expect(library.viewMode == .grid)
        library.clearSearch()
        library.select(nil)
        #expect(library.selectedGame == nil)
        #expect(library.rows.count == 6)
    }

    @Test func theGameMenuStaysTheLibrarysWhileAPSEXEOpens() async {
        // The player follows its session across a stop, so from the second PS-EXE on it plays as soon as the
        // job powers the session on: while the opening sheet shows, the library keeps the window and the
        // Game menu stays off, whatever the player says.
        let session = FakePowerSession()
        let library = makeLibrary(sampleStorage(), session: session)
        #expect(await settled(library))
        #expect(library.playerHoldsWindow(whilePlaying: true))
        #expect(!library.playerHoldsWindow(whilePlaying: false))
        library.play(sample(library, Files.gpuTest).id)
        #expect(await followed(session))
        #expect(library.opening.state == .running(.start))
        #expect(!library.playerHoldsWindow(whilePlaying: true), "the library and its opening sheet keep the window, and the Game menu off")
        await session.run(to: 120, reachedShell: true)
        #expect(await eventually { library.playerHoldsWindow(whilePlaying: true) })
        #expect(!library.playerHoldsWindow(whilePlaying: false))
    }

    @Test func aCancelledRunLeavesTheWindowTheLibrarysUntilItsStopLands() async {
        // A Cancel closes the sheet at once and sends the stop: until it lands the console the job powered on
        // runs, and a player following the session plays it, but nothing the person chose is playing.
        let session = FakePowerSession()
        let library = makeLibrary(sampleStorage(), session: session)
        #expect(await settled(library))
        library.play(sample(library, Files.gpuTest).id)
        #expect(await followed(session))
        await session.holdStops()
        library.opening.cancel()
        #expect(!library.opening.isShowingJob)
        #expect(library.opening.isStopping)
        #expect(await holdingStops(1, session))
        #expect(!library.playerHoldsWindow(whilePlaying: true), "the library keeps the window while the stop is on its way")
        await session.letStopsGo()
        #expect(await settled(library))
        #expect(!library.opening.isStopping)
        #expect(await session.snapshot.state == .stopped)
        #expect(library.playerHoldsWindow(whilePlaying: true))
    }

    @Test func hidingTheSidebarForGameInfoIsTheBreakpointsNotThePersons() async {
        let library = makeLibrary()
        #expect(await settled(library))
        library.toggleInfo()
        #expect(!library.layout(windowWidth: 1_000).showsSidebar, "under 1,100 Game info hides the sidebar")
        // The split view follows the breakpoint, and says it hid the sidebar.
        library.splitViewShowsSidebar(false)
        #expect(library.isShowingSidebar, "the person still wants the sidebar")
        library.toggleInfo()
        #expect(library.layout(windowWidth: 1_000).showsSidebar, "it comes back once Game info closes")
        library.toggleInfo()
        #expect(library.layout(windowWidth: 1_280).showsSidebar, "and at 1,280 with Game info")

        // Without Game info, the split view hiding the sidebar is the person's doing, as ⌃⌘S is.
        library.toggleInfo()
        library.splitViewShowsSidebar(false)
        #expect(!library.isShowingSidebar)
        #expect(!library.layout(windowWidth: 1_280).showsSidebar)
        library.splitViewShowsSidebar(true)
        #expect(library.isShowingSidebar)
    }

    @Test func theLeastWindowHoldsTheGamesBesideTheSidebarAndGameInfo() {
        // The split view counts the sidebar twice in its least width once its detail has an inspector
        // (measured, 2026-11-23: 220 + 220 + the games' least), so the games' least leaves room for that.
        // It shows the sidebar and Game info together for a moment in any window — as the window narrows
        // past 1,100 with Game info open, before the breakpoint hides the sidebar, and as Game info closes
        // and the sidebar comes back — and AppKit throws ("more Update Constraints in Window passes than
        // there are views") when the two and the games' least don't fit: so they fit the least window.
        let sizes = Metrics.mac
        #expect(sizes.windowMinWidth - 2 * sizes.sidebar - sizes.inspector >= sizes.gamesMinWidth, "800 beside both")
        #expect(sizes.windowMinWidth - 2 * sizes.sidebar >= sizes.gamesMinWidth, "800 beside the sidebar, Game info closed")
        #expect(sizes.windowMinWidth - sizes.inspector >= sizes.gamesMinWidth, "800 beside Game info, the sidebar hidden")
        #expect(sizes.gamesMinWidth > 0)
    }

    @Test func theToolbarsSidebarButtonSaysWhatItDoes() {
        let library = makeLibrary()
        #expect(library.sidebarButton.title == "Hide the sidebar")
        #expect(library.sidebarButton.help == "Hide the sidebar (⌃⌘S)")
        library.toggleSidebar()
        #expect(!library.isShowingSidebar)
        #expect(library.sidebarButton.title == "Show the sidebar")
        #expect(library.sidebarButton.help == "Show the sidebar (⌃⌘S)")
    }

    @Test func theLayoutPagesBreakpointsHold() {
        let all = LibraryLayout.Column.allCases
        let wide = LibraryLayout(windowWidth: 1_280, wantsSidebar: true, showsInfo: false, sizes: Metrics.mac)
        #expect(wide.showsSidebar)
        #expect(wide.contentWidth == 1_060)
        #expect(wide.columns == all)
        let withInfo = LibraryLayout(windowWidth: 1_280, wantsSidebar: true, showsInfo: true, sizes: Metrics.mac)
        #expect(withInfo.showsSidebar, "1,280 wide with Game info keeps the sidebar")
        #expect(withInfo.contentWidth == 760)
        #expect(withInfo.columns == [.name, .console, .serial, .size, .lastPlayed], "under 880, no Format")
        let narrow = LibraryLayout(windowWidth: 1_099, wantsSidebar: true, showsInfo: true, sizes: Metrics.mac)
        #expect(!narrow.showsSidebar, "under 1,100 Game info hides the sidebar")
        #expect(narrow.contentWidth == 799)
        let edge = LibraryLayout(windowWidth: 1_100, wantsSidebar: true, showsInfo: true, sizes: Metrics.mac)
        #expect(edge.showsSidebar)
        #expect(edge.columns == [.name, .console, .serial, .size], "under 700, no Last played")
        let least = LibraryLayout(windowWidth: 800, wantsSidebar: true, showsInfo: false, sizes: Metrics.mac)
        #expect(least.contentWidth == 580, "Mac-LibraryMin")
        #expect(least.columns == [.name, .console, .serial, .size])
        let hidden = LibraryLayout(windowWidth: 800, wantsSidebar: false, showsInfo: false, sizes: Metrics.mac)
        #expect(hidden.contentWidth == 800)
        #expect(hidden.columns == [.name, .console, .serial, .size, .lastPlayed])
        #expect(LibraryLayout.columns(contentWidth: 880, sizes: Metrics.mac) == all)
        #expect(LibraryLayout.columns(contentWidth: 879, sizes: Metrics.mac) == [.name, .console, .serial, .size, .lastPlayed])
        #expect(LibraryLayout.columns(contentWidth: 700, sizes: Metrics.mac).contains(.lastPlayed))
        #expect(!LibraryLayout.columns(contentWidth: 699, sizes: Metrics.mac).contains(.lastPlayed))
    }

    @Test func theWindowsLayoutFollowsGameInfoAsItShows() async {
        let library = makeLibrary()
        #expect(await settled(library))
        library.isShowingInfo = true
        #expect(!library.layout(windowWidth: 1_000).showsSidebar)
        library.selection = nil
        #expect(library.layout(windowWidth: 1_000).showsSidebar, "Game info without a game isn't shown")
        #expect(library.layout(windowWidth: 1_000).contentWidth == 1_000 - Metrics.layout.sidebar)
    }
}

extension Date {
    /// This moment to the whole second, as the library keeps dates.
    var roundedDown: Date { Date(timeIntervalSinceReferenceDate: timeIntervalSinceReferenceDate.rounded(.down)) }
}
