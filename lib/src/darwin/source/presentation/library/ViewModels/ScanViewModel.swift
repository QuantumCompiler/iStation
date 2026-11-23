// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import DataLibrary
import Foundation
import Observation
import PresentationStyles

/// Add Folder…'s job, as the design's job sheet runs it (boards `Mac-ScanRunning`, `Mac-ScanStopped`,
/// `Mac-ScanDone`): find the games in the folder the person chose and its subfolders — every .cue, .iso,
/// .m3u and .exe file, one entry for an .m3u and its discs and none for the .bin tracks a .cue names —
/// then go through them one by one, adding each to the library as it is read, so the library shows it at
/// once. A game whose file the library keeps already is passed over, "Already in your library", so Scan
/// Again adds no game twice. Stop ends the scan where it is, keeping the games added so far.
///
/// At the Today level the read step reads what can be read before 5h: each file's bookmark and size, and
/// the tracks or discs a .cue or .m3u names (`GameFiles.record(for:added:)`); a disc's console and serial
/// wait for 5h. The chooser is `isChoosingFolder`, which the view binds the system's folder importer to;
/// the folder it gives comes back through `scan(_:)`, and its security-scoped access is held from the
/// search until the last file is recorded.
@MainActor
@Observable
public final class ScanViewModel {
    /// The scan's steps, in order, as the job sheet names them.
    public enum Step: Int, Sendable, CaseIterable {
        /// "Find disc images": the folder and its subfolders searched.
        case find
        /// "Read each disc": each file recorded and added, one by one.
        case read
        /// "Add them to your library": done as each is read, so it passes once the last is.
        case add

        /// The step's name in the job sheet.
        public var name: String {
            switch self {
            case .find: "Find disc images"
            case .read: "Read each disc"
            case .add: "Add them to your library"
            }
        }
    }

    /// Where the scan stands: each visibly different state of its sheet.
    public enum State: Equatable, Sendable {
        /// No scan: the sheet is closed.
        case idle
        /// The scan is on `Step`.
        case running(Step)
        /// Every file found has been gone through.
        case done
        /// The person stopped the scan at `Step`; the games added before it stay.
        case stopped(Step)
        /// The scan couldn't go on at `Step`: the folder couldn't be searched. `details` names the call.
        case failed(Step, details: String)
    }

    /// Where the scan stands.
    public private(set) var state: State = .idle
    /// Whether the system's folder chooser is open; the view binds `.fileImporter` to it, and the
    /// person's choice comes back through `scan(_:)`.
    public var isChoosingFolder = false
    /// The folder scanned, or last scanned: Scan Again's.
    public private(set) var folder: URL?
    /// The games found in it, in path order; nil until the search ends.
    public private(set) var found: [URL]?
    /// What became of each file gone through so far, in order.
    public private(set) var results: [JobPresentation.FileResult] = []
    /// The games this scan added to the library, in order.
    public private(set) var added: [GameRecord] = []

    private let storage: any LibraryStorage
    private let home: String?
    private let now: @Sendable () -> Date
    private let onChange: @MainActor (Library) -> Void

    /// Which scan is current: stopping or starting another moves it on, and a scan whose number has
    /// passed changes nothing more.
    @ObservationIgnored private var generation = 0
    /// The scan now running, or the last one.
    @ObservationIgnored private var work: Task<Void, Never>?

    /// A scan that reaches files and the library through `storage`, writes folders under `home` from
    /// "~", dates the games it adds by `now`, and hands the library to `onChange` each time a game joins
    /// it, so the library shows it at once.
    public init(
        storage: any LibraryStorage, home: String? = nil, now: @escaping @Sendable () -> Date = { Date() },
        onChange: @escaping @MainActor (Library) -> Void = { _ in }
    ) {
        self.storage = storage
        self.home = home
        self.now = now
        self.onChange = onChange
    }

    deinit {
        work?.cancel()
    }

    // MARK: - Intents

    /// Opens the folder chooser: Add Folder…, ⇧⌘O. Nothing while the scan's sheet shows.
    public func chooseFolder() {
        guard canChooseFolder else { return }
        isChoosingFolder = true
    }

    /// Scans `folder`, the one the person chose. Nothing while a scan runs.
    public func scan(_ folder: URL) {
        guard !isRunning else { return }
        isChoosingFolder = false
        start(folder)
    }

    /// Scans the same folder again from the start, passing over the games added already: Scan Again.
    /// Nothing while a scan runs, or before any.
    public func scanAgain() {
        guard !isRunning, let folder else { return }
        start(folder)
    }

    /// Stops the running scan where it is: the games added stay, the file being read isn't added. Stop,
    /// ⌘. and Escape while it runs.
    public func stop() {
        guard case .running(let step) = state else { return }
        generation += 1
        work?.cancel()
        state = .stopped(step)
    }

