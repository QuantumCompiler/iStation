// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessPS1
import BusinessSession
import DataLibrary
import Foundation
import Observation
import PresentationStyles

/// The BIOS pane, as the design's `Mac-BiosPane` draws it: the BIOS the library keeps — its file, its
/// size in bytes and kilobytes, its SHA-1 fingerprint in groups of four, its folder, and when the check
/// passed it — and what a person can do with it: Run the BIOS, Choose Another BIOS… (the check's) and
/// Show in Finder (the view's, with the file this finds).
///
/// Run the BIOS reads the kept file through its bookmark, powers the player's session on with it, and
/// then hands the run to `onRun`, which the app wires to the player; this module knows nothing of the
/// player. Until the library (5d) the pane is the window's one place once a BIOS is kept, and Welcome
/// shows while `hasBIOS` is false.
@MainActor
@Observable
public final class BIOSPaneViewModel {
    /// The BIOS the library keeps; nil until one is kept.
    public private(set) var record: BIOSRecord?
    /// Whether Run the BIOS is reading the file and powering the console on.
    public private(set) var isStarting = false
    /// What went wrong running or finding the kept BIOS, while its alert is open.
    public private(set) var alert: BIOSAlert?

    private let storage: any BIOSStorage
    private let session: any ConsoleSessionPowerControls
    private let home: String?
    private let calendar: Calendar
    private let now: @Sendable () -> Date
    private let onRun: @MainActor (BIOSRun) -> Void

    /// The last Run the BIOS.
    @ObservationIgnored private var starting: Task<Void, Never>?

    /// The pane over the BIOS `storage` keeps — read now, so the window knows at once whether to show
    /// Welcome — whose Run the BIOS powers on `session`, the player's, and then calls `onRun`. Folders
    /// under `home`, the person's home folder, are written from "~"; dates are written in `calendar`,
    /// today being `now`'s day.
    public init(
        storage: any BIOSStorage, session: any ConsoleSessionPowerControls, home: String? = nil,
        calendar: Calendar = .current, now: @escaping @Sendable () -> Date = { Date() },
        onRun: @escaping @MainActor (BIOSRun) -> Void
    ) {
        self.storage = storage
        self.session = session
        self.home = home
        self.calendar = calendar
        self.now = now
        self.onRun = onRun
        // An unreadable library keeps nothing that can be shown: Welcome shows, and the check says why
        // it can't keep a BIOS when it tries.
        record = try? storage.keptBIOS()
    }

    deinit {
        starting?.cancel()
    }

    // MARK: - Intents

    /// Shows `record`, the BIOS the check just kept in place of any before: Continue on its done sheet.
    public func kept(_ record: BIOSRecord) {
        self.record = record
        alert = nil
    }

    /// Reads the kept BIOS where it is kept, powers the player's session on with it from frame 0, and
    /// hands the run to `onRun`. A file that can't be found or read, or is no longer a BIOS's size,
    /// opens an alert instead and powers nothing on. Nothing while a start is under way.
    public func runBIOS() {
        guard let record, !isStarting else { return }
        isStarting = true
        alert = nil
        starting = Task { [weak self] in
            await self?.start(record)
        }
    }

    /// The kept file, where its bookmark leads now, for Show in Finder; nil, with an alert saying why,
    /// when it can't be found.
    public func fileToShowInFinder() -> URL? {
        guard let record else { return nil }
        do {
            let resolved = try storage.resolve(record.bookmark)
            if resolved.isStale { remake(record, at: resolved.url) }
            return resolved.url
        } catch {
            alert = BIOSAlert(
                title: "The BIOS couldn’t be found",
                message: "iStation couldn’t find \(shownName(record)) where you keep it. Put it back, or choose it again.",
                details: BIOSText.threw("KeptFile.resolve(_:)", error)
            )
            return nil
        }
    }

    /// Closes the open alert.
    public func dismissAlert() {
        alert = nil
    }

    // MARK: - What the pane shows

    /// Whether the library keeps a BIOS: the pane shows; otherwise Welcome does.
    public var hasBIOS: Bool { record != nil }

    /// Whether Run the BIOS applies: a BIOS is kept and no start is under way.
    public var canRun: Bool { record != nil && !isStarting }

    /// The window's title over the pane, as the design's toolbar names it.
    public var windowTitle: String { "BIOS" }

    /// The window's subtitle over the pane: the kept file's name.
    public var windowSubtitle: String { fileName }

    /// The kept file's name: "my-console-bios.bin".
    public var fileName: String { record?.fileName ?? "" }

    /// Its size in bytes and kilobytes: "524,288 bytes (512 KB)".
    public var sizeText: String { BIOSText.bytesAndKilobytes(record?.size ?? 0) }

    /// Its SHA-1 fingerprint in groups of four: "SHA-1 3f9a 1c0e 52d4 …".
    public var fingerprintText: String {
        guard let sha1 = record?.sha1, !sha1.isEmpty else { return "SHA-1 unknown" }
        return BIOSText.fingerprint(sha1)
    }

