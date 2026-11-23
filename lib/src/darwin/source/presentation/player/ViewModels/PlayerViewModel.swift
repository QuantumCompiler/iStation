// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessPS1
import BusinessSession
import Observation
import PresentationStyles

/// The player: what the console session is doing, as the screen, its toolbar and the Game menu show
/// it, and what a person can do to it — pause, resume, reset, stop, full screen.
///
/// The player doesn't power the console on: whatever starts a run (5c's Run the BIOS, 5d's opening job)
/// powers the session on and calls `started(_:)` with the files it used, and from then on the player
/// follows the session's snapshots, here on the main actor. Reset and Stop ask first, as the
/// design does: asking pauses a running game, and the alert's Details name the exact call.
@MainActor
@Observable
public final class PlayerViewModel {
    /// Each visibly different state of the player.
    public enum State: Equatable, Sendable {
        /// No BIOS or game has been chosen, and the console has nothing to run.
        case nothingLoaded
        /// The console runs frames; until 6b and 5g there is no picture, so the screen counts them.
        case running
        /// The console holds its frame until the person resumes.
        case paused
        /// The run has ended and the console is released: nothing runs until something starts again.
        case stopped
    }

    /// Which question is open, Reset's or Stop's.
    public enum Confirmation: Equatable, Sendable {
        /// "Reset the console?"
        case reset
        /// "Stop the BIOS?" or "Stop playing …?"
        case stop
    }

    /// What the screen shows.
    public private(set) var state: State = .nothingLoaded
    /// What the run plays, as its starter told the player; nil until a run starts.
    public private(set) var run: PlayerRun?
    /// Frames the console has run since power-on, as the session last reported.
    public private(set) var frame = 0
    /// Frames run over the last whole second of running, as the session measured them; 0 until a
    /// second has run, and while paused.
    public private(set) var framesPerSecond: Double = 0
    /// Whether the player fills the screen, its toolbar hidden and its HUD carrying the controls.
    public private(set) var isFullScreen = false
    /// The question Reset or Stop is asking, while its alert is open.
    public private(set) var confirmation: Confirmation?

    private let session: any ConsoleSessionControls
    /// The task following the session's snapshots for the current run.
    @ObservationIgnored private var following: Task<Void, Never>?
    /// The last control sent: each waits for the one before, so they reach the session in order.
    @ObservationIgnored private var commands: Task<Void, Never>?

    /// A player for `session`, with nothing loaded until a run starts.
    public init(session: any ConsoleSessionControls) {
        self.session = session
    }

    deinit {
        // The follow holds the session, and a paused session sends no snapshot that would end it, so a
        // player let go stops following and its session can go too.
        following?.cancel()
    }

    // MARK: - Starting

    /// Tells the player a run has started, or is about to: the session is powered on with `run`'s BIOS
    /// and, for a PS-EXE, booted with its program. From here on the player follows the session's
    /// snapshots, across a stop too: a stop finishes every snapshot stream, so the player then takes the
    /// session's next one and shows whatever powers on after it. Called by whatever starts the console
    /// once it has powered the session on — Run the BIOS right after, the library's opening job once the
    /// program has booted — or just before; a run started while another plays replaces it, whether the
    /// starter stops the old run first or not.
    public func started(_ run: PlayerRun) {
        self.run = run
        confirmation = nil
        following?.cancel()
        let session = self.session
        following = Task { [weak self] in
            while !Task.isCancelled {
                for await snapshot in await session.snapshots() {
                    guard let self, !Task.isCancelled else { return }
                    self.show(snapshot)
                }
                // The stream finished. A stop finishes it after its stopped snapshot: follow the next
                // stream, so a power-on after the stop is seen. Otherwise the session has gone.
                guard let self, self.state == .stopped else { return }
            }
        }
    }

