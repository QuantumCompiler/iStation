// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import DataLibrary
import Foundation
import SupportSandbox
import Testing

/// A game's record as `library.json` keeps it: its format read leniently, every field's default, the
/// name the library shows and the path that tells two games apart. Files only inside a `Sandbox`.
@Suite struct GameRecordTests {
    /// Reads `text`, a whole `library.json`, from a file in `sandbox`.
    func load(_ text: String, in sandbox: Sandbox) throws -> Library {
        try LibraryStore(url: sandbox.write(text, to: "library.json")).load()
    }

    // MARK: The format

    @Test(arguments: [
        ("Glass Orchard (Europe).cue", GameFormat.cue), ("Moonbase Courier.ISO", .iso),
        ("Tidepool.m3u", .m3u), ("gpu-test.exe", .psexe), ("GPU-TEST.EXE", .psexe),
    ])
    func aGameIsKnownByItsExtensionInAnyCase(fileName: String, format: GameFormat) {
        #expect(GameFormat(fileName: fileName) == format)
    }

    @Test(arguments: ["Glass Orchard (Europe).bin", "my-console-bios.bin", "notes.txt", "Tidepool", ".cue", "cue"])
    func aFileTheLibraryDoesntKeepHasNoFormat(fileName: String) {
        #expect(GameFormat(fileName: fileName) == nil)
    }

    @Test func eachFormatIsWrittenByItsExtensionAndReadBack() {
        #expect([GameFormat.cue, .iso, .m3u, .psexe].map(\.rawValue) == ["cue", "iso", "m3u", "exe"])
        for format in [GameFormat.cue, .iso, .m3u, .psexe, .unknown("chd")] {
            #expect(GameFormat(rawValue: format.rawValue) == format)
        }
    }

