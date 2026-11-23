// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

#if DEBUG
import BusinessSession

/// A console session for previews: no console, only a snapshot it holds and answers the controls with
/// as `ConsoleSession` does — pause holds, resume runs, reset runs from frame 0, stop ends the run — so
/// a preview's buttons work and nothing runs or reads a file.
actor PreviewSession: ConsoleSessionControls {
    private var current: ConsoleSessionSnapshot
    private var streams: [AsyncStream<ConsoleSessionSnapshot>.Continuation] = []

    /// A session doing what `snapshot` says.
    init(_ snapshot: ConsoleSessionSnapshot) {
        current = snapshot
    }

    func pause() {
        guard current.state == .running else { return }
        current.state = .paused
        current.framesPerSecond = 0
        publish()
    }

    func resume() {
        guard current.state == .paused else { return }
        current.state = .running
        publish()
    }

    func reset() {
        guard current.state == .running || current.state == .paused else { return }
        current = ConsoleSessionSnapshot(state: .running)
        publish()
    }

    func stop() {
        current.state = .stopped
        current.framesPerSecond = 0
        publish()
        for stream in streams { stream.finish() }
        streams = []
    }

    func snapshots() -> AsyncStream<ConsoleSessionSnapshot> {
        let (stream, continuation) = AsyncStream.makeStream(of: ConsoleSessionSnapshot.self, bufferingPolicy: .bufferingNewest(1))
        continuation.yield(current)
        streams.append(continuation)
        return stream
    }

    private func publish() {
        for stream in streams { stream.yield(current) }
    }
}

/// Player view-models for previews, one per visible state, over a `PreviewSession` and sample runs
/// named as the design names them: never a real BIOS, a game or the person's files.
@MainActor
enum PreviewPlayer {
    /// The BIOS alone, as the design's placeholder names it: 512 KB.
    static let bios = PlayerRun(biosFileName: "my-console-bios.bin", biosSize: 524_288)
    /// A homebrew PS-EXE, as the design's library holds one.
    static let program = PlayerRun(
        biosFileName: "my-console-bios.bin", biosSize: 524_288,
        program: PlayerRun.Program(name: "gpu-test", fileName: "gpu-test.exe")
    )

    /// Nothing chosen yet.
    static func nothingLoaded() -> PlayerViewModel {
        PlayerViewModel(session: PreviewSession(ConsoleSessionSnapshot()))
    }

    /// Running at 60 frames a second, as `Mac-TodayPlayer` draws it: frame 1,234.
    static func running(_ run: PlayerRun = bios) -> PlayerViewModel {
        playing(run, ConsoleSessionSnapshot(state: .running, frame: 1_234, framesPerSecond: 60))
    }

    /// Just powered on: frame 0, before a second has been measured.
    static func justStarted() -> PlayerViewModel {
        playing(bios, ConsoleSessionSnapshot(state: .running))
    }

    /// Paused at frame 1,234, the overlay offering Resume.
    static func paused() -> PlayerViewModel {
        playing(bios, ConsoleSessionSnapshot(state: .paused, frame: 1_234))
    }

    /// Stopped at frame 1,234, the console released.
    static func stopped() -> PlayerViewModel {
        playing(bios, ConsoleSessionSnapshot(state: .stopped, frame: 1_234))
    }

    /// Reset asking first, over a paused game, as `Mac-ResetConfirm` draws it.
    static func resetConfirm(_ run: PlayerRun = bios) -> PlayerViewModel {
        let player = playing(run, ConsoleSessionSnapshot(state: .paused, frame: 1_234))
        player.askToReset()
        return player
    }

    /// Stop asking first, over a paused game, as `Mac-StopConfirm` draws it.
    static func stopConfirm(_ run: PlayerRun = bios) -> PlayerViewModel {
        let player = playing(run, ConsoleSessionSnapshot(state: .paused, frame: 1_234))
        player.askToStop()
        return player
    }

    /// Running full screen, the HUD carrying Pause and Exit full screen, as `Mac-PlayerFullscreen` does.
    static func fullScreen() -> PlayerViewModel {
        let player = running()
        player.toggleFullScreen()
        return player
    }

    /// A player told `run` started, showing `snapshot` at once rather than when its stream first
    /// delivers, so a preview draws its state from the first frame.
    private static func playing(_ run: PlayerRun, _ snapshot: ConsoleSessionSnapshot) -> PlayerViewModel {
        let player = PlayerViewModel(session: PreviewSession(snapshot))
        player.started(run)
        player.show(snapshot)
        return player
    }
}
#endif
