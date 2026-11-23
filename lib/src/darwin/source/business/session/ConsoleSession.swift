// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessPS1

#if PERSONAL_BUILD
/// The console a personal build's session runs: the tracing console, counting the instructions it
/// retires (6a), so the snapshot carries the instructions run and the debug values.
typealias SessionConsole = PS1TracingConsole<InstructionCounter>
#else
/// The console an App Store build's session runs: `PS1Console`, untouched (ADR 0016).
typealias SessionConsole = PS1Console
#endif

/// Runs one PS1 console off the main actor: powers it on with a BIOS and, for a PS-EXE, boots it before
/// the first frame; runs its frames 60 a second by `SessionClock`; pauses, resumes, resets and stops it;
/// and streams a `ConsoleSessionSnapshot` each frame. The console is this actor's own state, so every
/// call into it — the frames and the controls — is made here, one at a time and between frames, never
/// from two places at once (ADR 0015 §4). The apps pace it by `ContinuousClock`; tests give it a clock
/// they move. In personal builds it runs `PS1TracingConsole`, counting instructions; in App Store
/// builds `PS1Console`.
public actor ConsoleSession<SessionClock: Clock>: ConsoleSessionControls where SessionClock.Duration == Duration {
    private let clock: SessionClock

    /// The console, from power-on until stop.
    private var console: SessionConsole?
    /// What the console was powered on with, for Reset.
    private var bios: [UInt8] = []
    private var exe: PSEXE?
    private var capturesBIOSPutchar = false

    private var current = ConsoleSessionSnapshot()

    /// The frame loop now running, by number: pausing, resetting, powering on and stopping each end it,
    /// and a loop whose number has passed runs no frame more.
    private var run = 0
    private var loop: Task<Void, Never>?

    /// Frames per second's measure: the frames run since `measuredFrom`.
    private var measuredFrom: SessionClock.Instant?
    private var framesSinceMeasured = 0

    private var observers: [Int: AsyncStream<ConsoleSessionSnapshot>.Continuation] = [:]
    private var lastObserver = 0

    /// A session, powered off, whose frames `clock` will pace.
    public init(clock: SessionClock) {
        self.clock = clock
    }

    deinit {
        loop?.cancel()
        for observer in observers.values { observer.finish() }
    }

    /// What the session is doing now.
    public var snapshot: ConsoleSessionSnapshot { current }

    /// Whether the session holds a console: from power-on until stop.
    var holdsConsole: Bool { console != nil }

    // MARK: - The controls

    /// Powers on a fresh console with `bios`, the user's 512 KB image, gives it `exe` to boot before its
    /// first frame — the BIOS's shell is entered once per power-on, so an EXE given later waits for good
    /// — and runs it from frame 0, its first frame a sixtieth of a second from now. In any state: a
    /// running or paused session starts afresh, a stopped one runs again. An image of another size
    /// throws and changes nothing: the session goes on as it was.
    public func powerOn(bios: [UInt8], exe: PSEXE? = nil) throws(PS1Error) {
        try start(bios: bios, exe: exe, capturesBIOSPutchar: false)
    }

    #if PERSONAL_BUILD
    /// `powerOn(bios:exe:)`, with the BIOS's putchar calls captured into the TTY when
    /// `capturesBIOSPutchar` is true (5f's Settings › Personal); Reset powers on the same way.
    public func powerOn(bios: [UInt8], exe: PSEXE? = nil, capturesBIOSPutchar: Bool) throws(PS1Error) {
        try start(bios: bios, exe: exe, capturesBIOSPutchar: capturesBIOSPutchar)
    }
    #endif

    /// Holds the frame: the frame loop ends, and frames wait until `resume()`. Nothing unless running.
    public func pause() {
        guard current.state == .running else { return }
        endLoop()
        current.state = .paused
        current.framesPerSecond = 0
        publish()
    }

    /// Runs frames again from the held frame, the next a sixtieth of a second from now. Nothing unless paused.
    public func resume() {
        guard current.state == .paused else { return }
        startLoop()
    }

    /// Powers on again with the same BIOS, gives the same PS-EXE to `boot(exe:)` again, and runs from
    /// frame 0 — a paused session too. Nothing unless running or paused.
    public func reset() {
        guard current.state == .running || current.state == .paused else { return }
        // The BIOS powered the console on once, so its size is right and this can't throw.
        try? start(bios: bios, exe: exe, capturesBIOSPutchar: capturesBIOSPutchar)
    }

    /// Ends the frame loop and releases the console, keeping the frame it stopped at in the snapshot;
    /// every snapshot stream gets the stopped snapshot and finishes. The BIOS and disc files are left as
    /// they are, and nothing is saved.
    public func stop() {
        endLoop()
        console = nil
        bios = []
        exe = nil
        current.state = .stopped
        current.framesPerSecond = 0
        publish()
        for observer in observers.values { observer.finish() }
        observers = [:]
    }

    /// A stream of the session's snapshots, the current one first, then one each frame and each change
    /// of state; a slow reader gets the latest. It finishes at the next `stop()`.
    public func snapshots() -> AsyncStream<ConsoleSessionSnapshot> {
        let (stream, continuation) = AsyncStream.makeStream(of: ConsoleSessionSnapshot.self, bufferingPolicy: .bufferingNewest(1))
        continuation.yield(current)
        lastObserver += 1
        observers[lastObserver] = continuation
        return stream
    }

    // MARK: - Running

    /// Powers on a fresh console and starts its frames; throws, changing nothing, for a wrong-size BIOS.
    private func start(bios: [UInt8], exe: PSEXE?, capturesBIOSPutchar: Bool) throws(PS1Error) {
        let console = SessionConsole()
        #if PERSONAL_BUILD
        try console.powerOn(bios: bios, tracer: InstructionCounter(), capturesBIOSPutchar: capturesBIOSPutchar)
        #else
        try console.powerOn(bios: bios)
        #endif
        if let exe { console.boot(exe: exe) }
        self.console = console
        self.bios = bios
        self.exe = exe
        self.capturesBIOSPutchar = capturesBIOSPutchar
        current = ConsoleSessionSnapshot()
        read(console)
        startLoop()
    }

    /// Starts a frame loop, ending the one before: it sleeps until each frame is due, then has this
    /// actor run it. It holds the session weakly, so a session let go without `stop()` ends it too.
    private func startLoop() {
        endLoop()
        let run = self.run
        let clock = self.clock
        let start = clock.now
        measuredFrom = start
        framesSinceMeasured = 0
        current.state = .running
        current.framesPerSecond = 0
        publish()
        loop = Task.detached(priority: .userInitiated) { [weak self] in
            var pace = FramePace(from: start)
            while true {
                do {
                    try await clock.sleep(until: pace.deadline, tolerance: nil)
                } catch {
                    return // cancelled: the loop has ended
                }
                let now = clock.now
                pace.frameIsDue(at: now)
                guard let session = self, await session.runFrame(of: run, at: now) else { return }
            }
        }
    }

    /// Ends the frame loop now running, if any: its next frame never runs.
    private func endLoop() {
        run += 1
        loop?.cancel()
        loop = nil
    }

    /// Runs one frame for loop `run`, due at `now`, and publishes it; false when that loop has ended.
    private func runFrame(of run: Int, at now: SessionClock.Instant) -> Bool {
        guard run == self.run, let console else { return false }
        console.runFrame()
        framesSinceMeasured += 1
        if let measuredFrom {
            let elapsed = measuredFrom.duration(to: now)
            if elapsed >= .seconds(1) {
                current.framesPerSecond = Double(framesSinceMeasured) / elapsed.inSeconds
                self.measuredFrom = now
                framesSinceMeasured = 0
            }
        }
        read(console)
        publish()
        return true
    }

    /// Copies the console's values into the snapshot.
    private func read(_ console: SessionConsole) {
        current.frame = console.frame
        current.reachedShell = console.reachedShell
        current.bootIsPending = console.bootIsPending
        #if PERSONAL_BUILD
        current.instructions = console.tracer?.count ?? 0
        current.debugSnapshot = console.debugSnapshot
        #endif
    }

    /// Gives the snapshot to every stream, forgetting those whose reader has gone.
    private func publish() {
        for (id, observer) in observers {
            if case .terminated = observer.yield(current) { observers[id] = nil }
        }
    }
}