    /// The folder it was kept from, from "~" under the home folder: "In ~/Documents/Console".
    public var folderText: String {
        guard let folder = record?.folder, !folder.isEmpty else { return "In an unknown folder" }
        return "In " + shown(folder)
    }

    /// When the check passed it: "Checked Nov 20: it reached its shell.", "Checked Today: …" on the
    /// day, the year added for another year's; without the date when the library didn't record one.
    public var checkedText: String {
        let verdict = ": it reached its shell."
        guard let checked = record?.checked, checked != .distantPast else { return "Checked" + verdict }
        let today = now()
        if calendar.isDate(checked, inSameDayAs: today) { return "Checked Today" + verdict }
        var style = Date.FormatStyle().month(.abbreviated).day()
        if calendar.component(.year, from: checked) != calendar.component(.year, from: today) { style = style.year() }
        style.locale = Locale(identifier: "en_US")
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        return "Checked " + checked.formatted(style) + verdict
    }

    /// The pane's note on how the file is kept.
    public var keptByBookmarkText: String { BIOSText.keptByBookmark }

    /// The pane's note on what a BIOS is, with the one sentence of guidance.
    public var noteText: String { BIOSText.paneNote }

    // MARK: - Running

    /// Reads `record`'s file, powers the player's session on with it and hands the run on.
    private func start(_ record: BIOSRecord) async {
        defer { isStarting = false }
        let storage = self.storage
        let name = shownName(record)
        let resolved: KeptFile.Resolved
        let size: Int
        do {
            resolved = try await Task.detached { try storage.resolve(record.bookmark) }.value
        } catch {
            alert = unreadable(name, BIOSText.threw("KeptFile.resolve(_:)", error))
            return
        }
        do {
            size = try await Task.detached { try storage.size(of: resolved.url) }.value
        } catch {
            alert = unreadable(name, BIOSText.threw("KeptFile.size(at:)", error))
            return
        }
        // A file that is no longer a BIOS's size isn't read whole, as the check doesn't read one.
        guard size == BIOSText.biosSize else {
            alert = wrongSize(name, size, BIOSCheckViewModel.powerOnRefusal(size))
            return
        }
        let bytes: [UInt8]
        do {
            bytes = try await Task.detached { try storage.bytes(of: resolved.url) }.value
        } catch {
            alert = unreadable(name, BIOSText.threw("KeptFile.bytes(at:)", error))
            return
        }
        if resolved.isStale { remake(record, at: resolved.url) }
        do {
            try await session.powerOn(bios: bytes, exe: nil)
        } catch {
            alert = wrongSize(name, bytes.count, BIOSText.threw("PS1Console.powerOn(bios:)", error))
            return
        }
        onRun(BIOSRun(fileName: resolved.url.lastPathComponent, size: bytes.count))
    }

    /// Keeps `record` again with a new bookmark to the file where it is now — it moved or was renamed —
    /// and its name and folder there. Left as it was if either can't be made.
    private func remake(_ record: BIOSRecord, at url: URL) {
        guard let bookmark = try? storage.bookmark(for: url) else { return }
        var moved = record
        moved.bookmark = bookmark
        moved.fileName = url.lastPathComponent
        moved.folder = url.deletingLastPathComponent().path
        guard (try? storage.keep(moved)) != nil else { return }
        self.record = moved
    }

    /// The alert for a kept file that can't be found or read.
    private func unreadable(_ name: String, _ details: String) -> BIOSAlert {
        BIOSAlert(
            title: "The BIOS couldn’t be read",
            message: "iStation couldn’t open \(name) where you keep it. Put it back, or choose it again.",
            details: details
        )
    }

    /// The alert for a kept file that is no longer a BIOS's size.
    private func wrongSize(_ name: String, _ bytes: Int, _ details: String) -> BIOSAlert {
        BIOSAlert(
            title: "This BIOS can’t be run",
            message: "\(name) is now \(BIOSText.bytes(bytes)). A PS1 BIOS is exactly \(BIOSText.bytes(BIOSText.biosSize)). Choose the BIOS file itself.",
            details: details
        )
    }

    /// The record's file name, or "your BIOS" when the library didn't record one.
    private func shownName(_ record: BIOSRecord) -> String {
        record.fileName.isEmpty ? "your BIOS" : record.fileName
    }

    /// `folder`, from "~" when it is the home folder or inside it.
    private func shown(_ folder: String) -> String {
        guard var home, !home.isEmpty else { return folder }
        while home.count > 1 && home.hasSuffix("/") { home.removeLast() }
        if folder == home { return "~" }
        guard folder.hasPrefix(home + "/") else { return folder }
        return "~" + folder.dropFirst(home.count)
    }

    /// Waits until the last Run the BIOS has finished; the tests' way to know.
    func settled() async {
        await starting?.value
    }
}
