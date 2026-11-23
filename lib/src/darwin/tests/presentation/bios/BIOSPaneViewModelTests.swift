// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessPS1
import BusinessSession
import DataLibrary
import Foundation
@testable import PresentationBIOS
import Testing

/// Dates in UTC, so the tests read the same wherever they run.
private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
    return calendar
}()

/// 2026-11-22 12:00 UTC, the tests' today, and 2026-11-20 12:00 UTC, when the design's BIOS was checked.
private let today = Date(timeIntervalSince1970: 1_795_348_800)
private let nov20 = Date(timeIntervalSince1970: 1_795_176_000)

/// The design's kept BIOS, its bookmark the fake's: the file's path.
private func record(_ file: URL = Files.bios, checked: Date = nov20, sha1: String = "3f9a1c0e52d488b0e7a14c269d0f51aa7b21c3e8") -> BIOSRecord {
    BIOSRecord(
        fileName: file.lastPathComponent, folder: file.deletingLastPathComponent().path, size: 524_288,
        sha1: sha1, checked: checked, bookmark: Data(file.path.utf8)
    )
}

@MainActor
@Suite struct BIOSPaneViewModelTests {
    let storage = FakeStorage(record: record(), files: [Files.bios: biosImage])
    let log = EventLog()
    let session: FakePowerSession

    init() {
        session = FakePowerSession(log: log)
    }

    /// A pane over this suite's storage and session, in UTC, today being Nov 22.
    func makePane(home: String? = Files.home, now: Date = today) -> BIOSPaneViewModel {
        let log = self.log
        return BIOSPaneViewModel(storage: storage, session: session, home: home, calendar: utc, now: { now }) { run in
            log.note("started \(run.fileName), \(run.size) bytes")
        }
    }

    // MARK: - What the pane shows

    @Test func theKeptBIOSIsShownAsTheDesignWritesIt() {
        let pane = makePane()
        #expect(pane.hasBIOS)
        #expect(pane.record == record())
        #expect(pane.fileName == "my-console-bios.bin")
        #expect(pane.sizeText == "524,288 bytes (512 KB)")
        #expect(pane.fingerprintText == "SHA-1 3f9a 1c0e 52d4 88b0 e7a1 4c26 9d0f 51aa 7b21 c3e8")
        #expect(pane.folderText == "In ~/Documents/Console")
        #expect(pane.checkedText == "Checked Nov 20: it reached its shell.")
        #expect(pane.windowTitle == "BIOS")
        #expect(pane.windowSubtitle == "my-console-bios.bin")
        #expect(pane.keptByBookmarkText == "iStation keeps a bookmark to this file and reads it each time the console starts. It never copies the file.")
        #expect(pane.noteText == "A BIOS is the small program built into a console that starts it up. iStation runs yours, so your games start the way they do on your console. It comes from your own console: iStation can’t provide one, and it expects a 512 KB file. When PS2 games arrive, they won’t need a BIOS file.")
        #expect(pane.canRun)
        #expect(pane.alert == nil)
        #expect(storage.calls == [.keptBIOS], "the pane reads the library once, and no file")
    }

    @Test func aFingerprintWithLeadingZerosKeepsThemInItsGroups() {
        try? storage.keep(record(sha1: "000a00000000000000000000000000000000c0de"))
        #expect(makePane().fingerprintText == "SHA-1 000a 0000 0000 0000 0000 0000 0000 0000 0000 c0de")
    }

    @Test func aBIOSCheckedTodayWasCheckedToday() {
        try? storage.keep(record(checked: today.addingTimeInterval(-3_600)))
        #expect(makePane().checkedText == "Checked Today: it reached its shell.")
    }

    @Test func aBIOSCheckedInAnotherYearNamesTheYear() {
        try? storage.keep(record(checked: Date(timeIntervalSince1970: 1_763_640_000)))  // 2025-11-20 12:00 UTC
        #expect(makePane().checkedText == "Checked Nov 20, 2025: it reached its shell.")
    }

    @Test func aCheckTheLibraryDidntDateLeavesTheDateOut() {
        try? storage.keep(record(checked: .distantPast))
        #expect(makePane().checkedText == "Checked: it reached its shell.")
    }

