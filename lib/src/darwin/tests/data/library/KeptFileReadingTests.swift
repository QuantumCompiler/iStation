// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import DataLibrary
import Foundation
import SupportSandbox
import Testing

/// The kept files read through `KeptFileReading`: the kept BIOS read as Run the BIOS and the opening job
/// read it — found, sized unread and read, each failure its own error — and where a kept game's file is
/// now: found, moved (a stale bookmark, kept and flagged) or missing, never dropped. Over real files in
/// a `Sandbox` through `KeptFileReader`, and over a scripted reader that records its calls.
@Suite struct KeptFileReadingTests {
    /// 512 KB of made-up bytes, built in code: never a real BIOS.
    static let image = KeptFileTests.image

    /// The same file, however the system spells its path.
    func samePath(_ one: URL, _ other: URL) -> Bool {
        GameRecord.standardizedPath(of: one) == GameRecord.standardizedPath(of: other)
    }

    /// A BIOS record of `url` and `bookmark`, the rest made up.
    func bios(_ url: URL, _ bookmark: Data) -> BIOSRecord {
        BIOSRecord(fileName: url.lastPathComponent, folder: url.deletingLastPathComponent().path, size: 524_288,
                   sha1: "", checked: .distantPast, bookmark: bookmark)
    }

    // MARK: The kept BIOS

    @Test func theKeptBIOSIsFoundSizedAndRead() throws {
        let sandbox = try Sandbox()
        let url = try sandbox.write(Data(Self.image), to: "Console/my-console-bios.bin")
        let read = try KeptFileReader().readBIOS(bios(url, try KeptFile.bookmark(for: url)), expectedSize: 524_288)
        #expect(samePath(read.url, url))
        #expect(!read.isStale)
        #expect(read.bytes == Self.image)
    }

    @Test func aMovedBIOSIsReadWhereItIsNowAndSaysItsBookmarkIsStale() throws {
        let sandbox = try Sandbox()
        let url = try sandbox.write(Data(Self.image), to: "Console/my-console-bios.bin")
        let record = bios(url, try KeptFile.bookmark(for: url))
        let moved = sandbox.url("Archive/bios-backup.bin")
        try FileManager.default.createDirectory(at: moved.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: url, to: moved)
        let read = try KeptFileReader().readBIOS(record, expectedSize: 524_288)
        #expect(samePath(read.url, moved))
        #expect(read.isStale, "macOS marks a bookmark stale once its file moves (measured 2026-11-22)")
        #expect(read.bytes == Self.image)
        // The record made again where it is now, as the pane keeps it.
        let again = record.moved(to: read.url, bookmark: try KeptFile.bookmark(for: read.url))
        #expect(again.fileName == "bios-backup.bin")
        #expect(samePath(URL(fileURLWithPath: again.folder), sandbox.url("Archive")))
        #expect(again.size == record.size)
        #expect(try KeptFile.resolve(again.bookmark).isStale == false)
    }

    @Test func aBIOSThatIsGoneCantBeFound() throws {
        let sandbox = try Sandbox()
        let url = try sandbox.write(Data(Self.image), to: "my-console-bios.bin")
        let record = bios(url, try KeptFile.bookmark(for: url))
        try FileManager.default.removeItem(at: url)
        let error = #expect(throws: KeptBIOSError.self) { try KeptFileReader().readBIOS(record, expectedSize: 524_288) }
        guard case .cannotFind(.cannotResolve)? = error else {
            Issue.record("\(String(describing: error)) is not cannotFind(cannotResolve)")
            return
        }
    }

