// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import DataLibrary
import Foundation
import SupportSandbox
import Testing

/// The games in a folder, and the record of each, over a folder of made-up files built in a `Sandbox`:
/// tiny cue sheets, playlists and tracks of a few bytes, never a disc image. The search finds .cue,
/// .iso, .m3u and .exe files in the folder and its subfolders, one entry for an .m3u and its discs and
/// none for a .cue's tracks; a record is the file's name, folder, format, bookmark, size and parts.
@Suite struct GameFilesTests {
    /// A folder of games, as a person might keep them, and a few files that aren't games.
    func makeGames(in sandbox: Sandbox) throws -> URL {
        try sandbox.write("FILE \"Glass Orchard (Europe).bin\" BINARY\n  TRACK 01 MODE2/2352\n", to: "Games/PS1/Glass Orchard (Europe).cue")
        try sandbox.write(Data(repeating: 1, count: 1_000), to: "Games/PS1/Glass Orchard (Europe).bin")
        try sandbox.write("FILE \"Harbor Lights (USA) (Track 1).bin\" BINARY\nFILE \"Harbor Lights (USA) (Track 2).bin\" BINARY\n", to: "Games/PS1/Harbor Lights (USA).cue")
        try sandbox.write(Data(repeating: 2, count: 3_000), to: "Games/PS1/Harbor Lights (USA) (Track 1).bin")
        try sandbox.write(Data(repeating: 3, count: 500), to: "Games/PS1/Harbor Lights (USA) (Track 2).bin")
        try sandbox.write(Data(repeating: 4, count: 2_048), to: "Games/PS1/Moonbase Courier.ISO")
        try sandbox.write("#EXTM3U\nTidepool (Disc 1).cue\nTidepool (Disc 2).iso\n", to: "Games/PS1/Tidepool/Tidepool.m3u")
        try sandbox.write("FILE \"Tidepool (Disc 1).bin\" BINARY\n", to: "Games/PS1/Tidepool/Tidepool (Disc 1).cue")
        try sandbox.write(Data(repeating: 5, count: 4_000), to: "Games/PS1/Tidepool/Tidepool (Disc 1).bin")
        try sandbox.write(Data(repeating: 6, count: 6_000), to: "Games/PS1/Tidepool/Tidepool (Disc 2).iso")
        try sandbox.write(Data(repeating: 7, count: 2_048), to: "Games/Homebrew/gpu-test.exe")
        try sandbox.write("Notes about the homebrew.", to: "Games/Homebrew/readme.txt")
        try sandbox.write(Data(repeating: 8, count: 100), to: "Games/Stray/orphan.bin")
        try sandbox.write("FILE \"hidden.bin\" BINARY\n", to: "Games/.Hidden/hidden.cue")
        try sandbox.write("FILE \"x.bin\" BINARY\n", to: "Games/PS1/._Glass Orchard (Europe).cue")
        return sandbox.url("Games")
    }

    /// `urls`' paths below `folder`, as the design's scan lists them.
    func relative(_ urls: [URL], to folder: URL) -> [String] {
        let base = GameRecord.standardizedPath(of: folder) + "/"
        return urls.map { String(GameRecord.standardizedPath(of: $0).dropFirst(base.count)) }
    }

    // MARK: The search