    @Test func foldersAreWrittenFromTheHomeFolderOnlyInsideIt() {
        #expect(makePane(home: "/Users/you/").folderText == "In ~/Documents/Console")
        #expect(makePane(home: "/Users/yo").folderText == "In /Users/you/Documents/Console", "a folder beside home isn't inside it")
        #expect(makePane(home: nil).folderText == "In /Users/you/Documents/Console")
        try? storage.keep(record(Files.elsewhere))
        #expect(makePane().folderText == "In /Volumes/Archive/Console")
        try? storage.keep(record(URL(fileURLWithPath: "/Users/you/bios.bin")))
        #expect(makePane().folderText == "In ~")
    }

    @Test func aRecordMissingItsFieldsSaysSo() {
        try? storage.keep(BIOSRecord(fileName: "", folder: "", size: 0, sha1: "", checked: .distantPast, bookmark: Data()))
        let pane = makePane()
        #expect(pane.hasBIOS)
        #expect(pane.fingerprintText == "SHA-1 unknown")
        #expect(pane.folderText == "In an unknown folder")
    }

    @Test func noKeptBIOSMeansWelcomeShows() {
        let empty = FakeStorage()
        let pane = BIOSPaneViewModel(storage: empty, session: session) { _ in }
        #expect(!pane.hasBIOS)
        #expect(!pane.canRun)
        #expect(pane.fileToShowInFinder() == nil)
        pane.runBIOS()
        #expect(!pane.isStarting)
    }

    @Test func aLibraryThatCantBeReadShowsWelcome() {
        storage.fail(FakeStorage.Failures(load: .newerVersion(2, path: "/Library/library.json")))
        #expect(!makePane().hasBIOS)
    }

    @Test func theCheckKeepingAnotherBIOSShowsIt() {
        let pane = makePane()
        let copy = record(Files.copy)
        pane.kept(copy)
        #expect(pane.record == copy)
        #expect(pane.fileName == "bios-copy.bin")
    }

    // MARK: - Run the BIOS

    @Test func runTheBIOSPowersThePlayersSessionOnThenHandsTheRunOn() async {
        let pane = makePane()
        pane.runBIOS()
        #expect(pane.isStarting)
        #expect(!pane.canRun)
        #expect(await settled(pane))
        #expect(!pane.isStarting)
        #expect(pane.canRun)
        #expect(log.noted == ["powered on", "started my-console-bios.bin, 524288 bytes"], "the player is told once its session is on")
        #expect(await session.controls == [.powerOn(bytes: 524_288, exe: false)])
        #expect(await session.bios == biosImage, "powered on with the kept file's own bytes")
        #expect(await session.snapshot == ConsoleSessionSnapshot(state: .running), "from frame 0")
        #expect(pane.alert == nil)
        #expect(storage.calls == [.keptBIOS, .resolve, .size(Files.bios.path), .bytes(Files.bios.path)])
    }