    /// Shows what `snapshot` says the session is doing. A run that ends closes any open question and
    /// leaves full screen.
    func show(_ snapshot: ConsoleSessionSnapshot) {
        let wasPlaying = isPlaying
        let state = State(snapshot.state)
        // A snapshot arrives every frame: only what changed is set, so only what reads it redraws.
        if self.state != state { self.state = state }
        if frame != snapshot.frame { frame = snapshot.frame }
        if framesPerSecond != snapshot.framesPerSecond { framesPerSecond = snapshot.framesPerSecond }
        if !isPlaying {
            confirmation = nil
            if wasPlaying { isFullScreen = false }
        }
    }

    // MARK: - Intents

    /// Holds the frame. Only while running, with no question open.
    public func pause() {
        guard canPause else { return }
        send { await $0.pause() }
    }

    /// Runs frames again from the held frame. Only while paused, with no question open.
    public func resume() {
        guard canResume else { return }
        send { await $0.resume() }
    }

    /// Pauses a running game or resumes a paused one: ⌘P, and the Pause or Resume button.
    public func togglePause() {
        if state == .paused { resume() } else { pause() }
    }

    /// Asks before resetting, pausing a running game while the alert is open. Only while playing.
    public func askToReset() {
        ask(.reset)
    }

    /// Asks before stopping, pausing a running game while the alert is open. Only while playing.
    public func askToStop() {
        ask(.stop)
    }

    /// Goes ahead with the open question: Reset powers the console on again and runs it from frame 0,
    /// booting the same PS-EXE; Stop ends the run loop and releases the console, saving nothing.
    public func confirm() {
        guard let confirmation else { return }
        self.confirmation = nil
        switch confirmation {
        case .reset: send { await $0.reset() }
        case .stop: send { await $0.stop() }
        }
    }

    /// Closes the open question and changes nothing: a game the question paused stays paused, as the
    /// design has it.
    public func cancel() {
        confirmation = nil
    }

    /// Enters or leaves full screen: ⌃⌘F, and the Full screen button. Only while playing, or to leave.
    public func toggleFullScreen() {
        guard canToggleFullScreen else { return }
        isFullScreen.toggle()
    }

    /// Leaves full screen: Esc, and the HUD's Exit full screen button.
    public func exitFullScreen() {
        isFullScreen = false
    }

    /// Follows the window into or out of full screen when the system takes it there — its green
    /// button, the View menu — so the player's look and its menus agree with the window.
    public func fullScreenDidChange(_ isFullScreen: Bool) {
        self.isFullScreen = isFullScreen
    }

    // MARK: - What the screen shows

    /// The console's name.
    public var consoleName: String { PS1Console.name }

    /// What the screen says in the current state: what's happening while nothing plays, and why
    /// there's no picture while the console runs.
    public var message: String {
        switch state {
        case .nothingLoaded: "Nothing to play yet."
        case .running, .paused: "This build runs the console but can’t show its picture yet."
        case .stopped: "Stopped. Nothing is running."
        }
    }

    /// Whether a run is under way, running or paused: the HUD and the frame count show.
    public var isPlaying: Bool { state == .running || state == .paused }

    /// Whether the paused overlay with Resume shows: while paused, unless an alert stands in for it.
    public var showsPausedOverlay: Bool { state == .paused && confirmation == nil }

    /// What the HUD names: the program's name, or "BIOS" while the BIOS runs alone.
    public var name: String { run?.program?.name ?? "BIOS" }

    /// The window's title while a run plays, as the design's toolbar names it: the program's name, or
    /// "BIOS". Nil while nothing plays, when the window keeps the app's own title.
    public var windowTitle: String? { isPlaying ? name : nil }

    /// The HUD's status chip while playing: "Running" or "Paused".
    public var statusText: String { state == .paused ? "Paused" : "Running" }

    /// The frame count, grouped by thousands: "1,234".
    public var frameText: String { Figures.grouped(frame) }

    /// The HUD's frame counter: "Frame 1,234".
    public var hudFrameText: String { "Frame " + frameText }

    /// The frames per second as the HUD shows them at the Today level: "60 per second" while running,
    /// "paused" while paused; nil before the session has measured a whole second, and while nothing plays.
    public var framesPerSecondText: String? {
        switch state {
        case .running: measuredRate.map { "\($0) per second" }
        case .paused: "paused"
        case .nothingLoaded, .stopped: nil
        }
    }