    @Test func aBIOSNoLongerABIOSsSizeIsRefusedUnread() throws {
        let sandbox = try Sandbox()
        let url = try sandbox.write(Data(repeating: 0, count: 1_000), to: "my-console-bios.bin")
        let files = ScriptedFiles(reader: KeptFileReader())
        #expect(throws: KeptBIOSError.wrongSize(1_000)) {
            try files.readBIOS(bios(url, try KeptFile.bookmark(for: url)), expectedSize: 524_288)
        }
        #expect(files.calls == ["resolve", "size"], "sized, never read")
    }

    @Test func eachStepsFailureIsItsOwnErrorWithWhatWasThrown() throws {
        let record = bios(URL(fileURLWithPath: "/Volumes/Archive/Console/my-console-bios.bin"), Data("bookmark".utf8))
        let cannotResolve = KeptFileError.cannotResolve(reason: "No such file.")
        let cannotRead = KeptFileError.cannotRead(path: "/Volumes/Archive/Console/my-console-bios.bin", reason: "Permission denied.")
        #expect(throws: KeptBIOSError.cannotFind(cannotResolve)) {
            try ScriptedFiles(failing: "resolve", with: cannotResolve).readBIOS(record, expectedSize: 524_288)
        }
        #expect(throws: KeptBIOSError.cannotSize(cannotRead)) {
            try ScriptedFiles(failing: "size", with: cannotRead).readBIOS(record, expectedSize: 524_288)
        }
        #expect(throws: KeptBIOSError.cannotRead(cannotRead)) {
            try ScriptedFiles(failing: "bytes", with: cannotRead).readBIOS(record, expectedSize: 524_288)
        }
        let files = ScriptedFiles()
        let read = try files.readBIOS(record, expectedSize: 524_288)
        #expect(read.bytes.count == 524_288)
        #expect(files.calls == ["resolve", "size", "bytes"])
    }

    @Test func anErrorThatIsntAKeptFilesIsMadeOneWithItsDescription() {
        let record = bios(URL(fileURLWithPath: "/Volumes/Archive/Console/my-console-bios.bin"), Data("bookmark".utf8))
        let foreign = CocoaError(.fileReadNoPermission)
        #expect(throws: KeptBIOSError.cannotFind(.cannotResolve(reason: foreign.localizedDescription))) {
            try ScriptedFiles(failing: "resolve", with: foreign).readBIOS(record, expectedSize: 524_288)
        }
        #expect(throws: KeptBIOSError.cannotRead(.cannotRead(path: record.folder + "/" + record.fileName, reason: foreign.localizedDescription))) {
            try ScriptedFiles(failing: "bytes", with: foreign).readBIOS(record, expectedSize: 524_288)
        }
    }

    // MARK: Where a game is

    /// A record of the game in the file at `url`, kept by a bookmark to it.
    func record(of url: URL) throws -> GameRecord {
        try GameFiles.record(for: url, added: LibraryGamesTests.today)
    }

    @Test func aGameWhereTheLibraryRecordedItIsFound() throws {
        let sandbox = try Sandbox()
        let url = try sandbox.write(Data(repeating: 1, count: 2_048), to: "Games/Moonbase Courier.iso")
        let whereabouts = KeptFileReader().whereabouts(of: try record(of: url))
        guard case .found(let found) = whereabouts else {
            Issue.record("\(whereabouts) is not found")
            return
        }
        #expect(samePath(found, url))
    }

    @Test func aStaleBookmarkIsKeptInTheLibraryAndFlaggedMoved() throws {
        let sandbox = try Sandbox()
        let url = try sandbox.write(Data(repeating: 1, count: 2_048), to: "Games/Moonbase Courier.iso")
        let store = LibraryStore(url: sandbox.url("Container/library.json"))
        let game = try record(of: url)
        try store.addGames([game])
        let renamed = sandbox.url("Games/Moonbase Courier (USA).iso")
        try FileManager.default.moveItem(at: url, to: renamed)

        let library = try store.load()
        #expect(library.games == [game], "the library keeps the record as it was")
        let whereabouts = KeptFileReader().whereabouts(of: game)
        guard case .moved(let now) = whereabouts else {
            Issue.record("\(whereabouts) is not moved")
            return
        }
        #expect(samePath(now, renamed))
        // Kept again by the file it was found as, it is found there.
        let kept = try store.relocateGame(game.id, to: try record(of: now))
        let relocated = try #require(kept.game(game.id))
        #expect(relocated.fileName == "Moonbase Courier (USA).iso")
        #expect(relocated.added == game.added)
        guard case .found(let there) = KeptFileReader().whereabouts(of: relocated) else {
            Issue.record("the game kept again is not found")
            return
        }
        #expect(samePath(there, renamed))
    }

    @Test func aStaleBookmarkStillLeadingToTheRecordedPathIsMoved() {
        // The system says the bookmark should be made again though the file is where the library recorded
        // it (a volume renamed and back, a file replaced in place): it is kept again quietly, never missing.
        let game = LibraryGamesTests.orchard
        let here = URL(fileURLWithPath: game.path)
        let files = ScriptedFiles(resolving: here, isStale: true)
        #expect(files.whereabouts(of: game) == .moved(here))
        #expect(ScriptedFiles(resolving: here).whereabouts(of: game) == .found(here), "the same file, its bookmark fresh, is found")
    }

    @Test func aGameRecordedAtAnotherPathIsMovedEvenWhenItsBookmarkIsntStale() throws {
        let sandbox = try Sandbox()
        let url = try sandbox.write(Data(repeating: 1, count: 2_048), to: "Games/Moonbase Courier.iso")
        var game = try record(of: url)
        game.folder = "/Volumes/Archive/Games"
        let whereabouts = KeptFileReader().whereabouts(of: game)
        guard case .moved(let now) = whereabouts else {
            Issue.record("\(whereabouts) is not moved")
            return
        }
        #expect(samePath(now, url))
    }

    @Test func aGameWhoseFileIsGoneIsMissingAndStaysInTheLibrary() throws {
        let sandbox = try Sandbox()
        let url = try sandbox.write(Data(repeating: 1, count: 2_048), to: "Games/Lantern Street.cue")
        let store = LibraryStore(url: sandbox.url("library.json"))
        let game = try record(of: url)
        try store.addGames([game])
        try FileManager.default.removeItem(at: url)
        let whereabouts = KeptFileReader().whereabouts(of: game)
        guard case .missing(.cannotResolve) = whereabouts else {
            Issue.record("\(whereabouts) is not missing(cannotResolve)")
            return
        }
        #expect(try store.load().games == [game], "never dropped")
    }

    @Test func aGameWithADamagedOrEmptyBookmarkIsMissing() {
        var game = LibraryGamesTests.orchard
        game.bookmark = Data("not a bookmark".utf8)
        guard case .missing = KeptFileReader().whereabouts(of: game) else {
            Issue.record("a damaged bookmark is not missing")
            return
        }
        game.bookmark = Data()
        guard case .missing = KeptFileReader().whereabouts(of: game) else {
            Issue.record("an empty bookmark is not missing")
            return
        }
    }

    @Test func aGameWhoseFileCantBeReachedIsMissing() {
        let failure = KeptFileError.cannotRead(path: "/Volumes/Archive/Games/PS1/Glass Orchard (Europe).cue", reason: "Permission denied.")
        let files = ScriptedFiles(failing: "size", with: failure)
        #expect(files.whereabouts(of: LibraryGamesTests.orchard) == .missing(failure))
        #expect(files.calls == ["resolve", "size"])
    }
}

