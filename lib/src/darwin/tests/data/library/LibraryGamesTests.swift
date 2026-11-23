// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import DataLibrary
import Foundation
import SupportSandbox
import Testing

/// The games through `LibraryStore`, every `library.json` inside a `Sandbox`: a library of games round
/// tripping, adding them without duplicates, renaming, removing, marking one played and keeping one
/// by the file it was found as, and the calls on a game the library doesn't keep refused. The records
/// are made up: no file is behind their bookmarks.
@Suite struct LibraryGamesTests {
    /// A whole-second date, as the file keeps one.
    static let today = Date(timeIntervalSince1970: 1_795_343_400) // 2026-11-22T10:30:00Z

    /// A game of made-up values at `folder`/`fileName`.
    static func game(_ fileName: String, in folder: String = "/Volumes/Archive/Games/PS1", format: GameFormat = .cue,
                     added: Date = today) -> GameRecord {
        GameRecord(fileName: fileName, folder: folder, format: format, size: 1_000, added: added,
                   bookmark: Data(fileName.utf8))
    }

    static let orchard = game("Glass Orchard (Europe).cue")
    static let courier = game("Moonbase Courier.iso", format: .iso)
    static let program = game("gpu-test.exe", in: "/Volumes/Archive/Games/Homebrew", format: .psexe)

    /// A store at a `library.json` in `sandbox`, not written yet.
    func store(in sandbox: Sandbox) -> LibraryStore {
        LibraryStore(url: sandbox.url("Container/library.json"))
    }

    // MARK: Round trip

    @Test func aLibraryOfGamesRoundTripsThroughTheFile() throws {
        let sandbox = try Sandbox()
        let store = store(in: sandbox)
        var tidepool = Self.game("Tidepool.m3u", in: "/Volumes/Archive/Games/PS1/Tidepool", format: .m3u)
        tidepool.discs = ["Tidepool (Disc 1).cue", "Tidepool (Disc 2).cue"]
        tidepool.lastPlayed = Self.today
        var orchard = Self.orchard
        orchard.tracks = ["Glass Orchard (Europe).bin"]
        orchard.name = "Glass Orchard"
        let library = Library(bios: LibraryStoreTests.record, games: [orchard, tidepool, Self.program])
        try store.save(library)
        let loaded = try LibraryStore(url: store.url).load() // a fresh store: everything came from the file
        #expect(loaded == library)
        #expect(loaded.version == 2)
        #expect(loaded.games.map(\.id) == [orchard.id, tidepool.id, Self.program.id], "in the order added")
    }

    // MARK: Adding

    @Test func addingGamesKeepsThemAndSaysWhichWereAdded() throws {
        let sandbox = try Sandbox()
        let store = store(in: sandbox)
        let result = try store.addGames([Self.orchard, Self.courier])
        #expect(result.added == [Self.orchard, Self.courier])
        #expect(result.library == Library(games: [Self.orchard, Self.courier]))
        #expect(try store.load() == result.library)
    }

    @Test func addingAGameAlreadyKeptSkipsItSoAFolderScannedAgainAddsNoDuplicate() throws {
        let sandbox = try Sandbox()
        let store = store(in: sandbox)
        try store.addGames([Self.orchard, Self.courier])
        // Scan Again: the same files found again, as new records with new ids, and one more.
        let again = [Self.game("Glass Orchard (Europe).cue"), Self.game("Moonbase Courier.iso", format: .iso), Self.program]
        let result = try store.addGames(again)
        #expect(result.added.map(\.fileName) == ["gpu-test.exe"])
        #expect(try store.load().games.map(\.id) == [Self.orchard.id, Self.courier.id, again[2].id], "the games kept before keep their ids")
    }

    @Test func aFileIsTheSameGameHoweverItsPathIsSpelt() throws {
        let sandbox = try Sandbox()
        let store = store(in: sandbox)
        try store.addGames([Self.orchard])
        let spellings = [
            Self.game("Glass Orchard (Europe).cue", in: "/Volumes/Archive/Games/PS1/"),
            Self.game("Glass Orchard (Europe).cue", in: "/Volumes/Archive/Games/./PS1"),
            Self.game("Glass Orchard (Europe).cue", in: "/Volumes/Archive/Games/Homebrew/../PS1"),
        ]
        #expect(try store.addGames(spellings).added.isEmpty)
        #expect(try store.load().games == [Self.orchard])
    }

    @Test func aFileGivenTwiceInOneAddIsAddedOnce() throws {
        let sandbox = try Sandbox()
        let store = store(in: sandbox)
        let twice = Self.game("Glass Orchard (Europe).cue")
        let result = try store.addGames([Self.orchard, twice, Self.orchard])
        #expect(result.added == [Self.orchard])
        #expect(try store.load().games == [Self.orchard])
    }

    @Test func addingNothingNewWritesNothing() throws {
        let sandbox = try Sandbox()
        let store = store(in: sandbox)
        #expect(try store.addGames([]).added.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: store.url.path), "no file made for nothing")
        try store.addGames([Self.orchard])
        let before = try Data(contentsOf: store.url)
        #expect(try store.addGames([Self.game("Glass Orchard (Europe).cue")]).added.isEmpty)
        #expect(try Data(contentsOf: store.url) == before)
    }