    /// Closes a scan that has ended: Done. Nothing while one runs.
    public func close() {
        guard !isRunning else { return }
        state = .idle
    }

    /// Does what the job sheet's button `action` says.
    public func perform(_ action: JobPresentation.Action) {
        switch action.role {
        case .stop: stop()
        case .close, .finish: close()
        case .retry: scanAgain()
        }
    }

    /// The sheet was closed without a button: a running scan stops, as the design's Escape stops it;
    /// an ended one closes.
    public func dismiss() {
        if isRunning { stop() } else { close() }
    }

    // MARK: - What the sheet shows

    /// Whether a scan is under way.
    public var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    /// Whether the job sheet shows. It reads only the state, which changes once a step, so the sheet's
    /// presenter and the menus aren't redrawn for each file.
    public var isShowingJob: Bool { state != .idle }

    /// Whether Add Folder… can open the chooser now: no scan's sheet shows.
    public var canChooseFolder: Bool { state == .idle }

    /// How many files the search found; 0 until it ends.
    public var total: Int { found?.count ?? 0 }

    /// The job sheet's contents; nil while no scan shows.
    public var job: JobPresentation? {
        let current: Int
        let stepState: JobPresentation.StepState
        switch state {
        case .idle: return nil
        case .running(let step): (current, stepState) = (step.rawValue, .running)
        case .done: (current, stepState) = (Step.allCases.count, .done)
        case .stopped(let step): (current, stepState) = (step.rawValue, .stopped)
        case .failed(let step, _): (current, stepState) = (step.rawValue, .failed)
        }
        let read = results.count
        let details: [Step: String?] = [
            .find: found == nil ? "Looking for .cue, .iso, .m3u and .exe files" : "\(Figures.grouped(total)) found",
            // Before 5h the read step reads no SYSTEM.CNF, so it doesn't say it will.
            .read: found == nil ? nil : "\(Figures.grouped(min(read, total))) of \(Figures.grouped(total))",
            .add: nil,
        ]
        let steps = Step.allCases.map { JobPresentation.Step($0.name, detail: details[$0] ?? nil) }
        var progress: JobPresentation.Progress?
        if state == .running(.read), let found, !found.isEmpty {
            let next = found[min(read, found.count - 1)]
            progress = JobPresentation.Progress(
                .count(read, of: found.count), label: "Discs read",
                text: "Reading \(Figures.grouped(min(read + 1, found.count))) of \(Figures.grouped(found.count)) · \(relative(next))"
            )
        }
        return JobPresentation(
            title: "Adding games from " + shownFolder, steps: steps.reaching(current, as: stepState),
            progress: progress, summary: summary, results: results, output: output, actions: actions
        )
    }

    /// The scanned folder as the sheet's title names it, from "~" under the home folder: "~/Games".
    var shownFolder: String {
        guard let folder else { return "" }
        return Folders.shown(GameRecord.standardizedPath(of: folder), home: home)
    }

    /// The line on what came of the scan.
    private var summary: JobPresentation.Summary? {
        switch state {
        case .idle, .running: return nil
        case .done: return JobPresentation.Summary(tally, tone: .ok)
        case .stopped:
            let read = results.count
            guard read > 0 else {
                return JobPresentation.Summary("Stopped before reading any disc. Scan Again starts over.", tone: .warning)
            }
            return JobPresentation.Summary(
                "Stopped after \(Figures.grouped(read)) of \(Figures.grouped(total)). \(tally) Scan Again skips the games already added.",
                tone: .warning
            )
        case .failed: return JobPresentation.Summary("iStation couldn’t open this folder.", tone: .danger)
        }
    }

    /// What came of the files gone through, as the design tallies them: "Added 3 games. 2 already in
    /// your library. 1 couldn’t be added.", or "Nothing added yet.".
    private var tally: String {
        let added = results.count { $0.outcome == .added }
        let skipped = results.count { $0.outcome == .skipped }
        let failed = results.count { $0.outcome == .failed }
        var parts: [String] = []
        if added > 0 { parts.append("Added \(Figures.grouped(added)) " + (added == 1 ? "game." : "games.")) }
        if skipped > 0 { parts.append("\(Figures.grouped(skipped)) already in your library.") }
        if failed > 0 { parts.append("\(Figures.grouped(failed)) couldn’t be added.") }
        return parts.isEmpty ? "Nothing added yet." : parts.joined(separator: " ")
    }

    /// The exact call behind a scan that couldn't go on.
    private var output: String? {
        guard case .failed(_, let details) = state else { return nil }
        return details
    }

    /// The sheet's buttons in each state.
    private var actions: [JobPresentation.Action] {
        switch state {
        case .idle: []
        case .running: [JobPresentation.Action("Stop", role: .stop)]
        case .done: [JobPresentation.Action("Done", role: .finish)]
        case .stopped, .failed: [JobPresentation.Action("Done", role: .close), JobPresentation.Action("Scan Again", role: .retry)]
        }
    }

