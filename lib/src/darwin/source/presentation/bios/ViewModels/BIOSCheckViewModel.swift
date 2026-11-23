// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessPS1
import BusinessSession
import DataLibrary
import Foundation
import Observation
import PresentationStyles

/// The BIOS check, as the design's job sheet runs it (boards `Mac-BiosChecking`, `Mac-BiosWrongSize`,
/// `Mac-BiosNoShell`, `Mac-BiosDone`): read the file the person chose, check its size, work out its
/// SHA-1 fingerprint, power on and run 60 frames, then run on until the BIOS reaches its shell — kept
/// in the library by its bookmark once it does, refused if it hasn't by frame 600. Stop ends the check
/// and keeps nothing.
///
/// It runs on a console session of its own, never the player's: the player follows its session across
/// a stop, so a check on that one would take the window. The chooser is `isChoosingFile`, which the view
/// binds the system's file importer to; the file it gives comes back through `check(_:)`. A file of
/// another size is refused before it is read, so a disc image chosen by mistake is never read whole.
@MainActor
@Observable
public final class BIOSCheckViewModel {
    /// The check's steps, in order, as the job sheet names them.
    public enum Step: Int, Sendable, CaseIterable {
        /// "Read the file": its bookmark, its size and, when that is a BIOS's, its bytes.
        case read
        /// "Check its size": 524,288 bytes.
        case size
        /// "Work out its fingerprint": its SHA-1.
        case fingerprint
        /// "Power on and run 60 frames", on the check's own session.
        case frames
        /// "Reach the BIOS’s shell": on until the shell, or refused at frame 600.
        case shell

        /// The step's name in the job sheet.
        public var name: String {
            switch self {
            case .read: "Read the file"
            case .size: "Check its size"
            case .fingerprint: "Work out its fingerprint"
            case .frames: "Power on and run 60 frames"
            case .shell: "Reach the BIOS’s shell"
            }
        }
    }

    /// Why a check refused the file, or couldn't keep it.
    public enum Failure: Equatable, Sendable {
        /// The file couldn't be bookmarked, sized or read; `details` names the call and what it threw.
        case unreadable(details: String)
        /// The file is `bytes` long, not a BIOS's 524,288; `details` names the error powering on throws.
        case wrongSize(bytes: Int, details: String)
        /// The BIOS powered on and ran 600 frames without reaching its shell.
        case noShell
        /// The BIOS reached its shell, but the library couldn't keep it; `details` names what it threw.
        case notKept(details: String)
    }

    /// Where the check stands: each visibly different state of its sheet.
    public enum State: Equatable, Sendable {
        /// No check: the sheet is closed.
        case idle
        /// The check is on `Step`.
        case running(Step)
        /// The BIOS reached its shell and the library keeps it.
        case done
        /// The check ended at `Step`, for `Failure`, keeping nothing.
        case failed(Step, Failure)
        /// The person stopped the check at `Step`; nothing was kept.
        case stopped(Step)
    }

    /// Frames the check runs before it looks for the shell.
    public static let framesToRun = 60
    /// The frame by which the BIOS must have reached its shell.
    public static let shellDeadline = 600

    /// Where the check stands.
    public private(set) var state: State = .idle
    /// Whether the system's file chooser is open, for one file of any type; the view binds
    /// `.fileImporter` to it, and the person's choice comes back through `check(_:)`.
    public var isChoosingFile = false
    /// The chosen file's name: the sheet's subtitle.
    public private(set) var fileName = ""
    /// The chosen file's size in bytes, once read.
    public private(set) var size: Int?
    /// Its SHA-1 fingerprint, 40 lowercase hex digits, once worked out.
    public private(set) var sha1: String?
    /// Frames the check's session has run since it powered on.
    public private(set) var frame = 0
    /// The record the library keeps once the BIOS reached its shell; nil until then.
    public private(set) var kept: BIOSRecord?

    private let session: any ConsoleSessionPowerControls
    private let storage: any BIOSStorage
    private let now: @Sendable () -> Date
    private let onKept: @MainActor (BIOSRecord) -> Void

