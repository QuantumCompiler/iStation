// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

#if DEBUG
import BusinessPS1
import BusinessSession
import DataLibrary
import Foundation
import os
import PresentationStyles
import SwiftUI

/// A console session for the previews: no console. Powering on takes a BIOS's size, refusing another as
/// the console does, and runs nothing; whoever follows the session then hears the snapshots the preview
/// scripts, in order, and the stream stays open after the last, so a check stays where the script leaves
/// it. Stop ends every stream with the stopped snapshot, as the session's does.
actor PreviewPowerSession: ConsoleSessionPowerControls {
    private var current = ConsoleSessionSnapshot()
    /// The snapshots still to send once powered on.
    private var script: [ConsoleSessionSnapshot]
    private var streams: [AsyncStream<ConsoleSessionSnapshot>.Continuation] = []

    /// A session, powered off, that sends `frames` once it is powered on and followed.
    init(frames: [ConsoleSessionSnapshot] = []) {
        script = frames
    }

    var snapshot: ConsoleSessionSnapshot { current }

    func powerOn(bios: [UInt8], exe: PSEXE?) throws(PS1Error) {
        guard bios.count == PS1Bus.biosSize else { throw .biosSize(bios.count) }
        current = ConsoleSessionSnapshot(state: .running)
        publish()
    }

    func pause() {}

    func resume() {}

    func reset() {}

    func stop() {
        current.state = .stopped
        current.framesPerSecond = 0
        publish()
        for stream in streams { stream.finish() }
        streams = []
    }

    func snapshots() -> AsyncStream<ConsoleSessionSnapshot> {
        let (stream, continuation) = AsyncStream.makeStream(of: ConsoleSessionSnapshot.self)
        continuation.yield(current)
        guard current.state != .stopped else {
            continuation.finish()
            return stream
        }
        if current.state == .running {
            for next in script {
                current = next
                continuation.yield(next)
            }
            script = []
        }
        // Held open after the script's last snapshot, until a stop.
        streams.append(continuation)
        return stream
    }

    private func publish() {
        for stream in streams { stream.yield(current) }
    }
}

/// A library and the chosen file for the previews, held in memory as each preview scripts it: the file
/// is `size` bytes, every one `fill` — made up, never a real BIOS's and never the person's — and its
/// read, the library's keep or finding the kept file fails where a preview says. It keeps a record in
/// memory and writes no file.
struct PreviewStorage: BIOSStorage {
    /// The record kept, in memory.
    private let record: OSAllocatedUnfairLock<BIOSRecord?>
    /// The file's size in bytes.
    private let size: Int
    /// The one byte the file is made of.
    private let fill: UInt8
    /// Whether reading the file's bytes fails, as a file without permission to read does.
    private let failsToRead: Bool
    /// Whether keeping a record fails, as a library on a read-only volume does.
    private let failsToKeep: Bool
    /// Whether the kept file can't be found, as a moved or deleted one can't.
    private let isMissing: Bool

    /// A library keeping `record`, its file `size` bytes of `fill`, failing where the flags say.
    init(
        record: BIOSRecord? = nil, size: Int = PS1Bus.biosSize, fill: UInt8 = 0,
        failsToRead: Bool = false, failsToKeep: Bool = false, isMissing: Bool = false
    ) {
        self.record = OSAllocatedUnfairLock(initialState: record)
        self.size = size
        self.fill = fill
        self.failsToRead = failsToRead
        self.failsToKeep = failsToKeep
        self.isMissing = isMissing
    }

    func keptBIOS() -> BIOSRecord? { record.withLock { $0 } }

    func keep(_ record: BIOSRecord) throws {
        if failsToKeep { throw LibraryStoreError.cannotWrite(path: PreviewBIOS.library.path, reason: "The volume is read only.") }
        self.record.withLock { $0 = record }
    }

    func bookmark(for url: URL) -> Data { Data() }

    func resolve(_ bookmark: Data) throws -> KeptFile.Resolved {
        if isMissing { throw KeptFileError.cannotResolve(reason: "The file couldn’t be opened because it doesn’t exist.") }
        return KeptFile.Resolved(url: PreviewBIOS.file, isStale: false)
    }

    func size(of url: URL) -> Int { size }

    func bytes(of url: URL) throws -> [UInt8] {
        if failsToRead { throw KeptFileError.cannotRead(path: url.path, reason: "You don’t have permission to view it.") }
        return [UInt8](repeating: fill, count: size)
    }
}

/// The BIOS check and pane for the previews, one per visible state, as the design's prototype reports
/// them (`html/main.html`'s BIOS_OK, BIOS_WRONG and BIOS_NO_SHELL): its made-up files and folders, dated
/// Nov 20, 2026, seen on Nov 22. Each state is reached as a person reaches it — the check is handed a
/// file and runs over a `PreviewStorage` and a `PreviewPowerSession` scripted for that state — so the
/// check's fingerprints are worked out from the previews' made-up bytes, not the design's placeholders;
/// the pane shows the design's placeholder, the record it keeps being built here.
@MainActor
enum PreviewBIOS {
    /// A made-up home folder, so folders inside it are written from "~".
    nonisolated static let home = "/Users/you"
    /// The design's kept BIOS, in ~/Documents/Console.
    nonisolated static let file = URL(fileURLWithPath: "/Users/you/Documents/Console/my-console-bios.bin")
    /// The design's file of the wrong size, in ~/Downloads.
    nonisolated static let backup = URL(fileURLWithPath: "/Users/you/Downloads/bios-backup.zip")
    /// The design's copy that never reaches its shell, in ~/Documents/Console.
    nonisolated static let copy = URL(fileURLWithPath: "/Users/you/Documents/Console/bios-copy.bin")
    /// A made-up library, named by the keep that fails.
    nonisolated static let library = URL(fileURLWithPath: "/Users/you/Library/Application Support/library.json")
    /// The design's fingerprint for the kept BIOS: a placeholder, not any real BIOS's.
    nonisolated static let sha1 = "3f9a1c0e52d488b0e7a14c269d0f51aa7b21c3e8"