    @Test func aFormatThisBuildDoesntKnowIsKeptNotRefused() throws {
        let sandbox = try Sandbox()
        let url = try sandbox.write(#"{"version": 2, "games": [{"fileName": "Night Ferry.chd", "format": "chd"}]}"#, to: "library.json")
        let store = LibraryStore(url: url)
        let game = try #require(try store.load().games.first)
        #expect(game.format == .unknown("chd"))
        // Saved again, it is written as it was read.
        try store.save(try store.load())
        let written = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let games = written?["games"] as? [[String: Any]]
        #expect(games?.first?["format"] as? String == "chd")
        #expect(try store.load().games.first?.format == .unknown("chd"))
    }

    // MARK: Defaults

    @Test func everyFieldOfAGameHasItsDefault() throws {
        let sandbox = try Sandbox()
        let library = try load(#"{"version": 2, "games": [{}], "aFieldALaterVersionAdds": true}"#, in: sandbox)
        let game = try #require(library.games.first)
        #expect(game.fileName == "")
        #expect(game.folder == "")
        #expect(game.format == .unknown(""))
        #expect(game.size == 0)
        #expect(game.added == .distantPast)
        #expect(game.lastPlayed == nil)
        #expect(game.name == nil)
        #expect(game.bookmark == Data())
        #expect(game.tracks == [])
        #expect(game.discs == [])
    }

    @Test func aGameWithoutItsFormatTakesTheOneItsFileNameSays() throws {
        let sandbox = try Sandbox()
        let library = try load(#"{"version": 2, "games": [{"fileName": "Tidepool.m3u"}, {"fileName": "gpu-test.exe"}, {"fileName": "notes.txt"}]}"#, in: sandbox)
        #expect(library.games.map(\.format) == [.m3u, .psexe, .unknown("")])
    }

    @Test func aGameWithoutAnIdIsTheSameGameEveryTimeItIsRead() throws {
        let sandbox = try Sandbox()
        let text = #"{"version": 2, "games": [{"fileName": "a.cue", "folder": "/Volumes/Archive"}, {"fileName": "b.cue", "folder": "/Volumes/Archive"}]}"#
        let url = try sandbox.write(text, to: "library.json")
        let store = LibraryStore(url: url)
        let first = try store.load().games.map(\.id)
        let second = try store.load().games.map(\.id)
        #expect(first == second, "read twice, the same ids")
        #expect(Set(first).count == 2, "two files, two games")
        // So a call by that id finds it, and the save writes the id down.
        try store.renameGame(first[1], to: "Second")
        let renamed = try store.load()
        #expect(renamed.games.map(\.id) == first)
        #expect(renamed.game(first[1])?.name == "Second")
        let written = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let ids = (written?["games"] as? [[String: Any]])?.compactMap { $0["id"] as? String }
        #expect(ids == first.map(\.uuidString))
    }

    @Test func twoRecordsOfOneIdAreTwoGamesOnceRead() throws {
        // Two records without ids for the same file and bookmark, and two a hand gave the same id: every game
        // read has an id of its own, the same each time the file is read, so a call by one reaches only it.
        let sandbox = try Sandbox()
        let shared = "0F8D3F8C-61D8-4B6C-9B7B-1F3E1F27C0DE"
        let text = """
        {"version": 2, "games": [
          {"fileName": "a.iso", "folder": "/Volumes/Archive", "bookmark": "AAEC"},
          {"fileName": "a.iso", "folder": "/Volumes/Archive", "bookmark": "AAEC"},
          {"id": "\(shared)", "fileName": "b.iso", "folder": "/Volumes/Archive"},
          {"id": "\(shared)", "fileName": "c.iso", "folder": "/Volumes/Archive"}
        ]}
        """
        let store = LibraryStore(url: try sandbox.write(text, to: "library.json"))
        let ids = try store.load().games.map(\.id)
        #expect(Set(ids).count == 4, "ids: \(ids)")
        #expect(try store.load().games.map(\.id) == ids, "read twice, the same ids")
        #expect(ids[2].uuidString == shared, "the first record keeps the id it was written with")
        try store.renameGame(ids[3], to: "Third")
        #expect(try store.load().games.map(\.name) == [nil, nil, nil, "Third"])
        try store.removeGames([ids[1]])
        #expect(try store.load().games.map(\.id) == [ids[0], ids[2], ids[3]], "removing one leaves its twin")
    }

    // MARK: The name shown

    @Test func aGameIsShownByItsFileNameWithoutItsExtensionUntilItIsRenamed() {
        var game = GameRecord(fileName: "Glass Orchard (Europe).cue", folder: "/Volumes/Archive/Games", format: .cue,
                              size: 0, added: .distantPast, bookmark: Data())
        #expect(game.shownName == "Glass Orchard (Europe)")
        game.name = "Glass Orchard"
        #expect(game.shownName == "Glass Orchard")
        game.name = "  "
        #expect(game.shownName == "Glass Orchard (Europe)", "an empty name shows the file's")
        game.name = nil
        game.fileName = ".cue"
        #expect(game.shownName == ".cue", "a name that is all extension is shown whole")
        game.fileName = "gpu-test"
        #expect(game.shownName == "gpu-test")
    }

    // MARK: The path

    @Test func aGamesPathIsStandardized() {
        let game = GameRecord(fileName: "a.cue", folder: "/Volumes/Archive/Games/./PS1/../PS1/", format: .cue,
                              size: 0, added: .distantPast, bookmark: Data())
        #expect(game.path == "/Volumes/Archive/Games/PS1/a.cue")
        #expect(game.path == GameRecord.standardizedPath(of: URL(fileURLWithPath: "/Volumes/Archive/Games/PS1/a.cue")))
        let unplaced = GameRecord(fileName: "a.cue", folder: "", format: .cue, size: 0, added: .distantPast, bookmark: Data())
        #expect(unplaced.path == "a.cue")
    }

    @Test func theSystemsTwoSpellingsOfItsTemporaryFolderAreOnePath() throws {
        // The temporary folder is behind a symbolic link (/var → /private/var): a bookmark and a folder's
        // listing spell it one way, the folder the test was given the other.
        let sandbox = try Sandbox()
        let url = try sandbox.write("FILE \"a.bin\" BINARY\n", to: "a.cue")
        let spelt = url.path.hasPrefix("/private/") ? String(url.path.dropFirst("/private".count)) : "/private" + url.path
        let other = URL(fileURLWithPath: spelt)
        #expect(FileManager.default.fileExists(atPath: other.path), "the same file, by its other spelling")
        #expect(other.path != url.path)
        let game = GameRecord(fileName: "a.cue", folder: other.deletingLastPathComponent().path, format: .cue,
                              size: 0, added: .distantPast, bookmark: Data())
        #expect(game.path == GameRecord.standardizedPath(of: url))
        #expect(GameRecord.standardizedPath(of: other) == GameRecord.standardizedPath(of: url))
    }
}