    /// Which check is current: stopping or starting another moves it on, and a check whose number has
    /// passed changes nothing more.
    @ObservationIgnored private var generation = 0
    /// The check now running, or the last one.
    @ObservationIgnored private var work: Task<Void, Never>?
    /// The last stop sent to the session.
    @ObservationIgnored private var stopping: Task<Void, Never>?

    /// A check that powers on `session`, its own, reads and keeps through `storage`, dates a kept BIOS by
    /// `now`, and hands the kept record to `onKept` when the person continues from the done sheet.
    public init(
        session: any ConsoleSessionPowerControls, storage: any BIOSStorage,
        now: @escaping @Sendable () -> Date = { Date() },
        onKept: @escaping @MainActor (BIOSRecord) -> Void = { _ in }
    ) {
        self.session = session
        self.storage = storage
        self.now = now
        self.onKept = onKept
    }

    deinit {
        work?.cancel()
    }

    // MARK: - Intents

    /// Opens the file chooser — Choose BIOS File…, Choose Another BIOS…, Choose Another File…, Check
    /// Again — closing a finished check's sheet first: a done one hands its kept record on, as Continue
    /// does, since the library already keeps it. Nothing while a check runs.
    public func chooseFile() {
        guard !isRunning else { return }
        if state == .done { finish() }
        state = .idle
        isChoosingFile = true
    }

    /// Checks the file at `url`, the one the person chose. Nothing while a check runs.
    public func check(_ url: URL) {
        guard !isRunning else { return }
        isChoosingFile = false
        generation += 1
        let run = generation
        fileName = url.lastPathComponent
        size = nil
        sha1 = nil
        frame = 0
        kept = nil
        state = .running(.read)
        // A check after another starts once the one before has finished and its stop has reached the
        // session, so nothing of it can stop this one's console.
        let previous = work
        let previousStop = stopping
        work = Task { [weak self] in
            await previous?.value
            await previousStop?.value
            await self?.run(url, run)
        }
    }

    /// Stops the running check where it is, keeping nothing: the session is stopped if it was powered
    /// on. Stop, ⌘. and Escape while it runs.
    public func stop() {
        guard case .running(let step) = state else { return }
        generation += 1
        work?.cancel()
        state = .stopped(step)
        if step.rawValue >= Step.frames.rawValue { sendStop() }
    }

    /// Closes a check that stopped or failed: Close and Cancel. Nothing while one runs or is done.
    public func close() {
        switch state {
        case .failed, .stopped: state = .idle
        case .idle, .running, .done: break
        }
    }

    /// Closes the done sheet and hands the kept record on: Continue. Nothing unless done.
    public func finish() {
        guard state == .done, let kept else { return }
        state = .idle
        onKept(kept)
    }

    /// Does what the job sheet's button `action` says.
    public func perform(_ action: JobPresentation.Action) {
        switch action.role {
        case .stop: stop()
        case .close: close()
        case .finish: finish()
        case .retry: chooseFile()
        }
    }

    /// The sheet was closed without a button: a running check stops, a done one continues, any other closes.
    public func dismiss() {
        switch state {
        case .running: stop()
        case .done: finish()
        case .idle, .failed, .stopped: close()
        }
    }

    // MARK: - What the sheet shows

    /// Whether a check is under way.
    public var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    /// Whether the buttons and the menu item behind the sheet can open the chooser now: no sheet shows,
    /// as the design has it, where a key or button under a sheet does nothing. A finished check's sheet
    /// chooses again through its own button, `perform(_:)`.
    public var canChooseFile: Bool { state == .idle }

    /// Whether the job sheet shows. It reads only the state, which changes once a step, so what reads it
    /// — the sheet's presenter, the menus — isn't redrawn every frame the check counts.
    public var isShowingJob: Bool { state != .idle }

