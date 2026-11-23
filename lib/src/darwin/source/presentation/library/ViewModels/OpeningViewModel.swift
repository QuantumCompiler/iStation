// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessPS1
import BusinessSession
import DataLibrary
import Foundation
import Observation
import PresentationStyles

/// A PS-EXE's opening job, as the design's opening sheet runs it at the Today level (the "today" flow's
/// three steps): open the file — read it and recognize it as a PS-EXE (`PSEXE(bytes:)`) — then power the
/// player's session on with the BIOS the library keeps and the program, which the session gives to
/// `boot(exe:)` before the first frame, then start the program once the BIOS reaches its shell: the
/// session's snapshots are followed until `bootIsPending` clears. The run is then handed to `onRun` as a
/// `GameRun`, which the app gives the player as its run, and the game is noted as played. A BIOS that
/// hasn't reached its shell by frame 600 is given up on, as the BIOS check gives up on one. Cancel ends
/// the job and stops the session if it was powered on. A disc isn't opened: discs play from v0.2.0 (5i).
@MainActor
@Observable
public final class OpeningViewModel {
    /// The job's steps, in order, as the sheet names them.
    public enum Step: Int, Sendable, CaseIterable {
        /// "Open the file": the program found by its bookmark, sized, read and recognized.
        case open
        /// "Power on with your BIOS": the kept BIOS read, and the player's session powered on with it and the program.
        case powerOn
        /// "Start the program": once the BIOS reaches its shell, the program starts in its place.
        case start

        /// The step's name in the job sheet.
        public var name: String {
            switch self {
            case .open: "Open the file"
            case .powerOn: "Power on with your BIOS"
            case .start: "Start the program"
            }
        }
    }

    /// Why a game couldn't be opened. `details` names the call that failed and what it threw.
    public enum Failure: Error, Equatable, Sendable {
        /// The program's file can't be found where the library keeps it.
        case missing(details: String)
        /// The file was found but couldn't be sized or read.
        case unreadable(details: String)
        /// The file isn't a PS-EXE: too short, without its header, or too big for the console's memory.
        case notAProgram(details: String)
        /// The library keeps no BIOS to power on with, or couldn't be read (`details` then says why).
        case noBIOS(details: String?)
        /// The kept BIOS, `name`, can't be found or read where it is kept.
        case biosUnreadable(name: String, details: String)
        /// The kept BIOS, `name`, is now `bytes` long, not a BIOS's 524,288.
        case biosWrongSize(name: String, bytes: Int, details: String)
        /// The BIOS powered on but hadn't reached its shell by frame 600, so the program never started.
        case noShell
    }

    /// Where the job stands: each visibly different state of its sheet. A job handed on, or cancelled, is idle.
    public enum State: Equatable, Sendable {
        /// No job: the sheet is closed.
        case idle
        /// The job is on `Step`.
        case running(Step)
        /// The job ended at `Step`, for `Failure`, and nothing was handed on.
        case failed(Step, Failure)
    }

    /// The frame by which the BIOS must have reached its shell for the program to start, as the BIOS check has it.
    public static let shellDeadline = 600
    /// The largest file that can be a PS-EXE: its 2 KB header and the console's 2 MB of memory. A bigger
    /// file is refused before it is read, so a disc image named .exe by mistake is never read whole.
    public nonisolated static var largestProgram: Int { PSEXE.headerSize + PS1Bus.ramSize }

    /// Where the job stands.
    public private(set) var state: State = .idle
    /// The game being opened, or last opened.
    public private(set) var game: GameRecord?
    /// The BIOS file's name, as the second step names it: the library's record, then the file read.
    public private(set) var biosFileName = ""
    /// Whether a stop Cancel sent is still on its way to the session: until it lands, the console the
    /// cancelled job powered on may still be running, though nothing was handed on.
    public var isStopping: Bool { stopsUnderWay > 0 }
    /// How many stops Cancel sent haven't reached the session yet.
    private var stopsUnderWay = 0

    private let storage: any LibraryStorage
    private let session: any ConsoleSessionPowerControls
    private let now: @Sendable () -> Date
    private let onRun: @MainActor (GameRun) -> Void
    private let onPlayed: @MainActor (Library) -> Void
    private let onBIOSMoved: @MainActor (BIOSRecord) -> Void