    @Test func aGameIsAddedWithItsDatesToTheWholeSecond() throws {
        let sandbox = try Sandbox()
        let store = store(in: sandbox)
        var game = Self.game("Glass Orchard (Europe).cue", added: Self.today.addingTimeInterval(0.75))
        game.lastPlayed = Self.today.addingTimeInterval(-0.25)
        let added = try #require(try store.addGames([game]).added.first)
        #expect(added.added == Self.today)
        #expect(added.lastPlayed == Self.today.addingTimeInterval(-1))
        #expect(try store.load().games == [added], "what the call returned is what the file holds")
    }

    @Test func addingGamesToAVersion1LibraryKeepsItsBIOS() throws {
        let sandbox = try Sandbox()
        let url = try sandbox.write(Data(contentsOf: LibraryStoreTests.fixtures.appendingPathComponent("library-v1.json")), to: "library.json")
        let store = LibraryStore(url: url)
        let result = try store.addGames([Self.program])
        #expect(result.library.version == 2)
        let loaded = try store.load()
        #expect(loaded.version == 2)
        #expect(loaded.bios == LibraryStoreTests.record)
        #expect(loaded.games == [Self.program])
    }

    @Test func keepingABIOSKeepsTheGames() throws {
        let sandbox = try Sandbox()
        let store = store(in: sandbox)
        try store.addGames([Self.orchard])
        try store.keepBIOS(LibraryStoreTests.record)
        #expect(try store.load() == Library(bios: LibraryStoreTests.record, games: [Self.orchard]))
        try store.forgetBIOS()
        #expect(try store.load() == Library(games: [Self.orchard]))
    }

    // MARK: Renaming

    @Test func renamingAGameNamesItInTheLibraryAlone() throws {
        let sandbox = try Sandbox()
        let store = store(in: sandbox)
        try store.addGames([Self.orchard, Self.program])
        let renamed = try store.renameGame(Self.program.id, to: "  GPU test \n")
        let game = try #require(renamed.game(Self.program.id))
        #expect(game.name == "GPU test", "trimmed")
        #expect(game.shownName == "GPU test")
        #expect(game.fileName == "gpu-test.exe", "the file keeps its own name")
        #expect(try store.load() == renamed)
        #expect(renamed.game(Self.orchard.id) == Self.orchard, "the others are as they were")
    }

    @Test(arguments: ["", "   ", nil] as [String?])
    func anEmptyNameShowsTheFilesNameAgain(name: String?) throws {
        let sandbox = try Sandbox()
        let store = store(in: sandbox)
        try store.addGames([Self.program])
        try store.renameGame(Self.program.id, to: "GPU test")
        let renamed = try store.renameGame(Self.program.id, to: name)
        #expect(renamed.game(Self.program.id)?.name == nil)
        #expect(try store.load().game(Self.program.id)?.shownName == "gpu-test")
    }

    // MARK: Removing

    @Test func removingGamesLeavesTheOthersAndPassesOverOnesNotKept() throws {
        let sandbox = try Sandbox()
        let store = store(in: sandbox)
        try store.addGames([Self.orchard, Self.courier, Self.program])
        let left = try store.removeGames([Self.courier.id, UUID()])
        #expect(left.games == [Self.orchard, Self.program])
        #expect(try store.load() == left)
        // A file the game named is no business of the store's: nothing but library.json is touched.
        #expect(try FileManager.default.contentsOfDirectory(atPath: store.url.deletingLastPathComponent().path) == ["library.json"])
    }

    @Test func removingOnlyGamesNotKeptWritesNothing() throws {
        let sandbox = try Sandbox()
        let store = store(in: sandbox)
        try store.addGames([Self.orchard])
        let before = try Data(contentsOf: store.url)
        #expect(try store.removeGames([UUID()]).games == [Self.orchard])
        #expect(try Data(contentsOf: store.url) == before)
        #expect(try store.removeGames([]).games == [Self.orchard])
    }

    // MARK: Played

    @Test func markingAGamePlayedNotesTheWholeSecond() throws {
        let sandbox = try Sandbox()
        let store = store(in: sandbox)
        try store.addGames([Self.orchard, Self.program])
        let played = try store.markPlayed(Self.program.id, at: Self.today.addingTimeInterval(3_600.6))
        #expect(played.game(Self.program.id)?.lastPlayed == Self.today.addingTimeInterval(3_600))
        #expect(played.game(Self.orchard.id)?.lastPlayed == nil)
        #expect(try store.load() == played)
    }

    // MARK: Found somewhere else