    /// The job sheet's contents; nil while no check is shown.
    public var job: JobPresentation? {
        let current: Int
        let stepState: JobPresentation.StepState
        switch state {
        case .idle: return nil
        case .running(let step): (current, stepState) = (step.rawValue, .running)
        case .done: (current, stepState) = (Step.allCases.count, .done)
        case .failed(let step, _): (current, stepState) = (step.rawValue, .failed)
        case .stopped(let step): (current, stepState) = (step.rawValue, .stopped)
        }
        let poweredOn = current >= Step.frames.rawValue
        let framesRun = min(frame, Self.framesToRun)
        let details: [Step: String?] = [
            .read: size.map(BIOSText.bytes),
            .size: "A PS1 BIOS is " + BIOSText.bytesAndKilobytes(BIOSText.biosSize),
            .fingerprint: sha1.map(BIOSText.fingerprint),
            .frames: poweredOn ? "\(Figures.grouped(framesRun)) of \(Self.framesToRun) frames" : nil,
            .shell: nil,
        ]
        let steps = Step.allCases.map { JobPresentation.Step($0.name, detail: details[$0] ?? nil) }
        var progress: JobPresentation.Progress?
        if state == .running(.frames) {
            progress = JobPresentation.Progress(
                .count(framesRun, of: Self.framesToRun), label: "Frames run",
                text: "\(Figures.grouped(framesRun)) of \(Self.framesToRun) frames"
            )
        }
        return JobPresentation(
            title: "Checking your BIOS", subtitle: fileName,
            steps: steps.reaching(current, as: stepState),
            progress: progress, summary: summary, output: output, actions: actions
        )
    }

    /// The line on what came of the check.
    private var summary: JobPresentation.Summary? {
        switch state {
        case .idle, .running: nil
        case .done: JobPresentation.Summary("Your BIOS works: it reached its shell.", tone: .ok)
        case .stopped: JobPresentation.Summary("Stopped. iStation didn’t keep this BIOS.", tone: .warning)
        case .failed(_, let failure):
            switch failure {
            case .unreadable:
                JobPresentation.Summary("The BIOS couldn’t be read. Choose another file.", tone: .danger)
            case .wrongSize(let bytes, _):
                JobPresentation.Summary(
                    "This file is \(BIOSText.bytes(bytes)). A PS1 BIOS is exactly \(BIOSText.bytes(BIOSText.biosSize)). Choose the BIOS file itself.",
                    tone: .danger
                )
            case .noShell:
                JobPresentation.Summary("Your BIOS powered on but didn’t reach its shell in \(Self.shellDeadline) frames. Choose another file.", tone: .danger)
            case .notKept:
                JobPresentation.Summary("Your BIOS reached its shell, but iStation couldn’t keep it. Choose the file again.", tone: .danger)
            }
        }
    }

    /// The exact call behind a refusal, under the summary.
    private var output: String? {
        guard case .failed(_, let failure) = state else { return nil }
        switch failure {
        case .unreadable(let details), .wrongSize(_, let details), .notKept(let details): return details
        case .noShell: return "PS1Console.reachedShell stayed false: the shell (0x80030000) wasn’t reached by frame \(Self.shellDeadline)"
        }
    }

    /// The sheet's buttons in each state.
    private var actions: [JobPresentation.Action] {
        switch state {
        case .idle: []
        case .running: [JobPresentation.Action("Stop", role: .stop)]
        case .done: [JobPresentation.Action("Continue", role: .finish)]
        case .failed: [JobPresentation.Action("Cancel", role: .close), JobPresentation.Action("Choose Another File…", role: .retry)]
        case .stopped: [JobPresentation.Action("Close", role: .close), JobPresentation.Action("Check Again", role: .retry)]
        }
    }

    /// What powering on with `bytes` bytes throws, as Details name it: the error the console's own size
    /// check throws for that size.
    static func powerOnRefusal(_ bytes: Int) -> String {
        BIOSText.threw("PS1Console.powerOn(bios:)", PS1Error.biosSize(bytes))
    }

    // MARK: - The check