    /// Which job is current: cancelling or opening another moves it on, and a job whose number has
    /// passed changes nothing more.
    @ObservationIgnored private var generation = 0
    /// The job whose run may have powered the session on: Cancel stops the session for it.
    @ObservationIgnored private var poweringOn = 0
    /// The job now running, or the last one.
    @ObservationIgnored private var work: Task<Void, Never>?
    /// The last stop sent to the session.
    @ObservationIgnored private var stopping: Task<Void, Never>?

    /// An opening job that reads files and the library through `storage`, powers on `session`, the
    /// player's, and hands the run to `onRun`; then notes the game played at `now` and gives the library
    /// to `onPlayed`. A BIOS found somewhere else is kept again there and given to `onBIOSMoved`, so the
    /// BIOS pane shows where it is now.
    public init(
        storage: any LibraryStorage, session: any ConsoleSessionPowerControls,
        now: @escaping @Sendable () -> Date = { Date() },
        onRun: @escaping @MainActor (GameRun) -> Void,
        onPlayed: @escaping @MainActor (Library) -> Void = { _ in },
        onBIOSMoved: @escaping @MainActor (BIOSRecord) -> Void = { _ in }
    ) {
        self.storage = storage
        self.session = session
        self.now = now
        self.onRun = onRun
        self.onPlayed = onPlayed
        self.onBIOSMoved = onBIOSMoved
    }

    deinit {
        work?.cancel()
    }

    // MARK: - Intents

    /// Opens `game`, a PS-EXE: Play, Return and a double-click. Nothing for a disc, or while a job's
    /// sheet shows.
    public func open(_ game: GameRecord) {
        guard !isShowingJob, game.format == .psexe else { return }
        generation += 1
        let run = generation
        self.game = game
        biosFileName = (try? storage.library())?.bios?.fileName ?? ""
        state = .running(.open)
        // A job after another starts once the one before has finished and its stop has reached the
        // session, so nothing of it can stop this one's console.
        let previous = work
        let previousStop = stopping
        work = Task { [weak self] in
            await previous?.value
            await previousStop?.value
            await self?.run(game, run)
        }
    }

    /// Cancels the running job, as the design's Cancel closes the sheet: the session is stopped if it
    /// was powered on, and nothing is handed on. Cancel, ⌘. and Escape while it runs.
    public func cancel() {
        guard isRunning else { return }
        let mayBePoweredOn = poweringOn == generation
        generation += 1
        work?.cancel()
        state = .idle
        if mayBePoweredOn { sendStop() }
    }

    /// Closes a job that failed: Close. Nothing while one runs.
    public func close() {
        guard case .failed = state else { return }
        state = .idle
    }

    /// Does what the job sheet's button `action` says.
    public func perform(_ action: JobPresentation.Action) {
        switch action.role {
        case .stop: cancel()
        case .close, .finish, .retry: close()
        }
    }

    /// The sheet was closed without a button: a running job is cancelled, a failed one closes.
    public func dismiss() {
        if isRunning { cancel() } else { close() }
    }

    // MARK: - What the sheet shows

    /// Whether a job is under way.
    public var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    /// Whether the job sheet shows.
    public var isShowingJob: Bool { state != .idle }

    /// The job sheet's contents; nil while no job shows.
    public var job: JobPresentation? {
        guard let game else { return nil }
        let current: Int
        let stepState: JobPresentation.StepState
        switch state {
        case .idle: return nil
        case .running(let step): (current, stepState) = (step.rawValue, .running)
        case .failed(let step, _): (current, stepState) = (step.rawValue, .failed)
        }
        let details: [Step: String?] = [
            .open: game.fileName,
            .powerOn: biosFileName.isEmpty ? nil : biosFileName,
            .start: "Once the BIOS reaches its shell",
        ]
        let steps = Step.allCases.map { JobPresentation.Step($0.name, detail: details[$0] ?? nil) }
        return JobPresentation(
            title: "Opening " + game.shownName, steps: steps.reaching(current, as: stepState),
            summary: summary, output: output, actions: actions
        )
    }