    // MARK: - The scan

    /// Starts scanning `folder` afresh, once the scan before it has finished.
    private func start(_ folder: URL) {
        generation += 1
        let run = generation
        self.folder = folder
        found = nil
        results = []
        added = []
        state = .running(.find)
        let previous = work
        work = Task { [weak self] in
            await previous?.value
            await self?.run(folder, run)
        }
    }

    /// Runs scan `run` of `folder`, step by step, until every file is gone through, or it is stopped.
    private func run(_ folder: URL, _ run: Int) async {
        let storage = self.storage
        // The folder's files are reached through its access: held until the last is recorded.
        let accessing = storage.startAccessing(folder)
        defer { if accessing { storage.stopAccessing(folder) } }

        // Find disc images, off the main actor; a Stop cancels the search, which ends early.
        let search = Task.detached { () -> Result<[URL], any Error> in
            Result { try storage.games(in: folder) }
        }
        let searched = await withTaskCancellationHandler {
            await search.value
        } onCancel: {
            search.cancel()
        }
        guard isCurrent(run) else { return }
        let urls: [URL]
        switch searched {
        case .success(let value): urls = value
        case .failure(let error):
            state = .failed(.find, details: Details.threw("GameFiles.find(in:)", error))
            return
        }
        found = urls

        // Read each disc: record it off the main actor, then add it to the library here, one at a time.
        state = .running(.read)
        var library = (try? storage.library()) ?? Library()
        for url in urls {
            guard isCurrent(run) else { return }
            let file = relative(url)
            if library.game(at: url) != nil {
                results.append(JobPresentation.FileResult(file, outcome: .skipped, note: "Already in your library"))
                continue
            }
            let date = now()
            // Linked to the scan, so a Stop reaches a record that can hear it: a preview's held one.
            let recording = Task.detached { () async -> Result<GameRecord, any Error> in
                do {
                    return .success(try await storage.record(for: url, added: date))
                } catch {
                    return .failure(error)
                }
            }
            let recorded = await withTaskCancellationHandler { await recording.value } onCancel: { recording.cancel() }
            // Stopped while the file was read: it isn't added, and the scan ends where it was.
            guard isCurrent(run) else { return }
            let record: GameRecord
            switch recorded {
            case .success(let value): record = value
            case .failure(let error):
                results.append(JobPresentation.FileResult(file, outcome: .failed, note: "iStation couldn’t open this file.", code: Self.code(error)))
                continue
            }
            do {
                let change = try storage.addGames([record])
                library = change.library
                onChange(change.library)
                if let game = change.added.first {
                    added.append(game)
                    results.append(JobPresentation.FileResult(file, outcome: .added, note: "Added · " + Self.note(game)))
                } else {
                    results.append(JobPresentation.FileResult(file, outcome: .skipped, note: "Already in your library"))
                }
            } catch {
                results.append(JobPresentation.FileResult(
                    file, outcome: .failed, note: "iStation couldn’t add this game to your library.", code: Self.code(error)
                ))
            }
        }
        guard isCurrent(run) else { return }
        // Each game was added as it was read, so the last step passes with the last file.
        state = .done
    }

    /// Whether scan `run` is still the current one.
    private func isCurrent(_ run: Int) -> Bool {
        run == generation && !Task.isCancelled
    }

    /// `url`'s path below the scanned folder, as the results list it: "PS1/Tidepool/Tidepool.m3u".
    private func relative(_ url: URL) -> String {
        let path = GameRecord.standardizedPath(of: url)
        guard let folder else { return path }
        let base = GameRecord.standardizedPath(of: folder)
        let prefix = base.hasSuffix("/") ? base : base + "/"
        return path.hasPrefix(prefix) ? String(path.dropFirst(prefix.count)) : path
    }

    /// What an added game's result says after "Added · ", at the Today level: its format as the table's
    /// Format column writes it — ".cue", ".iso", ".m3u" — and for a PS-EXE "PS-EXE · no serial", as the
    /// design's scan does; a disc's console and serial wait for 5h.
    static func note(_ game: GameRecord) -> String {
        game.format == .psexe ? "PS-EXE · no serial" : LibraryText.formatCell(game.format)
    }

    /// The error a failed file's result shows in monospaced type, as the design shows "DiscError.truncated":
    /// its type and case, without the case's values.
    static func code(_ error: any Error) -> String {
        let described = String(describing: error)
        guard Mirror(reflecting: error).displayStyle == .enum else { return described }
        let name = described.prefix { $0 != "(" }
        return "\(String(describing: type(of: error))).\(name)"
    }

    /// Waits until the current scan has finished; the tests' way to know.
    func settled() async {
        await work?.value
    }
}
