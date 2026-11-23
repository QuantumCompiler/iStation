// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import DataLibrary
import Foundation
import SupportSandbox
import Testing

/// `library.json` through `LibraryStore`, every file inside a `Sandbox`: the round trip, an empty
/// library before the first save, corrupt, foreign and newer files refused and left as they are, and
/// the recorded shapes in `Fixtures/` decoding with defaults — version 1's, which this build reads and
/// saves again as version 2, and version 2's, pinned both ways (ADR 0016 §5). The games' own calls are
/// `LibraryGamesTests`'.
@Suite struct LibraryStoreTests {
    /// The recorded fixtures, beside this file: read from the repository, never written.
    static let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures")

    /// A whole-second date, as the file keeps one.
    static let checked = Date(timeIntervalSince1970: 1_795_343_400) // 2026-11-22T10:30:00Z

    /// A BIOS record of made-up values: no real file is behind it.
    static let record = BIOSRecord(fileName: "my-console-bios.bin", folder: "/Volumes/Archive/Console", size: 524_288,
                                   sha1: "6a521e1d2a632c26e53b83d2cc4b0edecfc1e68c", checked: checked, bookmark: Data("bookmark".utf8))

    // MARK: Round trip

    @Test func aKeptBIOSRoundTripsThroughTheFile() throws {
        let sandbox = try Sandbox()
        let url = sandbox.url("Container/Library/library.json") // its folders aren't there yet
        let store = LibraryStore(url: url)
        let saved = try store.keepBIOS(Self.record)
        #expect(saved == Library(bios: Self.record))
        #expect(FileManager.default.fileExists(atPath: url.path))
        let loaded = try LibraryStore(url: url).load() // a fresh store: everything came from the file
        #expect(loaded == saved)
        #expect(loaded.version == Library.currentVersion)
        #expect(loaded.bios == Self.record)
    }