    /// The line on why the job failed.
    private var summary: JobPresentation.Summary? {
        guard case .failed(_, let failure) = state else { return nil }
        let text = switch failure {
        case .missing: "iStation can’t find this file. It may have been moved, renamed or deleted."
        case .unreadable: "iStation couldn’t open this file."
        case .notAProgram: "This file isn’t a PS-EXE program, so iStation can’t start it."
        case .noBIOS: "iStation has no BIOS to power on with. Choose your BIOS file first."
        case .biosUnreadable(let name, _): "iStation couldn’t open \(name) where you keep it. Put it back, or choose it again."
        case .biosWrongSize(let name, let bytes, _):
            "\(name) is now \(Figures.grouped(bytes)) bytes. A PS1 BIOS is exactly \(Figures.grouped(PS1Bus.biosSize)) bytes. Choose the BIOS file itself."
        case .noShell: "Your BIOS didn’t reach its shell in \(Self.shellDeadline) frames, so the program didn’t start."
        }
        return JobPresentation.Summary(text, tone: .danger)
    }

    /// The exact call behind a failure, under the summary.
    private var output: String? {
        guard case .failed(_, let failure) = state else { return nil }
        switch failure {
        case .missing(let details), .unreadable(let details), .notAProgram(let details),
             .biosUnreadable(_, let details), .biosWrongSize(_, _, let details):
            return details
        case .noBIOS(let details): return details
        case .noShell:
            return "PS1Console.bootIsPending stayed true: the shell (0x80030000) wasn’t reached by frame \(Self.shellDeadline)"
        }
    }

    /// The sheet's buttons: Cancel while it runs, as the design has it, and Close once it fails.
    private var actions: [JobPresentation.Action] {
        switch state {
        case .idle: []
        case .running: [JobPresentation.Action("Cancel", role: .stop)]
        case .failed: [JobPresentation.Action("Close", role: .close)]
        }
    }

    // MARK: - The job

    /// Runs job `run` of `game`, step by step, until the run is handed on, the job fails or is cancelled.
    private func run(_ game: GameRecord, _ run: Int) async {
        let storage = self.storage

        // Open the file: found, sized, read and recognized, off the main actor.
        let opened = await Task.detached { Self.readProgram(game, from: storage) }.value
        guard isCurrent(run) else { return }
        let program: PSEXE
        switch opened {
        case .success(let value): program = value
        case .failure(let failure): return fail(run, .open, failure)
        }

        // Power on with your BIOS: the library's own reading of it, off the main actor.
        state = .running(.powerOn)
        let record: BIOSRecord
        do {
            guard let kept = try storage.library().bios else { return fail(run, .powerOn, .noBIOS(details: nil)) }
            record = kept
        } catch {
            return fail(run, .powerOn, .noBIOS(details: Details.threw("LibraryStore.load()", error)))
        }
        biosFileName = record.fileName
        let name = record.fileName.isEmpty ? "your BIOS" : record.fileName
        let expectedSize = PS1Bus.biosSize
        let read = await Task.detached {
            Result { () throws(KeptBIOSError) -> KeptBIOS in try storage.readBIOS(record, expectedSize: expectedSize) }
        }.value
        guard isCurrent(run) else { return }
        let bios: KeptBIOS
        switch read {
        case .success(let value):
            bios = value
        case .failure(.cannotFind(let error)):
            return fail(run, .powerOn, .biosUnreadable(name: name, details: Details.threw("KeptFile.resolve(_:)", error)))
        case .failure(.cannotSize(let error)):
            return fail(run, .powerOn, .biosUnreadable(name: name, details: Details.threw("KeptFile.size(at:)", error)))
        case .failure(.wrongSize(let size)):
            return fail(run, .powerOn, .biosWrongSize(
                name: name, bytes: size, details: Details.threw("PS1Console.powerOn(bios:)", PS1Error.biosSize(size))
            ))
        case .failure(.cannotRead(let error)):
            return fail(run, .powerOn, .biosUnreadable(name: name, details: Details.threw("KeptFile.bytes(at:)", error)))
        }
        if bios.isStale { keepAgain(record, at: bios.url) }
        biosFileName = bios.url.lastPathComponent
        poweringOn = run
        do {
            try await session.powerOn(bios: bios.bytes, exe: program)
        } catch {
            return fail(run, .powerOn, .biosWrongSize(
                name: name, bytes: bios.bytes.count, details: Details.threw("PS1Console.powerOn(bios:)", error)
            ))
        }
        guard isCurrent(run) else {
            // Cancelled while powering on: the stop may have reached the session first.
            stopsUnderWay += 1
            await session.stop()
            stopsUnderWay -= 1
            return
        }

        // Start the program: follow the session until the BIOS reaches its shell and the boot is done.
        state = .running(.start)
        for await snapshot in await session.snapshots() {
            guard isCurrent(run) else { return }
            if snapshot.state == .stopped || snapshot.state == .poweredOff { break }
            if !snapshot.bootIsPending {
                return handOff(game, bios: bios)
            }
            if snapshot.frame >= Self.shellDeadline {
                await session.stop()
                return fail(run, .start, .noShell)
            }
        }
        // The session stopped under the job before the program started: it ends, handing nothing on.
        if isCurrent(run) { state = .idle }
    }