    /// Dates in UTC, so every preview reads the same wherever it is drawn.
    nonisolated static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
        return calendar
    }()

    /// Nov 22, 2026, noon: the previews' today.
    nonisolated static let today = Date(timeIntervalSince1970: 1_795_348_800)
    /// Nov 20, 2026, when the design's BIOS was checked.
    nonisolated static let checked = Date(timeIntervalSince1970: 1_795_176_000)

    /// The design's kept BIOS, checked on `day`.
    static func record(checked day: Date = checked) -> BIOSRecord {
        BIOSRecord(
            fileName: file.lastPathComponent, folder: file.deletingLastPathComponent().path, size: PS1Bus.biosSize,
            sha1: sha1, checked: day, bookmark: Data()
        )
    }

    // MARK: The check

    /// A check showing nothing: Welcome's, and the pane's Choose Another BIOS….
    static func check() -> BIOSCheckViewModel {
        BIOSCheckViewModel(session: PreviewPowerSession(), storage: PreviewStorage(), now: { today })
    }

    /// Welcome with the file chooser asked for (the design's bios-picker).
    static func choosing() -> BIOSCheckViewModel {
        let check = check()
        check.chooseFile()
        return check
    }

    /// Checking the design's BIOS, 24 of its 60 frames run (bios-checking).
    static func checking() -> BIOSCheckViewModel {
        checking(file, frames: [frame(24)])
    }

    /// The design's BIOS past its 60 frames, run on to frame 240 looking for its shell.
    static func reachingShell() -> BIOSCheckViewModel {
        checking(file, frames: [frame(240)])
    }

    /// A file of the wrong size, refused before it was read (bios-wrong-size).
    static func wrongSize() -> BIOSCheckViewModel {
        checking(backup, storage: PreviewStorage(size: 271_384))
    }

    /// A 512 KB file that powered on but never reached its shell, refused at frame 600 (bios-no-shell):
    /// every byte 0xFF, as an erased copy's, so its fingerprint isn't the kept BIOS's.
    static func noShell() -> BIOSCheckViewModel {
        checking(copy, storage: PreviewStorage(fill: 0xFF), frames: [frame(600)])
    }

    /// A BIOS that reached its shell at frame 60 and is kept (bios-done).
    static func done() -> BIOSCheckViewModel {
        checking(file, frames: [frame(60, reachedShell: true)])
    }

    /// A check the person stopped during its frames, keeping nothing: Checking's, stopped with Stop once
    /// it shows frame 24.
    static func stopped() -> BIOSCheckViewModel {
        let check = checking()
        Task { [weak check] in
            // The check hears its session on a task of its own: watch what it shows, as the sheet does,
            // for two seconds at most.
            let deadline = ContinuousClock.now.advanced(by: .seconds(2))
            while let shown = check, shown.frame < 24, ContinuousClock.now < deadline {
                try? await Task.sleep(for: .milliseconds(5))
            }
            check?.stop()
        }
        return check
    }

    /// A file that couldn't be read: sized as a BIOS, its bytes refused.
    static func unreadable() -> BIOSCheckViewModel {
        checking(file, storage: PreviewStorage(failsToRead: true))
    }

    /// A BIOS that reached its shell at frame 75, which the library couldn't keep.
    static func notKept() -> BIOSCheckViewModel {
        checking(file, storage: PreviewStorage(failsToKeep: true), frames: [frame(75, reachedShell: true)])
    }

    /// A check of `url` over `storage`, its session sending `frames` once powered on.
    private static func checking(
        _ url: URL, storage: PreviewStorage = PreviewStorage(), frames: [ConsoleSessionSnapshot] = []
    ) -> BIOSCheckViewModel {
        let check = BIOSCheckViewModel(session: PreviewPowerSession(frames: frames), storage: storage, now: { today })
        check.check(url)
        return check
    }

    /// Frame `number` of a running session at 60 frames a second, the shell reached or not.
    private static func frame(_ number: Int, reachedShell: Bool = false) -> ConsoleSessionSnapshot {
        ConsoleSessionSnapshot(state: .running, frame: number, framesPerSecond: 60, reachedShell: reachedShell)
    }

    // MARK: The pane

    /// The pane over the design's kept BIOS, checked Nov 20, or today (bios-pane).
    static func pane(checkedToday: Bool = false) -> BIOSPaneViewModel {
        pane(over: PreviewStorage(record: record(checked: checkedToday ? today : checked)))
    }

    /// The pane after Run the BIOS couldn't find the kept file: the file is missing, and the pane runs it.
    static func paneThatCantRun() -> BIOSPaneViewModel {
        let pane = pane(over: PreviewStorage(record: record(), isMissing: true))
        pane.runBIOS()
        return pane
    }

    /// The pane over `storage`, its Run the BIOS powering on a session that runs nothing.
    private static func pane(over storage: PreviewStorage) -> BIOSPaneViewModel {
        BIOSPaneViewModel(
            storage: storage, session: PreviewPowerSession(), home: home,
            calendar: calendar, now: { today }, onRun: { _ in }
        )
    }
}

extension View {
    /// The preview as the window's content shows it: the default window, below its toolbar.
    func inPreviewWindow() -> some View {
        frame(width: Metrics.layout.windowWidth, height: Metrics.layout.windowHeight - Metrics.layout.toolbar)
    }
}
#endif