    @Test func savingReplacesTheFileAndLeavesNothingElseBeside() throws {
        let sandbox = try Sandbox()
        let folder = try sandbox.makeFolder("Library")
        let store = LibraryStore(url: folder.appendingPathComponent("library.json"))
        try store.save(Library())
        try store.save(Library(bios: Self.record))
        #expect(try store.load().bios == Self.record)
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path) == ["library.json"])
    }

    @Test func keepingABIOSReplacesTheOneBefore() throws {
        let sandbox = try Sandbox()
        let store = LibraryStore(url: sandbox.url("library.json"))
        try store.keepBIOS(Self.record)
        var another = Self.record
        another.fileName = "bios-backup.bin"
        another.sha1 = "a9993e364706816aba3e25717850c26c9cd0d89d"
        try store.keepBIOS(another)
        #expect(try store.load().bios == another)
    }

    @Test func forgettingTheBIOSLeavesAnEmptyLibrary() throws {
        let sandbox = try Sandbox()
        let store = LibraryStore(url: sandbox.url("library.json"))
        try store.keepBIOS(Self.record)
        let forgotten = try store.forgetBIOS()
        #expect(forgotten == Library())
        #expect(try store.load() == Library())
        #expect(try store.load().bios == nil)
    }

    // MARK: Before the first save

    @Test func aMissingFileIsAnEmptyLibraryAndWritesNothing() throws {
        let sandbox = try Sandbox()
        let url = sandbox.url("Library/library.json")
        let library = try LibraryStore(url: url).load()
        #expect(library == Library())
        #expect(library.version == Library.currentVersion)
        #expect(library.bios == nil)
        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(!FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path))
    }

    // MARK: Bad files

    @Test(arguments: [
        "not json {",
        "",
        "[1, 2, 3]",
        #"{"name": "a library from somewhere else"}"#,
        #"{"version": "one"}"#,
        #"{"version": 0}"#,
        #"{"version": 1, "bios": {"size": "big"}}"#,
        #"{"version": 1, "bios": [1]}"#,
    ])
    func aCorruptOrForeignFileIsRefusedAndLeftAsItIs(text: String) throws {
        let sandbox = try Sandbox()
        let url = try sandbox.write(text, to: "library.json")
        let store = LibraryStore(url: url)
        let error = #expect(throws: LibraryStoreError.self) { try store.load() }
        guard case .notALibrary(let path, _)? = error else {
            Issue.record("\(String(describing: error)) is not notALibrary")
            return
        }
        #expect(path == url.path)
        // Keeping a BIOS loads first, so it is refused too, and the file is never saved over.
        #expect(throws: LibraryStoreError.self) { try store.keepBIOS(Self.record) }
        #expect(throws: LibraryStoreError.self) { try store.forgetBIOS() }
        #expect(try String(contentsOf: url, encoding: .utf8) == text)
    }

    @Test func aLibraryFromALaterVersionIsRefusedAndLeftAsItIs() throws {
        let sandbox = try Sandbox()
        let text = #"{"version": 3, "bios": {"fileName": "my-console-bios.bin"}, "games": [], "cards": []}"#
        let url = try sandbox.write(text, to: "library.json")
        let store = LibraryStore(url: url)
        #expect(throws: LibraryStoreError.newerVersion(3, path: url.path)) { try store.load() }
        #expect(throws: LibraryStoreError.newerVersion(3, path: url.path)) { try store.keepBIOS(Self.record) }
        #expect(throws: LibraryStoreError.newerVersion(3, path: url.path)) { try store.addGames([]) }
        #expect(throws: LibraryStoreError.newerVersion(3, path: url.path)) { try store.removeGames([UUID()]) }
        #expect(try String(contentsOf: url, encoding: .utf8) == text)
    }

    @Test func aFolderWhereTheFileShouldBeCannotBeRead() throws {
        let sandbox = try Sandbox()
        let url = try sandbox.makeFolder("library.json")
        let error = #expect(throws: LibraryStoreError.self) { try LibraryStore(url: url).load() }
        guard case .cannotRead(let path, _)? = error else {
            Issue.record("\(String(describing: error)) is not cannotRead")
            return
        }
        #expect(path == url.path)
    }

    @Test func aLibraryThatCannotBeWrittenThrows() throws {
        let sandbox = try Sandbox()
        try sandbox.write("a file, not a folder", to: "Library")
        let url = sandbox.url("Library/library.json") // its folder can't be made: a file is in the way
        let error = #expect(throws: LibraryStoreError.self) { try LibraryStore(url: url).save(Library(bios: Self.record)) }
        guard case .cannotWrite(let path, _)? = error else {
            Issue.record("\(String(describing: error)) is not cannotWrite")
            return
        }
        #expect(path == url.path)
    }

    // MARK: Recorded shapes (never edited)

    @Test func theRecordedVersion1ShapeLoads() throws {
        let sandbox = try Sandbox()
        let url = try sandbox.write(Data(contentsOf: Self.fixtures.appendingPathComponent("library-v1.json")), to: "library.json")
        let library = try LibraryStore(url: url).load()
        #expect(library.version == 1)
        #expect(library.bios == Self.record)
    }

    @Test func aVersion1LibrarySavedAgainIsWrittenInVersion2sShapeWithItsBIOS() throws {
        // Version 1 was 5c's shape, and this build writes version 2: what version 1 held is all still there.
        let sandbox = try Sandbox()
        let url = try sandbox.write(Data(contentsOf: Self.fixtures.appendingPathComponent("library-v1.json")), to: "library.json")
        let store = LibraryStore(url: url)
        let loaded = try store.load()
        #expect(loaded.games.isEmpty)
        try store.save(loaded)
        let written = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let recorded = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: Self.fixtures.appendingPathComponent("library-v1.json"))) as? [String: Any])
        #expect(written["version"] as? Int == 2)
        #expect((written["games"] as? [Any])?.isEmpty == true)
        #expect(written["bios"] as? NSDictionary == recorded["bios"] as? NSDictionary)
        #expect(Set(written.keys) == ["version", "bios", "games"])
        let again = try store.load()
        #expect(again.version == 2)
        #expect(again == Library(bios: Self.record))
    }

    @Test func theRecordedVersion2ShapeLoads() throws {
        let sandbox = try Sandbox()
        let url = try sandbox.write(Data(contentsOf: Self.fixtures.appendingPathComponent("library-v2.json")), to: "library.json")
        let library = try LibraryStore(url: url).load()
        #expect(library.version == 2)
        #expect(library == Self.recordedVersion2)
        #expect(library.games.map(\.format) == [.cue, .m3u, .psexe])
        #expect(library.games.map(\.shownName) == ["Glass Orchard (Europe)", "Tidepool", "GPU test"])
    }

    @Test func thisBuildWritesTheRecordedVersion2Shape() throws {
        let sandbox = try Sandbox()
        let url = sandbox.url("library.json")
        try LibraryStore(url: url).save(Self.recordedVersion2)
        let written = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? NSDictionary
        let recorded = try JSONSerialization.jsonObject(with: Data(contentsOf: Self.fixtures.appendingPathComponent("library-v2.json"))) as? NSDictionary
        #expect(written != nil)
        #expect(written == recorded)
    }

    /// What `Fixtures/library-v2.json` holds: the BIOS and three games of made-up values — a .cue with its
    /// track, an .m3u with its discs, played, and a PS-EXE played and renamed.
    static let recordedVersion2 = Library(bios: record, games: [
        GameRecord(
            id: UUID(uuidString: "6F1C2A3B-0D4E-4F50-8A61-72B3C4D5E6F7")!, fileName: "Glass Orchard (Europe).cue",
            folder: "/Volumes/Archive/Games/PS1", format: .cue, size: 398_458_880,
            added: Date(timeIntervalSince1970: 1_794_646_800), // 2026-11-14T09:00:00Z
            bookmark: Data("glass-orchard".utf8), tracks: ["Glass Orchard (Europe).bin"]
        ),
        GameRecord(
            id: UUID(uuidString: "0A9B8C7D-6E5F-4A3B-9C2D-1E0F9A8B7C6D")!, fileName: "Tidepool.m3u",
            folder: "/Volumes/Archive/Games/PS1/Tidepool", format: .m3u, size: 1_953_021_952,
            added: Date(timeIntervalSince1970: 1_794_509_100), // 2026-11-12T18:45:00Z
            lastPlayed: Date(timeIntervalSince1970: 1_795_209_000), // 2026-11-20T21:10:00Z
            bookmark: Data("tidepool".utf8),
            discs: ["Tidepool (Disc 1).cue", "Tidepool (Disc 2).cue", "Tidepool (Disc 3).cue"]
        ),
        GameRecord(
            id: UUID(uuidString: "C3D4E5F6-A7B8-4C9D-8E0F-1A2B3C4D5E6F")!, fileName: "gpu-test.exe",
            folder: "/Volumes/Archive/Games/Homebrew", format: .psexe, size: 34_816,
            added: Date(timeIntervalSince1970: 1_794_989_700), // 2026-11-18T08:15:00Z
            lastPlayed: checked, name: "GPU test", bookmark: Data("gpu-test".utf8)
        ),
    ])

    @Test func aRecordWithoutItsCheckedDateLoadsWithTheDefault() throws {
        let sandbox = try Sandbox()
        let url = try sandbox.write(Data(contentsOf: Self.fixtures.appendingPathComponent("library-v1-no-checked.json")), to: "library.json")
        let bios = try #require(try LibraryStore(url: url).load().bios)
        #expect(bios.checked == .distantPast)
        #expect(bios.fileName == "bios-backup.bin")
        #expect(bios.folder == "/Volumes/Archive/Console")
        #expect(bios.size == 524_288)
        #expect(bios.sha1 == "6a521e1d2a632c26e53b83d2cc4b0edecfc1e68c")
        #expect(bios.bookmark == Data("bookmark".utf8))
    }

    @Test func everyFieldOfARecordHasItsDefault() throws {
        let sandbox = try Sandbox()
        let url = try sandbox.write(#"{"version": 1, "bios": {}, "aFieldALaterVersionAdds": true}"#, to: "library.json")
        let library = try LibraryStore(url: url).load()
        #expect(library.version == 1)
        #expect(library.bios == BIOSRecord(fileName: "", folder: "", size: 0, sha1: "", checked: .distantPast, bookmark: Data()))
    }

    @Test(arguments: [1, 2])
    func aLibraryWithNeitherBIOSNorGamesLoadsEmpty(version: Int) throws {
        let sandbox = try Sandbox()
        let url = try sandbox.write(#"{"version": \#(version)}"#, to: "library.json")
        let library = try LibraryStore(url: url).load()
        #expect(library.version == version)
        #expect(library.bios == nil)
        #expect(library.games.isEmpty)
    }

    @Test func aVersion1LibraryLoadsWithNoGames() throws {
        let sandbox = try Sandbox()
        let url = try sandbox.write(Data(contentsOf: Self.fixtures.appendingPathComponent("library-v1.json")), to: "library.json")
        let library = try LibraryStore(url: url).load()
        #expect(library.version == 1)
        #expect(library.games.isEmpty)
        #expect(library.bios == Self.record)
    }

    @Test(arguments: [
        #"{"version": 2, "games": {}}"#,
        #"{"version": 2, "games": [1]}"#,
        #"{"version": 2, "games": [{"size": "big"}]}"#,
        #"{"version": 2, "games": [{"format": 3}]}"#,
        #"{"version": 2, "games": [{"id": "not a uuid"}]}"#,
        #"{"version": 2, "games": [{"discs": "Disc 1.cue"}]}"#,
    ])
    func aGameOfTheWrongShapeIsRefusedAndLeftAsItIs(text: String) throws {
        let sandbox = try Sandbox()
        let url = try sandbox.write(text, to: "library.json")
        let store = LibraryStore(url: url)
        let error = #expect(throws: LibraryStoreError.self) { try store.load() }
        guard case .notALibrary? = error else {
            Issue.record("\(String(describing: error)) is not notALibrary")
            return
        }
        #expect(throws: LibraryStoreError.self) { try store.addGames([]) }
        #expect(try String(contentsOf: url, encoding: .utf8) == text)
    }
}