    /// The line under the "No picture yet" panel's frame count: "frames run · 60 per second".
    public var framesRunCaption: String {
        framesPerSecondText.map { "frames run · \($0)" } ?? "frames run"
    }

    /// The window's subtitle while playing: "Running · frame 1,234 · 60 frames a second", or
    /// "Paused · frame 1,234"; empty while nothing plays.
    public var statusLine: String {
        guard isPlaying else { return "" }
        var parts = [statusText, "frame " + frameText]
        if state == .running, let rate = measuredRate { parts.append("\(rate) frames a second") }
        return parts.joined(separator: " · ")
    }

    /// The open question's alert, its Details naming the run's own files; nil while none is open.
    public var alert: PlayerAlert? {
        guard let confirmation, let run else { return nil }
        switch confirmation {
        case .reset:
            let boot = run.program.map { "\nthen boot(exe:) with \($0.fileName)" } ?? ""
            return PlayerAlert(
                title: "Reset the console?",
                message: (run.program == nil ? "The game" : "The program") + " starts again from the beginning. Anything you haven’t saved is lost.",
                details: "PS1Console.powerOn(bios:) with \(run.biosFileName) (\(Figures.grouped(run.biosSize)) bytes)" + boot,
                confirmTitle: "Reset"
            )
        case .stop:
            return PlayerAlert(
                title: run.program.map { "Stop playing \($0.name)?" } ?? "Stop the BIOS?",
                message: "Anything you haven’t saved is lost.",
                details: "Ends the console’s run loop and releases it. The disc image and your BIOS aren’t changed.",
                confirmTitle: "Stop"
            )
        }
    }

    // MARK: - Which controls apply

    /// Whether Pause applies: running, with no question open.
    public var canPause: Bool { state == .running && confirmation == nil }

    /// Whether Resume applies: paused, with no question open.
    public var canResume: Bool { state == .paused && confirmation == nil }

    /// Whether the Pause or Resume command applies.
    public var canTogglePause: Bool { canPause || canResume }

    /// The Pause or Resume command's title: "Resume" while paused, "Pause" otherwise.
    public var pauseTitle: String { state == .paused ? "Resume" : "Pause" }

    /// Whether Reset applies: playing, with no question open.
    public var canReset: Bool { isPlaying && confirmation == nil }

    /// Whether Stop applies: playing, with no question open.
    public var canStop: Bool { isPlaying && confirmation == nil }

    /// Whether the full-screen command applies: playing, or full screen already and able to leave,
    /// with no question open.
    public var canToggleFullScreen: Bool { confirmation == nil && (isPlaying || isFullScreen) }

    /// The full-screen command's title in the Game menu.
    public var fullScreenTitle: String { isFullScreen ? "Exit Full Screen" : "Enter Full Screen" }

    // MARK: - Helpers

    /// The frames per second as a whole number, once the session has measured a second.
    private var measuredRate: Int? {
        framesPerSecond > 0 ? Int(framesPerSecond.rounded()) : nil
    }

    /// Opens `question`, pausing the game while it asks, as the design does. The pause goes even when
    /// the last snapshot said paused: a Resume sent before it may not have reached the session yet, and
    /// the session's pause does nothing unless running, so the game is held under the alert either way.
    private func ask(_ question: Confirmation) {
        guard isPlaying, confirmation == nil else { return }
        confirmation = question
        send { await $0.pause() }
    }

    /// Sends a control to the session after every control sent before it.
    private func send(_ control: @escaping @Sendable (any ConsoleSessionControls) async -> Void) {
        let previous = commands
        let session = self.session
        commands = Task {
            await previous?.value
            await control(session)
        }
    }

    /// Waits until every control sent so far has reached the session; the tests' way to know.
    func settled() async {
        await commands?.value
    }
}

extension PlayerViewModel.State {
    /// The player's state for a session's.
    init(_ state: ConsoleSessionSnapshot.State) {
        switch state {
        case .poweredOff: self = .nothingLoaded
        case .running: self = .running
        case .paused: self = .paused
        case .stopped: self = .stopped
        }
    }
}