extension ConsoleSession where SessionClock == ContinuousClock {
    /// A powered-off session paced by the system's continuous clock, as the apps run one.
    public init() {
        self.init(clock: ContinuousClock())
    }
}

/// When each frame is due: 60 a second from a start, until the video standard is known (G12). Frames
/// running late by up to a frame catch up; further behind — a stall, the Mac asleep — the pace starts
/// again from the late frame, so lost time is never made up in a burst.
struct FramePace<Instant: InstantProtocol> where Instant.Duration == Duration {
    /// Frames a second.
    static var rate: Int { 60 }

    private var start: Instant
    private var frames = 0

    /// A pace whose first frame is due a sixtieth of a second after `start`.
    init(from start: Instant) {
        self.start = start
    }

    /// When the next frame is due.
    var deadline: Instant { due(frames + 1) }

    /// When frame `number` of this pace is due: each from the start, so sixtieths, which no whole number
    /// of attoseconds is, never add up their rounding.
    private func due(_ number: Int) -> Instant { start.advanced(by: .seconds(number) / Self.rate) }

    /// The next frame runs now: counted on this pace, or, more than a frame late — past the frame after
    /// it — the start of a new one.
    mutating func frameIsDue(at now: Instant) {
        if now > due(frames + 2) {
            start = now
            frames = 0
        } else {
            frames += 1
        }
    }
}

extension Duration {
    /// The duration in seconds, as a `Double`.
    var inSeconds: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