    /// Closes the sheet, hands the run on for the player, and notes the game played.
    private func handOff(_ game: GameRecord, bios: KeptBIOS) {
        state = .idle
        onRun(GameRun(
            biosFileName: bios.url.lastPathComponent, biosSize: bios.bytes.count, name: game.shownName, fileName: game.fileName
        ))
        // The run is what matters: a library that can't note it played says so at its next change.
        if let library = try? storage.markPlayed(game.id, at: now()) { onPlayed(library) }
    }

    /// The program in `game`'s file: found by its bookmark, sized without reading — a file too big to be
    /// a PS-EXE is refused unread — then read and recognized.
    nonisolated static func readProgram(_ game: GameRecord, from storage: any LibraryStorage) -> Result<PSEXE, Failure> {
        let url: URL
        do {
            url = try storage.resolve(game.bookmark).url
        } catch {
            return .failure(.missing(details: Details.threw("KeptFile.resolve(_:)", error)))
        }
        let size: Int
        do {
            size = try storage.size(of: url)
        } catch {
            return .failure(.unreadable(details: Details.threw("KeptFile.size(at:)", error)))
        }
        guard size <= largestProgram else {
            return .failure(.notAProgram(details:
                "PSEXE(bytes:) wasn’t called: the file is \(Figures.grouped(size)) bytes, more than a PS-EXE’s \(Figures.grouped(largestProgram))"
            ))
        }
        let bytes: [UInt8]
        do {
            bytes = try storage.bytes(of: url)
        } catch {
            return .failure(.unreadable(details: Details.threw("KeptFile.bytes(at:)", error)))
        }
        do {
            return .success(try PSEXE(bytes: bytes))
        } catch {
            return .failure(.notAProgram(details: Details.threw("PSEXE(bytes:)", error)))
        }
    }

    /// Keeps `record` again by a new bookmark to the file where it is now, as Run the BIOS does, and
    /// tells `onBIOSMoved`. Left as it was if either can't be made.
    private func keepAgain(_ record: BIOSRecord, at url: URL) {
        guard let bookmark = try? storage.bookmark(for: url) else { return }
        let moved = record.moved(to: url, bookmark: bookmark)
        guard (try? storage.keepBIOS(moved)) != nil else { return }
        onBIOSMoved(moved)
    }

    /// Ends job `run` at `step` for `failure`, if it is still the current one.
    private func fail(_ run: Int, _ step: Step, _ failure: Failure) {
        guard isCurrent(run) else { return }
        state = .failed(step, failure)
    }

    /// Whether job `run` is still the current one.
    private func isCurrent(_ run: Int) -> Bool {
        run == generation && !Task.isCancelled
    }

    /// Stops the session after every stop sent before; `isStopping` until it has.
    private func sendStop() {
        let previous = stopping
        let session = self.session
        stopsUnderWay += 1
        stopping = Task { [weak self] in
            await previous?.value
            await session.stop()
            self?.stopsUnderWay -= 1
        }
    }

    /// Waits until the current job and every stop sent have finished; the tests' way to know.
    func settled() async {
        await work?.value
        await stopping?.value
    }
}