    @Test func aGameFoundSomewhereElseKeepsItsIdNameAndDates() throws {
        let sandbox = try Sandbox()
        let store = store(in: sandbox)
        try store.addGames([Self.orchard, Self.courier])
        try store.renameGame(Self.orchard.id, to: "Glass Orchard")
        try store.markPlayed(Self.orchard.id, at: Self.today)
        var found = Self.game("Glass Orchard.cue", in: "/Volumes/Archive/Games/PS1/Moved", added: Self.today.addingTimeInterval(86_400))
        found.size = 2_048
        found.tracks = ["Glass Orchard.bin"]
        let library = try store.relocateGame(Self.orchard.id, to: found)
        let game = try #require(library.game(Self.orchard.id))
        #expect(game.fileName == "Glass Orchard.cue")
        #expect(game.folder == "/Volumes/Archive/Games/PS1/Moved")
        #expect(game.bookmark == found.bookmark)
        #expect(game.size == 2_048)
        #expect(game.tracks == ["Glass Orchard.bin"])
        #expect(game.name == "Glass Orchard")
        #expect(game.added == Self.orchard.added)
        #expect(game.lastPlayed == Self.today)
        #expect(library.games.map(\.id) == [Self.orchard.id, Self.courier.id], "in its place")
        #expect(try store.load() == library)
        // Its old file is now free: added again, it is a game of its own.
        #expect(try store.addGames([Self.game("Glass Orchard (Europe).cue")]).added.count == 1)
    }

    @Test func aGameFoundWhereItWasIsKeptByItsNewBookmark() throws {
        let sandbox = try Sandbox()
        let store = store(in: sandbox)
        try store.addGames([Self.orchard])
        var found = Self.orchard
        found.bookmark = Data("a new bookmark".utf8)
        let library = try store.relocateGame(Self.orchard.id, to: found)
        #expect(library.game(Self.orchard.id)?.bookmark == Data("a new bookmark".utf8))
    }

    @Test func aGameCantBeKeptByAnotherGamesFile() throws {
        let sandbox = try Sandbox()
        let store = store(in: sandbox)
        try store.addGames([Self.orchard, Self.courier])
        let before = try Data(contentsOf: store.url)
        let courierAgain = Self.game("Moonbase Courier.iso", format: .iso)
        #expect(throws: LibraryStoreError.alreadyKept(path: Self.courier.path)) {
            try store.relocateGame(Self.orchard.id, to: courierAgain)
        }
        #expect(try Data(contentsOf: store.url) == before)
    }

    @Test func gamesFoundSomewhereElseAreKeptAgainInOneSave() throws {
        // The library's look, after a folder of games was renamed: every one moved in one load and one
        // save, each keeping its id, name and dates, a game gone meanwhile or onto another's file passed over.
        let sandbox = try Sandbox()
        let store = store(in: sandbox)
        try store.addGames([Self.orchard, Self.courier, Self.program])
        try store.renameGame(Self.courier.id, to: "Courier")
        let moved = "/Volumes/Archive/Games/PS1 Collection"
        let orchardThere = Self.game("Glass Orchard (Europe).cue", in: moved, added: Self.today.addingTimeInterval(60))
        let courierThere = Self.game("Moonbase Courier.iso", in: moved, format: .iso)
        let library = try store.relocateGames([
            Self.orchard.id: orchardThere, Self.courier.id: courierThere,
            UUID(): Self.game("Removed meanwhile.iso", in: moved, format: .iso),
            Self.program.id: Self.game("Glass Orchard (Europe).cue", in: moved),
        ])
        #expect(library.games.map(\.folder) == [moved, moved, Self.program.folder], "the program's new file is the orchard's: passed over")
        #expect(library.games.map(\.id) == [Self.orchard.id, Self.courier.id, Self.program.id])
        #expect(library.game(Self.courier.id)?.name == "Courier")
        #expect(library.game(Self.orchard.id)?.added == Self.orchard.added)
        #expect(try store.load() == library)

        let before = try Data(contentsOf: store.url)
        #expect(try store.relocateGames([UUID(): courierThere]).games == library.games)
        #expect(try Data(contentsOf: store.url) == before, "nothing relocated, nothing written")
    }

    // MARK: A game the library doesn't keep

    @Test func callsOnAGameTheLibraryDoesntKeepAreRefusedAndWriteNothing() throws {
        let sandbox = try Sandbox()
        let store = store(in: sandbox)
        try store.addGames([Self.orchard])
        let before = try Data(contentsOf: store.url)
        let gone = UUID()
        #expect(throws: LibraryStoreError.noSuchGame(gone)) { try store.renameGame(gone, to: "Anything") }
        #expect(throws: LibraryStoreError.noSuchGame(gone)) { try store.markPlayed(gone, at: Self.today) }
        #expect(throws: LibraryStoreError.noSuchGame(gone)) { try store.relocateGame(gone, to: Self.courier) }
        #expect(try Data(contentsOf: store.url) == before)
    }

    @Test func theLibraryFindsAGameByIdOrByItsFile() {
        let library = Library(games: [Self.orchard, Self.program])
        #expect(library.game(Self.program.id) == Self.program)
        #expect(library.game(UUID()) == nil)
        #expect(library.game(at: URL(fileURLWithPath: "/Volumes/Archive/Games/PS1/./Glass Orchard (Europe).cue")) == Self.orchard)
        #expect(library.game(at: URL(fileURLWithPath: "/Volumes/Archive/Games/PS1/Moonbase Courier.iso")) == nil)
    }
}
