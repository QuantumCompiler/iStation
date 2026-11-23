// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import DataLibrary
import Foundation
@testable import PresentationLibrary
import SupportSandbox
import Testing

/// The storage the app hands the library's view-models, over the real `library.json`, kept files and
/// folder search, inside a `Sandbox`: a scan keeps its games in the file and Scan Again adds none, the
/// library's changes reach the file, a moved game is found again by its bookmark, and a PS-EXE opens
/// with the BIOS kept by a real bookmark. Every wait ends after two seconds.
@MainActor
@Suite struct LibraryStoreStorageTests {
    func makeStorage(_ sandbox: Sandbox) -> (LibraryStoreStorage, LibraryStore) {
        let store = LibraryStore(url: sandbox.url("Container/library.json"))
        return (LibraryStoreStorage(store: store), store)
    }

    @Test func aScanKeepsItsGamesInLibraryJSONAndScanAgainAddsNone() async throws {
        let sandbox = try Sandbox()
        let folder = try makeGames(in: sandbox)
        let (storage, store) = makeStorage(sandbox)
        let scan = ScanViewModel(storage: storage, now: { today })
        scan.scan(folder)
        #expect(await settled(scan))
        #expect(scan.state == .done)
        #expect(try store.load().games.map(\.fileName) == ["gpu-test.exe", "Glass Orchard (Europe).cue", "Harbor Lights (USA).cue", "Moonbase Courier.iso", "Tidepool.m3u"])
        scan.scanAgain()
        #expect(await settled(scan))
        #expect(scan.results.allSatisfy { $0.outcome == .skipped })
        #expect(try store.load().games.count == 5)
    }

    @Test func theLibrarysChangesReachLibraryJSON() async throws {
        let sandbox = try Sandbox()
        let exe = try sandbox.write(Data(programImage), to: "Games/Homebrew/gpu-test.exe")
        let cue = try sandbox.write("FILE \"Glass Orchard (Europe).bin\" BINARY\n", to: "Games/PS1/Glass Orchard (Europe).cue")
        try sandbox.write(Data(repeating: 1, count: 1_000), to: "Games/PS1/Glass Orchard (Europe).bin")
        let (storage, store) = makeStorage(sandbox)
        let library = LibraryViewModel(storage: storage, session: FakePowerSession(), calendar: utc, now: { today }, onRun: { _ in })
        library.add([exe, cue])
        #expect(await settled(library))
        #expect(try store.load().games.map(\.fileName) == ["gpu-test.exe", "Glass Orchard (Europe).cue"])
        #expect(try store.load().games.last?.size == cue.fileSize + 1_000, "a cue sheet with its track")

        let program = try #require(library.games.first)
        library.rename(program.id)
        library.renameDraft = "GPU Test"
        library.saveRename()
        #expect(try store.load().games.first?.name == "GPU Test")
        #expect(FileManager.default.fileExists(atPath: exe.path), "the file keeps its own name")

        library.askToRemove(program.id)
        library.answer(.remove)
        #expect(try store.load().games.map(\.fileName) == ["Glass Orchard (Europe).cue"])
        #expect(FileManager.default.fileExists(atPath: exe.path), "removing leaves the file where it is")
        library.selection = library.games.first?.id
        #expect(library.fileToShowInFinder().map(GameRecord.standardizedPath(of:)) == GameRecord.standardizedPath(of: cue))
    }

    @Test func aGameMovedOnDiskIsFoundByItsBookmarkAndKeptWhereItIsNow() async throws {
        let sandbox = try Sandbox()
        let cue = try sandbox.write("FILE \"Lantern Street.bin\" BINARY\n", to: "Games/PS1/Lantern Street.cue")
        let (storage, store) = makeStorage(sandbox)
        _ = try storage.addGames([GameFiles.record(for: cue, added: today)])
        try FileManager.default.createDirectory(at: sandbox.url("Games/PS1/Moved"), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: cue, to: sandbox.url("Games/PS1/Moved/Lantern Street.cue"))

        let library = LibraryViewModel(storage: storage, session: FakePowerSession(), calendar: utc, now: { today }, onRun: { _ in })
        #expect(await settled(library))
        let lantern = try #require(library.games.first)
        #expect(!library.isMissing(lantern))
        #expect(lantern.folder == GameRecord.standardizedPath(of: sandbox.url("Games/PS1/Moved")))
        #expect(try store.load().games.first?.folder == lantern.folder, "kept again in library.json")

        try FileManager.default.removeItem(at: sandbox.url("Games/PS1/Moved/Lantern Street.cue"))
        library.checkFiles()
        #expect(await settled(library))
        #expect(library.isMissing(lantern), "a file that is gone is flagged missing")
        #expect(try store.load().games.count == 1, "and kept")
    }

    @Test func aPSEXEOpensWithTheBIOSKeptByItsBookmark() async throws {
        let sandbox = try Sandbox()
        let biosFile = try sandbox.write(Data(biosImage), to: "Console/my-console-bios.bin")
        let exe = try sandbox.write(Data(programImage), to: "Games/Homebrew/gpu-test.exe")
        let (storage, store) = makeStorage(sandbox)
        _ = try storage.keepBIOS(BIOSRecord(
            fileName: biosFile.lastPathComponent, folder: biosFile.deletingLastPathComponent().path, size: 524_288,
            sha1: "", checked: today.roundedDown, bookmark: storage.bookmark(for: biosFile)
        ))
        _ = try storage.addGames([GameFiles.record(for: exe, added: today)])
        let session = FakePowerSession()
        let handed = Handed()
        let opening = OpeningViewModel(storage: storage, session: session, now: { today }, onRun: { handed.runs.append($0) })
        opening.open(try #require(try store.load().games.first))
        #expect(await followed(session))
        let bios = await session.bios
        #expect(bios == biosImage, "powered on with the kept BIOS's bytes")
        #expect(await session.exe != nil)
        await session.run(to: 100, reachedShell: true)
        #expect(await eventually { handed.runs.count == 1 })
        #expect(handed.runs.first?.fileName == "gpu-test.exe")
        #expect(try store.load().games.first?.lastPlayed == today.roundedDown)
    }
}

extension URL {
    /// The size of the file here, for the tests' sums.
    var fileSize: Int {
        ((try? FileManager.default.attributesOfItem(atPath: path)[.size]) as? NSNumber)?.intValue ?? 0
    }
}