/// Kept files as a test scripts them: a bookmark leads to the file `resolving` names, fresh or stale as
/// `isStale` says — a file of 512 KB — or wherever `reader` says when one is given, and the call a test
/// names fails with what it names. It records every call, in order.
// @unchecked: `log`, its one `var`, is read and written only under `lock`; the `let`s are Sendable.
final class ScriptedFiles: KeptFileReading, @unchecked Sendable {
    private let lock = NSLock()
    private var log: [String] = []
    private let reader: (any KeptFileReading)?
    private let failing: String?
    private let failure: (any Error)?
    private let resolving: URL
    private let isStale: Bool

    /// Files read through `reader`, or made up when it is nil — every bookmark leading to `resolving`,
    /// stale if `isStale` — the call `failing` names failing with `failure`.
    init(
        reader: (any KeptFileReading)? = nil, failing: String? = nil, with failure: (any Error)? = nil,
        resolving: URL = URL(fileURLWithPath: "/Volumes/Archive/Console/my-console-bios.bin"), isStale: Bool = false
    ) {
        self.reader = reader
        self.failing = failing
        self.failure = failure
        self.resolving = resolving
        self.isStale = isStale
    }

    /// Every call, in order.
    var calls: [String] { lock.withLock { log } }

    private func note(_ call: String) throws {
        lock.withLock { log.append(call) }
        if call == failing, let failure { throw failure }
    }

    func resolve(_ bookmark: Data) throws -> KeptFile.Resolved {
        try note("resolve")
        if let reader { return try reader.resolve(bookmark) }
        return KeptFile.Resolved(url: resolving, isStale: isStale)
    }

    func size(of url: URL) throws -> Int {
        try note("size")
        if let reader { return try reader.size(of: url) }
        return 524_288
    }

    func bytes(of url: URL) throws -> [UInt8] {
        try note("bytes")
        if let reader { return try reader.bytes(of: url) }
        return [UInt8](repeating: 0, count: 524_288)
    }
}