    @Test func aFoldersGamesAreFoundInItsSubfoldersInPathOrder() throws {
        let sandbox = try Sandbox()
        let folder = try makeGames(in: sandbox)
        #expect(relative(try GameFiles.find(in: folder), to: folder) == [
            "Homebrew/gpu-test.exe",
            "PS1/Glass Orchard (Europe).cue",
            "PS1/Harbor Lights (USA).cue",
            "PS1/Moonbase Courier.ISO",
            "PS1/Tidepool/Tidepool.m3u",
        ])
    }

    @Test func anM3usDiscsComeWithItAndAreNoGamesOfTheirOwn() throws {
        let sandbox = try Sandbox()
        let folder = try makeGames(in: sandbox)
        let found = relative(try GameFiles.find(in: folder), to: folder)
        #expect(found.contains("PS1/Tidepool/Tidepool.m3u"))
        #expect(!found.contains("PS1/Tidepool/Tidepool (Disc 1).cue"))
        #expect(!found.contains("PS1/Tidepool/Tidepool (Disc 2).iso"))
    }

    @Test func aCuesTracksAreNoGamesEvenWhenTheyCouldBeOne() throws {
        // A .bin is never looked for; a track a .cue names in a format that is looked for isn't a game either.
        let sandbox = try Sandbox()
        try sandbox.write("FILE \"Night Ferry.iso\" BINARY\n", to: "Games/Night Ferry.cue")
        try sandbox.write(Data(repeating: 1, count: 2_048), to: "Games/Night Ferry.iso")
        try sandbox.write(Data(repeating: 1, count: 100), to: "Games/Night Ferry (Track 2).bin")
        let folder = sandbox.url("Games")
        #expect(relative(try GameFiles.find(in: folder), to: folder) == ["Night Ferry.cue"])
    }

    @Test func aPlaylistThatListsItselfIsStillAGame() throws {
        let sandbox = try Sandbox()
        try sandbox.write("Tidepool.m3u\nTidepool.iso\n", to: "Games/Tidepool.m3u")
        try sandbox.write(Data(repeating: 1, count: 2_048), to: "Games/Tidepool.iso")
        let folder = sandbox.url("Games")
        #expect(relative(try GameFiles.find(in: folder), to: folder) == ["Tidepool.m3u"])
    }

    @Test func anM3usDiscsNamedInAnotherCaseStillComeWithIt() throws {
        // A playlist written by hand, its discs in lower case: where the volume ignores case (the Mac's do,
        // by default) the playlist still finds them, so they are its discs, not games of their own.
        let sandbox = try Sandbox()
        try sandbox.write("tidepool (disc 1).cue\ntidepool (disc 2).ISO\n", to: "Games/Tidepool/Tidepool.m3u")
        try sandbox.write("file \"tidepool (disc 1).BIN\" binary\n", to: "Games/Tidepool/Tidepool (Disc 1).cue")
        try sandbox.write(Data(repeating: 1, count: 2_048), to: "Games/Tidepool/Tidepool (Disc 1).bin")
        try sandbox.write(Data(repeating: 2, count: 2_048), to: "Games/Tidepool/Tidepool (Disc 2).iso")
        let folder = sandbox.url("Games")
        let found = relative(try GameFiles.find(in: folder), to: folder)
        if FileManager.default.fileExists(atPath: sandbox.url("Games/Tidepool/tidepool (disc 1).cue").path) {
            #expect(found == ["Tidepool/Tidepool.m3u"])
        } else {
            // A volume that tells case apart: the playlist names files that aren't there.
            #expect(found == ["Tidepool/Tidepool (Disc 1).cue", "Tidepool/Tidepool (Disc 2).iso", "Tidepool/Tidepool.m3u"])
        }
    }

    @Test func playlistsThatListEachOtherKeepTheFirstOfThem() throws {
        // Two playlists that list each other, and nothing else lists: the first in path order stands for
        // both, and the discs come with it, rather than every game in the ring disappearing.
        let sandbox = try Sandbox()
        try sandbox.write("B.m3u\nB.iso\n", to: "Games/A.m3u")
        try sandbox.write("A.m3u\nA.iso\n", to: "Games/B.m3u")
        try sandbox.write(Data(repeating: 1, count: 2_048), to: "Games/A.iso")
        try sandbox.write(Data(repeating: 2, count: 2_048), to: "Games/B.iso")
        try sandbox.write(Data(repeating: 3, count: 2_048), to: "Games/C.iso")
        let folder = sandbox.url("Games")
        #expect(relative(try GameFiles.find(in: folder), to: folder) == ["A.m3u", "C.iso"])
    }

    @Test func aPlaylistListedByAnotherBringsItsOwnDiscs() throws {
        // Lists within lists: what a game that stays lists goes, and what that lists in turn.
        let sandbox = try Sandbox()
        try sandbox.write("Inner.m3u\n", to: "Games/Outer.m3u")
        try sandbox.write("Disc.iso\n", to: "Games/Inner.m3u")
        try sandbox.write(Data(repeating: 1, count: 2_048), to: "Games/Disc.iso")
        let folder = sandbox.url("Games")
        #expect(relative(try GameFiles.find(in: folder), to: folder) == ["Outer.m3u"])
    }

    @Test func whatARingListsGoesWithItWhateverItsName() throws {
        // A playlist that only a ring of playlists lists is the ring's, not a ring of its own: it goes with
        // the ring, whether or not its name comes first in path order.
        for inner in ["A-inner.m3u", "Z-inner.m3u"] {
            let sandbox = try Sandbox()
            try sandbox.write("Y.m3u\n", to: "Games/X.m3u")
            try sandbox.write("X.m3u\n\(inner)\n", to: "Games/Y.m3u")
            try sandbox.write("B.iso\n", to: "Games/\(inner)")
            try sandbox.write(Data(repeating: 1, count: 2_048), to: "Games/B.iso")
            let folder = sandbox.url("Games")
            let found = relative(try GameFiles.find(in: folder), to: folder)
            #expect(found == ["X.m3u"], "with \(inner)")
        }
    }

    @Test func aRingAnotherRingListsGoesWithIt() throws {
        // Two rings, one listing the other: the ring nothing lists keeps its first playlist, and the ring
        // it lists goes with it, though that ring's names come first in path order.
        let sandbox = try Sandbox()
        try sandbox.write("B.m3u\n", to: "Games/A.m3u")
        try sandbox.write("A.m3u\n", to: "Games/B.m3u")
        try sandbox.write("Q.m3u\n", to: "Games/P.m3u")
        try sandbox.write("P.m3u\nA.m3u\n", to: "Games/Q.m3u")
        let folder = sandbox.url("Games")
        let found = relative(try GameFiles.find(in: folder), to: folder)
        #expect(found == ["P.m3u"])
    }

    @Test func ofGamesThatAreOneFileByHardLinksADiscIsTheOneItsPlaylistNames() throws {
        // B.iso is a hard link to A.iso: one file, two names, two games. A playlist that names B.iso takes
        // B.iso, and A.iso stays a game; one that names both takes both.
        let sandbox = try Sandbox()
        for (folder, playlist) in [("One", "B.iso\n"), ("Both", "A.iso\nB.iso\n")] {
            try sandbox.write(playlist, to: "\(folder)/List.m3u")
            try sandbox.write(Data(repeating: 1, count: 2_048), to: "\(folder)/A.iso")
            try FileManager.default.linkItem(at: sandbox.url("\(folder)/A.iso"), to: sandbox.url("\(folder)/B.iso"))
        }
        let one = relative(try GameFiles.find(in: sandbox.url("One")), to: sandbox.url("One"))
        #expect(one == ["A.iso", "List.m3u"])
        let both = relative(try GameFiles.find(in: sandbox.url("Both")), to: sandbox.url("Both"))
        #expect(both == ["List.m3u"])
    }

    @Test func ofGamesThatAreOneFileByHardLinksADiscNamedInAnotherCaseIsTheOneItSpells() throws {
        // The playlist spells B.iso in lower case: resolving its path gives the file's own spelling, so it
        // still names B.iso, not A.iso.
        let sandbox = try Sandbox()
        try sandbox.write("b.iso\n", to: "Games/List.m3u")
        try sandbox.write(Data(repeating: 1, count: 2_048), to: "Games/A.iso")
        try FileManager.default.linkItem(at: sandbox.url("Games/A.iso"), to: sandbox.url("Games/B.iso"))
        let folder = sandbox.url("Games")
        let found = relative(try GameFiles.find(in: folder), to: folder)
        if FileManager.default.fileExists(atPath: sandbox.url("Games/b.iso").path) {
            #expect(found == ["A.iso", "List.m3u"])
        } else {
            // A volume that tells case apart: the playlist names a file that isn't there.
            #expect(found == ["A.iso", "B.iso", "List.m3u"])
        }
    }

    @Test func ofGamesThatAreOneFileByHardLinksADiscReachedThroughALinkedFolderIsTheOneItSpells() throws {
        // The playlist reaches B.iso through a symbolic link to its folder: the path it spells, links
        // followed, is B.iso's.
        let sandbox = try Sandbox()
        try sandbox.write("Linked/B.iso\n", to: "Games/List.m3u")
        try sandbox.write(Data(repeating: 1, count: 2_048), to: "Games/A.iso")
        try FileManager.default.linkItem(at: sandbox.url("Games/A.iso"), to: sandbox.url("Games/B.iso"))
        try FileManager.default.createSymbolicLink(at: sandbox.url("Games/Linked"), withDestinationURL: sandbox.url("Games"))
        let folder = sandbox.url("Games")
        let found = relative(try GameFiles.find(in: folder), to: folder)
        #expect(found == ["A.iso", "List.m3u"])
    }

    @Test func ofGamesThatAreOneFileByHardLinksADiscNamedByAThirdNameIsAllOfThem() throws {
        // The playlist names a third link to the same file, outside the folder searched: which of A.iso and
        // B.iso it means can't be told, so it takes both.
        let sandbox = try Sandbox()
        try sandbox.write("../Elsewhere/C.iso\n", to: "Games/List.m3u")
        try sandbox.write(Data(repeating: 1, count: 2_048), to: "Games/A.iso")
        try FileManager.default.linkItem(at: sandbox.url("Games/A.iso"), to: sandbox.url("Games/B.iso"))
        _ = try sandbox.makeFolder("Elsewhere")
        try FileManager.default.linkItem(at: sandbox.url("Games/A.iso"), to: sandbox.url("Elsewhere/C.iso"))
        let folder = sandbox.url("Games")
        let found = relative(try GameFiles.find(in: folder), to: folder)
        #expect(found == ["List.m3u"])
    }

    @Test func aDiscThatIsASymbolicLinkIsTheGameItLeadsTo() throws {
        // A folder of playlists whose discs are symbolic links into a folder of discs: each disc comes with
        // its playlist, though the playlist names the link.
        let sandbox = try Sandbox()
        try sandbox.write(Data(repeating: 1, count: 2_048), to: "Games/Discs/Disc.iso")
        try sandbox.write("Disc link.iso\n", to: "Games/Lists/List.m3u")
        try FileManager.default.createSymbolicLink(
            at: sandbox.url("Games/Lists/Disc link.iso"), withDestinationURL: sandbox.url("Games/Discs/Disc.iso")
        )
        let folder = sandbox.url("Games")
        let found = relative(try GameFiles.find(in: folder), to: folder)
        #expect(found == ["Lists/List.m3u"])
    }

    @Test func aFolderWithoutGamesHasNone() throws {
        let sandbox = try Sandbox()
        try sandbox.write("Nothing to play.", to: "Documents/notes.txt")
        #expect(try GameFiles.find(in: sandbox.url("Documents")).isEmpty)
        #expect(try GameFiles.find(in: sandbox.makeFolder("Empty")).isEmpty)
    }

    @Test func aFileOrAFolderThatIsntThereCantBeSearched() throws {
        let sandbox = try Sandbox()
        let file = try sandbox.write(Data(repeating: 1, count: 10), to: "Games/gpu-test.exe")
        let notAFolder = #expect(throws: KeptFileError.self) { try GameFiles.find(in: file) }
        guard case .cannotRead(let path, _)? = notAFolder else {
            Issue.record("\(String(describing: notAFolder)) is not cannotRead")
            return
        }
        #expect(path == file.path)
        #expect(throws: KeptFileError.self) { try GameFiles.find(in: sandbox.url("Missing")) }
    }

    @Test func aSubfolderThatCantBeReadIsPassedOver() throws {
        let sandbox = try Sandbox()
        let folder = try makeGames(in: sandbox)
        let locked = try sandbox.makeFolder("Games/Locked")
        try sandbox.write(Data(repeating: 1, count: 10), to: "Games/Locked/locked.iso")
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked.path) }
        let found = relative(try GameFiles.find(in: folder), to: folder)
        #expect(found.count == 5)
        #expect(!found.contains("Locked/locked.iso"))
    }

    @Test func aLinkToAGameIsPassedOverSoNoFileIsFoundTwice() throws {
        let sandbox = try Sandbox()
        let folder = try makeGames(in: sandbox)
        try FileManager.default.createSymbolicLink(
            at: folder.appendingPathComponent("Homebrew/gpu-test link.exe"),
            withDestinationURL: folder.appendingPathComponent("Homebrew/gpu-test.exe")
        )
        try FileManager.default.createSymbolicLink(at: folder.appendingPathComponent("Linked PS1"), withDestinationURL: folder.appendingPathComponent("PS1"))
        let found = relative(try GameFiles.find(in: folder), to: folder)
        #expect(found.count == 5)
        #expect(!found.contains("Homebrew/gpu-test link.exe"))
        #expect(!found.contains { $0.hasPrefix("Linked PS1/") })
    }

    @Test func aCancelledSearchEndsEarly() async throws {
        let sandbox = try Sandbox()
        let folder = try makeGames(in: sandbox)
        let search = Task { () throws -> [URL] in
            withUnsafeCurrentTask { $0?.cancel() }
            return try GameFiles.find(in: folder)
        }
        #expect(try await search.value.isEmpty)
    }

    // MARK: A game's record

    @Test func aCuesRecordNamesItsTracksAndCountsTheirSize() throws {
        let sandbox = try Sandbox()
        let folder = try makeGames(in: sandbox)
        let url = folder.appendingPathComponent("PS1/Harbor Lights (USA).cue")
        let added = LibraryGamesTests.today.addingTimeInterval(0.5)
        let game = try GameFiles.record(for: url, added: added)
        #expect(game.fileName == "Harbor Lights (USA).cue")
        #expect(game.folder == GameRecord.standardizedPath(of: folder.appendingPathComponent("PS1")))
        #expect(game.path == GameRecord.standardizedPath(of: url))
        #expect(game.format == .cue)
        #expect(game.tracks == ["Harbor Lights (USA) (Track 1).bin", "Harbor Lights (USA) (Track 2).bin"])
        #expect(game.discs == [])
        let cueSize = try KeptFile.size(at: url)
        #expect(game.size == cueSize + 3_000 + 500)
        #expect(game.added == LibraryGamesTests.today, "to the whole second")
        #expect(game.lastPlayed == nil)
        #expect(game.name == nil)
        #expect(game.shownName == "Harbor Lights (USA)")
        let resolved = try KeptFile.resolve(game.bookmark)
        #expect(GameRecord.standardizedPath(of: resolved.url) == game.path)
    }

    @Test func anM3usRecordNamesItsDiscsAndCountsThemAndTheirTracks() throws {
        let sandbox = try Sandbox()
        let folder = try makeGames(in: sandbox)
        let url = folder.appendingPathComponent("PS1/Tidepool/Tidepool.m3u")
        let game = try GameFiles.record(for: url, added: LibraryGamesTests.today)
        #expect(game.format == .m3u)
        #expect(game.discs == ["Tidepool (Disc 1).cue", "Tidepool (Disc 2).iso"])
        #expect(game.tracks == [])
        let own = try KeptFile.size(at: url)
        let disc1 = try KeptFile.size(at: folder.appendingPathComponent("PS1/Tidepool/Tidepool (Disc 1).cue"))
        #expect(game.size == own + disc1 + 4_000 + 6_000)
    }

    @Test func anM3usDiscLinkedToACueCountsTheTracksOfTheSheetItLeadsTo() throws {
        // A playlist in a folder of its own whose disc is a symbolic link to a cue sheet elsewhere: the
        // sheet's tracks are in its own folder, not the link's, and count toward the game's size.
        let sandbox = try Sandbox()
        try sandbox.write("FILE \"Tidepool (Disc 1).bin\" BINARY\n", to: "Games/Discs/Tidepool (Disc 1).cue")
        try sandbox.write(Data(repeating: 1, count: 4_000), to: "Games/Discs/Tidepool (Disc 1).bin")
        try sandbox.write("Disc 1.cue\n", to: "Games/Lists/Tidepool.m3u")
        try FileManager.default.createSymbolicLink(
            at: sandbox.url("Games/Lists/Disc 1.cue"), withDestinationURL: sandbox.url("Games/Discs/Tidepool (Disc 1).cue")
        )
        let url = sandbox.url("Games/Lists/Tidepool.m3u")
        let game = try GameFiles.record(for: url, added: LibraryGamesTests.today)
        #expect(game.discs == ["Disc 1.cue"])
        let own = try KeptFile.size(at: url)
        let sheet = try KeptFile.size(at: sandbox.url("Games/Discs/Tidepool (Disc 1).cue"))
        #expect(game.size == own + sheet + 4_000)
        let found = relative(try GameFiles.find(in: sandbox.url("Games")), to: sandbox.url("Games"))
        #expect(found == ["Lists/Tidepool.m3u"])
    }

    @Test func aProgramsRecordIsItsFileAlone() throws {
        let sandbox = try Sandbox()
        let folder = try makeGames(in: sandbox)
        let game = try GameFiles.record(for: folder.appendingPathComponent("Homebrew/gpu-test.exe"), added: LibraryGamesTests.today)
        #expect(game.format == .psexe)
        #expect(game.size == 2_048)
        #expect(game.tracks == [])
        #expect(game.discs == [])
        #expect(game.shownName == "gpu-test")
    }

    @Test func aTrackThatIsntThereCountsNothing() throws {
        let sandbox = try Sandbox()
        let url = try sandbox.write("FILE \"Lantern Street.bin\" BINARY\n", to: "Games/Lantern Street.cue")
        let game = try GameFiles.record(for: url, added: LibraryGamesTests.today)
        #expect(game.tracks == ["Lantern Street.bin"])
        #expect(game.size == (try KeptFile.size(at: url)))
    }

    @Test func aCueTooBigToBeOneIsntReadForItsTracks() throws {
        let sandbox = try Sandbox()
        let line = "FILE \"Lantern Street.bin\" BINARY\n"
        let text = String(repeating: line, count: GameFiles.playlistLimit / line.utf8.count + 1)
        let url = try sandbox.write(text, to: "Games/Lantern Street.cue")
        try sandbox.write(Data(repeating: 1, count: 100), to: "Games/Lantern Street.bin")
        let game = try GameFiles.record(for: url, added: LibraryGamesTests.today)
        #expect(game.tracks == [])
        #expect(game.size == text.utf8.count)
    }

    @Test func aFileOfAnotherKindIsRecordedWithItsExtensionKept() throws {
        let sandbox = try Sandbox()
        let url = try sandbox.write(Data(repeating: 1, count: 10), to: "Games/Night Ferry.CHD")
        #expect(try GameFiles.record(for: url, added: LibraryGamesTests.today).format == .unknown("chd"))
    }

    @Test func aFileThatIsntThereHasNoRecord() throws {
        let sandbox = try Sandbox()
        #expect(throws: KeptFileError.self) { try GameFiles.record(for: sandbox.url("Games/gpu-test.exe"), added: LibraryGamesTests.today) }
    }

    // MARK: Scanned twice

    @Test func aFolderScannedTwiceAddsEachGameOnce() throws {
        let sandbox = try Sandbox()
        let folder = try makeGames(in: sandbox)
        let store = LibraryStore(url: sandbox.url("Container/library.json"))
        let first = try GameFiles.find(in: folder).map { try GameFiles.record(for: $0, added: LibraryGamesTests.today) }
        #expect(try store.addGames(first).added.count == 5)
        // A file added since, then the folder scanned again.
        try sandbox.write(Data(repeating: 9, count: 2_048), to: "Games/Homebrew/cube.exe")
        let again = try GameFiles.find(in: folder).map { try GameFiles.record(for: $0, added: LibraryGamesTests.today) }
        let result = try store.addGames(again)
        #expect(result.added.map(\.fileName) == ["cube.exe"])
        #expect(try store.load().games.count == 6)
        #expect(Set(try store.load().games.map(\.path)).count == 6, "no file twice")
    }
}
