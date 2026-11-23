// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessSession

/// A console session the tests script: it records every call the player makes, answers the controls
/// as `ConsoleSession` does — pause holds, resume runs, reset runs from frame 0, stop finishes every
/// stream with the stopped snapshot — and sends whatever snapshot a test gives it, as frames would.
actor FakeSession: ConsoleSessionControls {
    /// One call the player made.
    enum Call: Equatable, Sendable {
        case pause, resume, reset, stop, snapshots
    }

    /// Every call, in the order made.
    private(set) var calls: [Call] = []
    /// What the session is doing now.
    private(set) var current: ConsoleSessionSnapshot
    private var streams: [AsyncStream<ConsoleSessionSnapshot>.Continuation] = []
    /// How long `pause()` takes before it holds the frame, so a control sent after it could overtake it.
    private let pauseTakes: Duration

    /// A session doing `snapshot`'s state — a running one at frame 0 unless a test says otherwise —
    /// whose pause takes `pauseTakes`.
    init(_ snapshot: ConsoleSessionSnapshot = ConsoleSessionSnapshot(state: .running), pauseTakes: Duration = .zero) {
        current = snapshot
        self.pauseTakes = pauseTakes
    }

    /// The controls the player called, without its snapshot streams.
    var controls: [Call] { calls.filter { $0 != .snapshots } }

    func pause() async {
        if pauseTakes > .zero { try? await Task.sleep(for: pauseTakes) }
        calls.append(.pause)
        guard current.state == .running else { return }
        current.state = .paused
        current.framesPerSecond = 0
        publish()
    }

    func resume() {
        calls.append(.resume)
        guard current.state == .paused else { return }
        current.state = .running
        publish()
    }

    func reset() {
        calls.append(.reset)
        guard current.state == .running || current.state == .paused else { return }
        current = ConsoleSessionSnapshot(state: .running)
        publish()
    }

    func stop() {
        calls.append(.stop)
        current.state = .stopped
        current.framesPerSecond = 0
        publish()
        finishStreams()
    }

    func snapshots() -> AsyncStream<ConsoleSessionSnapshot> {
        calls.append(.snapshots)
        let (stream, continuation) = AsyncStream.makeStream(of: ConsoleSessionSnapshot.self)
        continuation.yield(current)
        streams.append(continuation)
        return stream
    }

    /// Sends `snapshot` to every stream, as the session does each frame and each change of state.
    func send(_ snapshot: ConsoleSessionSnapshot) {
        current = snapshot
        publish()
    }

    /// Finishes every stream without a stopped snapshot, as a session let go does.
    func finishStreams() {
        for stream in streams { stream.finish() }
        streams = []
    }

    private func publish() {
        for stream in streams { stream.yield(current) }
    }
}

/// Waits on the main actor until `condition` holds, for up to two seconds: the player hears its
/// session's snapshots on a task of its own. True once it holds, false if it never did.
@MainActor
func eventually(_ condition: () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now.advanced(by: .seconds(2))
    while !condition() {
        guard ContinuousClock.now < deadline else { return false }
        try? await Task.sleep(for: .milliseconds(1))
    }
    return true
}