    @Test func runTheBIOSThatCantBeFoundSaysWhyAndPowersNothingOn() async {
        let pane = makePane()
        storage.fail(FakeStorage.Failures(resolve: .cannotResolve(reason: "No such file.")))
        pane.runBIOS()
        #expect(await settled(pane))
        #expect(pane.alert == BIOSAlert(
            title: "The BIOS couldn’t be read",
            message: "iStation couldn’t open my-console-bios.bin where you keep it. Put it back, or choose it again.",
            details: #"KeptFile.resolve(_:) threw KeptFileError.cannotResolve(reason: "No such file.")"#
        ))
        #expect(log.noted.isEmpty)
        #expect(await session.calls.isEmpty)
        pane.dismissAlert()
        #expect(pane.alert == nil)
    }

    @Test func runTheBIOSThatCantBeSizedOrReadNamesTheCallThatFailed() async {
        let gone = KeptFileError.cannotRead(path: Files.bios.path, reason: "Gone.")
        let threw = #"threw KeptFileError.cannotRead(path: "/Users/you/Documents/Console/my-console-bios.bin", reason: "Gone.")"#
        storage.fail(FakeStorage.Failures(size: gone))
        var pane = makePane()
        pane.runBIOS()
        #expect(await settled(pane))
        #expect(pane.alert == BIOSAlert(
            title: "The BIOS couldn’t be read",
            message: "iStation couldn’t open my-console-bios.bin where you keep it. Put it back, or choose it again.",
            details: "KeptFile.size(at:) " + threw
        ))
        #expect(storage.reads(of: Files.bios) == 0, "not read once it couldn't be sized")

        storage.fail(FakeStorage.Failures(bytes: gone))
        pane = makePane()
        pane.runBIOS()
        #expect(await settled(pane))
        #expect(pane.alert == BIOSAlert(
            title: "The BIOS couldn’t be read",
            message: "iStation couldn’t open my-console-bios.bin where you keep it. Put it back, or choose it again.",
            details: "KeptFile.bytes(at:) " + threw
        ))
        #expect(await session.calls.isEmpty)
        #expect(log.noted.isEmpty)
    }

    @Test func runTheBIOSThatIsNoLongerABIOSsSizeSaysWhyUnread() async {
        storage.put([UInt8](repeating: 0, count: 1_000), at: Files.bios)
        let pane = makePane()
        pane.runBIOS()
        #expect(await settled(pane))
        #expect(pane.alert == BIOSAlert(
            title: "This BIOS can’t be run",
            message: "my-console-bios.bin is now 1,000 bytes. A PS1 BIOS is exactly 524,288 bytes. Choose the BIOS file itself.",
            details: "PS1Console.powerOn(bios:) threw PS1Error.biosSize(1000)"
        ))
        #expect(storage.reads(of: Files.bios) == 0)
        #expect(await session.calls.isEmpty)
        #expect(log.noted.isEmpty)
    }

    @Test func aMovedBIOSIsBookmarkedAgainWhereItIsNowAndRuns() async {
        let pane = makePane()
        storage.move(Files.bios, to: Files.elsewhere)
        pane.runBIOS()
        #expect(await settled(pane))
        let moved = record(Files.elsewhere)
        #expect(storage.kept == moved, "kept again by a bookmark to where it is now")
        #expect(pane.record == moved)
        #expect(pane.folderText == "In /Volumes/Archive/Console")
        #expect(log.noted == ["powered on", "started my-console-bios.bin, 524288 bytes"])
    }

    // MARK: - Show in Finder

    @Test func showInFinderFindsTheKeptFile() {
        let pane = makePane()
        #expect(pane.fileToShowInFinder() == Files.bios)
        #expect(pane.alert == nil)
    }

    @Test func showInFinderOnAFileThatIsGoneSaysWhy() {
        let pane = makePane()
        storage.fail(FakeStorage.Failures(resolve: .cannotResolve(reason: "No such file.")))
        #expect(pane.fileToShowInFinder() == nil)
        #expect(pane.alert?.title == "The BIOS couldn’t be found")
        #expect(pane.alert?.message == "iStation couldn’t find my-console-bios.bin where you keep it. Put it back, or choose it again.")
        #expect(pane.alert?.details == #"KeptFile.resolve(_:) threw KeptFileError.cannotResolve(reason: "No such file.")"#)
    }

    // MARK: - Choose Another BIOS…

    @Test func chooseAnotherBIOSReplacesTheKeptOneOnlyWhenTheCheckPasses() async {
        let kept = record()
        storage.put([UInt8](repeating: 0, count: 271_384), at: Files.backup)
        storage.put(biosImage, at: Files.copy)
        let pane = makePane()
        let checkSession = FakePowerSession()
        let check = BIOSCheckViewModel(session: checkSession, storage: storage, now: { today }) { pane.kept($0) }

        // A file of another size: refused, the kept BIOS stays.
        check.check(Files.backup)
        #expect(await settled(check))
        check.close()
        #expect(pane.record == kept)
        #expect(storage.kept == kept)

        // A file that never reaches its shell: refused at frame 600, the kept BIOS stays.
        check.check(Files.copy)
        #expect(await followed(checkSession))
        await checkSession.run(to: 600)
        #expect(await eventually { check.state == .failed(.shell, .noShell) })
        check.close()
        #expect(pane.record == kept)
        #expect(storage.kept == kept)

        // A file that reaches it: kept in place of the old, and the pane shows it once the person continues.
        check.check(Files.copy)
        #expect(await eventually { check.state == .running(.frames) })
        #expect(await followed(checkSession))
        await checkSession.run(to: 60, reachedShell: true)
        #expect(await eventually { check.state == .done })
        #expect(storage.kept?.fileName == "bios-copy.bin")
        #expect(pane.record == kept)
        check.finish()
        #expect(pane.record?.fileName == "bios-copy.bin")
        #expect(pane.record == storage.kept)
        #expect(await session.calls.isEmpty, "the check never touches the player's session")
    }
}