    /// Runs check `run` of the file at `url`, step by step, until it is kept, refused or stopped.
    private func run(_ url: URL, _ run: Int) async {
        let storage = self.storage

        // Read the file: its bookmark and size, and its bytes only if the size is a BIOS's.
        let bookmark: Data
        do {
            bookmark = try await Task.detached { try storage.bookmark(for: url) }.value
        } catch {
            return fail(run, .read, .unreadable(details: BIOSText.threw("KeptFile.bookmark(for:)", error)))
        }
        guard isCurrent(run) else { return }
        var count: Int
        do {
            count = try await Task.detached { try storage.size(of: url) }.value
        } catch {
            return fail(run, .read, .unreadable(details: BIOSText.threw("KeptFile.size(at:)", error)))
        }
        guard isCurrent(run) else { return }
        size = count
        var bytes: [UInt8] = []
        if count == BIOSText.biosSize {
            do {
                bytes = try await Task.detached { try storage.bytes(of: url) }.value
            } catch {
                return fail(run, .read, .unreadable(details: BIOSText.threw("KeptFile.bytes(at:)", error)))
            }
            guard isCurrent(run) else { return }
            // The file may have changed since it was sized: the bytes read are what is checked.
            count = bytes.count
            size = count
        }

        // Check its size: a file of another size is refused with the error the console throws for it.
        state = .running(.size)
        guard count == BIOSText.biosSize else {
            return fail(run, .size, .wrongSize(bytes: count, details: Self.powerOnRefusal(count)))
        }

        // Work out its fingerprint, off the main actor.
        state = .running(.fingerprint)
        let image = bytes
        let sha1 = await Task.detached { Fingerprint.sha1(of: image) }.value
        guard isCurrent(run) else { return }
        self.sha1 = sha1

        // Power on and run 60 frames, on the check's own session.
        state = .running(.frames)
        do {
            try await session.powerOn(bios: bytes, exe: nil)
        } catch {
            return fail(run, .frames, .wrongSize(bytes: bytes.count, details: BIOSText.threw("PS1Console.powerOn(bios:)", error)))
        }
        guard isCurrent(run) else {
            // Stopped while powering on: the stop may have reached the session first.
            await session.stop()
            return
        }

        // Follow its frames: 60 first, then on until the shell or frame 600.
        for await snapshot in await session.snapshots() {
            guard isCurrent(run) else { return }
            frame = snapshot.frame
            guard snapshot.frame >= Self.framesToRun else { continue }
            if state == .running(.frames) { state = .running(.shell) }
            if snapshot.reachedShell {
                return await keep(run, url: url, bookmark: bookmark, size: bytes.count, sha1: sha1)
            }
            if snapshot.frame >= Self.shellDeadline {
                await session.stop()
                return fail(run, .shell, .noShell)
            }
        }
        // The session stopped under the check with no verdict: it ends where it was, keeping nothing.
        if isCurrent(run), case .running(let step) = state { state = .stopped(step) }
    }

    /// Releases the check's console and keeps the BIOS that reached its shell. The record is written
    /// without a suspension once the console is released, so a Stop can't land between the two.
    private func keep(_ run: Int, url: URL, bookmark: Data, size: Int, sha1: String) async {
        await session.stop()
        guard isCurrent(run) else { return }
        let checked = now().timeIntervalSinceReferenceDate.rounded(.down)
        let record = BIOSRecord(
            fileName: url.lastPathComponent, folder: url.deletingLastPathComponent().path, size: size,
            sha1: sha1, checked: Date(timeIntervalSinceReferenceDate: checked), bookmark: bookmark
        )
        do {
            try storage.keep(record)
        } catch {
            return fail(run, .shell, .notKept(details: BIOSText.threw("LibraryStore.keepBIOS(_:)", error)))
        }
        kept = record
        state = .done
    }

    /// Ends check `run` at `step` for `failure`, if it is still the current one.
    private func fail(_ run: Int, _ step: Step, _ failure: Failure) {
        guard isCurrent(run) else { return }
        state = .failed(step, failure)
    }

    /// Whether check `run` is still the current one.
    private func isCurrent(_ run: Int) -> Bool {
        run == generation && !Task.isCancelled
    }

    /// Stops the session after every stop sent before.
    private func sendStop() {
        let previous = stopping
        let session = self.session
        stopping = Task {
            await previous?.value
            await session.stop()
        }
    }

    /// Waits until the current check and every stop sent have finished; the tests' way to know.
    func settled() async {
        await work?.value
        await stopping?.value
    }
}
