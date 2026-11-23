// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessPS1
@testable import BusinessSession
import Testing

/// `ConsoleSession` over a clock the test moves: power on, frames at 60 a second, pause, resume, reset
/// and stop, and the snapshots it gives — every image and EXE built in code.
@Suite struct ConsoleSessionTests {
    let clock = ManualClock()

    /// A session over the test's clock.
    func makeSession() -> ConsoleSession<ManualClock> { ConsoleSession(clock: clock) }

    // MARK: Power on

    @Test func aNewSessionIsPoweredOffAndHoldsNoConsole() async {
        let session = makeSession()
        #expect(await session.snapshot == ConsoleSessionSnapshot(state: .poweredOff))
        #expect(await !session.holdsConsole)
        #expect(clock.sleeperCount == 0) // nothing runs before power on
    }

    @Test func poweringOnStartsAtFrameZeroAndRunsNoFrameBeforeASixtiethHasPassed() async throws {
        let session = makeSession()
        try await session.powerOn(bios: shellBIOS())
        let snapshot = await session.snapshot
        #expect(snapshot.state == .running)
        #expect(snapshot.frame == 0)
        #expect(await session.holdsConsole)
        #expect(await eventually { clock.sleeperCount == 1 })
        #expect(clock.nextDeadline == clock.now.advanced(by: .seconds(1) / 60))
        #expect(await session.snapshot.frame == 0)
        await session.stop()
    }

    @Test func aWrongSizeBIOSIsRefusedAndChangesNothing() async throws {
        let session = makeSession()
        await #expect(throws: PS1Error.biosSize(1000)) { try await session.powerOn(bios: wrongSizeBIOS, exe: okEXE) }
        #expect(await session.snapshot == ConsoleSessionSnapshot(state: .poweredOff))
        #expect(await !session.holdsConsole)
        #expect(clock.sleeperCount == 0)

        // Running, it keeps the console it had, at its frame, and goes on.
        try await session.powerOn(bios: shellBIOS())
        var ticks = Ticks(clock)
        #expect(await ticks.run(2, session))
        await #expect(throws: PS1Error.biosSize(1000)) { try await session.powerOn(bios: wrongSizeBIOS) }
        let kept = await session.snapshot
        #expect(kept.state == .running && kept.frame == 2 && kept.reachedShell)
        #expect(await ticks.run(1, session))
        #expect(await session.snapshot.frame == 3)
        await session.stop()
    }

    @Test func poweringOnAgainStartsAFreshRun() async throws {
        let session = makeSession()
        try await session.powerOn(bios: shellBIOS())
        var ticks = Ticks(clock)
        #expect(await ticks.run(3, session))
        #expect(await session.snapshot.reachedShell)
        try await session.powerOn(bios: stuckBIOS(), exe: okEXE)
        let fresh = await session.snapshot
        #expect(fresh.state == .running && fresh.frame == 0 && !fresh.reachedShell && fresh.bootIsPending)
        ticks.restart()
        #expect(await ticks.run(2, session))
        #expect(await session.snapshot.frame == 2)
        #expect(await isOneLoop()) // the old run's loop is gone
        await session.stop()
    }

    // MARK: Pacing

    @Test func sixtyTicksRunSixtyFramesInOneSecondOfTheClock() async throws {
        let session = makeSession()
        let start = clock.now
        try await session.powerOn(bios: shellBIOS())
        var ticks = Ticks(clock)
        #expect(await ticks.run(59, session))
        let early = await session.snapshot
        #expect(early.frame == 59)
        #expect(early.framesPerSecond == 0) // not a whole second of frames yet
        #expect(await ticks.run(1, session))
        let second = await session.snapshot
        #expect(second.frame == 60)
        #expect(start.duration(to: clock.now) == .seconds(1))
        #expect(second.framesPerSecond == 60)
        await session.stop()
    }

    @Test func betweenTicksTheFrameWaitsForTheClock() async throws {
        let session = makeSession()
        try await session.powerOn(bios: shellBIOS())
        var ticks = Ticks(clock)
        for frame in 1...5 {
            #expect(await ticks.run(1, session))
            #expect(await eventually { clock.sleeperCount == 1 }) // asleep until the next sixtieth
            #expect(clock.nextDeadline == ticks.instant(frame + 1))
            #expect(await session.snapshot.frame == frame)
        }
        await session.stop()
    }

    @Test func aSessionThatFallsBehindPacesFromNowInsteadOfRacingToCatchUp() async throws {
        let session = makeSession()
        let start = clock.now
        try await session.powerOn(bios: shellBIOS())
        #expect(await eventually { clock.sleeperCount == 1 })
        clock.advance(to: start.advanced(by: .seconds(1))) // a second late: a stall, the Mac asleep
        #expect(await eventually(session) { $0.frame >= 1 } != nil)
        #expect(await eventually { clock.sleeperCount == 1 })
        #expect(await session.snapshot.frame == 1) // one frame, not sixty in a burst
        #expect(clock.nextDeadline == clock.now.advanced(by: .seconds(1) / 60))
        await session.stop()
    }

    @Test func framesPerSecondMeasuresTheFramesActuallyRun() async throws {
        let session = makeSession()
        try await session.powerOn(bios: shellBIOS())
        var ticks = Ticks(clock)
        #expect(await ticks.run(60, session))
        #expect(await session.snapshot.framesPerSecond == 60)
        // The next second's frames each come three sixtieths late, too late to catch up: 20 of them.
        for _ in 0..<20 {
            let frame = await session.snapshot.frame
            clock.advance(to: clock.now.advanced(by: .seconds(3) / 60))
            #expect(await eventually(session) { $0.frame > frame } != nil)
            #expect(await eventually { clock.sleeperCount == 1 })
        }
        let slow = await session.snapshot
        #expect(slow.frame == 80)
        #expect(slow.framesPerSecond == 20)
        await session.stop()
    }

    @Test func aFrameOneSixtiethLateIsCaughtUp() async throws {
        let session = makeSession()
        try await session.powerOn(bios: shellBIOS())
        var ticks = Ticks(clock)
        #expect(await ticks.run(1, session))
        clock.advance(to: ticks.instant(3)) // frame 2's tick missed by one sixtieth
        #expect(await eventually(session) { $0.frame >= 3 } != nil)
        #expect(await eventually { clock.sleeperCount == 1 })
        #expect(await session.snapshot.frame == 3)
        #expect(clock.nextDeadline == ticks.instant(4)) // still on the original pace
        await session.stop()
    }

    @Test func withTheContinuousClockFramesKeepToTheClockInsteadOfRacing() async throws {
        // The one real-time test. Unpaced, the code-built BIOS runs thousands of frames in this window,
        // so the ceiling is what proves the frames are paced. The floor is loose: a loaded machine runs
        // frames late, and the pace drops what it can't catch up. The exact 60 a second is the
        // ManualClock tests' proof, over the same FramePace.
        let session = ConsoleSession()
        try await session.powerOn(bios: shellBIOS())
        // The first frame, waited for with a timeout, so a busy machine's slow start fails nothing.
        #expect(await eventually(session) { $0.frame >= 1 } != nil, "no frame ran within the timeout")
        // The window opens before its first frame is read and closes after its last, so it never
        // counts a frame it didn't time.
        let start = ContinuousClock.now
        let first = await session.snapshot.frame
        try await Task.sleep(for: .milliseconds(500))
        let last = await session.snapshot.frame
        let elapsed = start.duration(to: .now).inSeconds
        await session.stop()
        let frames = Double(last - first)
        #expect(frames <= elapsed * 60 + 2, "\(frames) frames in \(elapsed) s: faster than 60 a second")
        #expect(frames >= elapsed * 60 / 4, "\(frames) frames in \(elapsed) s: slower than 15 a second")
    }

    // MARK: Pause and resume

    @Test func pausingHoldsTheFrame() async throws {
        let session = makeSession()
        try await session.powerOn(bios: shellBIOS())
        var ticks = Ticks(clock)
        #expect(await ticks.run(60, session))
        await session.pause()
        let paused = await session.snapshot
        #expect(paused.state == .paused)
        #expect(paused.frame == 60)
        #expect(paused.framesPerSecond == 0) // no frames run while paused
        #expect(clock.sleeperCount == 0) // the loop has ended: nothing waits for a tick
        clock.advance(to: clock.now.advanced(by: .seconds(2)))
        try await Task.sleep(for: .milliseconds(20))
        #expect(await session.snapshot == paused)
        await session.stop()
    }

    @Test func resumingContinuesFromTheHeldFrame() async throws {
        let session = makeSession()
        try await session.powerOn(bios: shellBIOS())
        var ticks = Ticks(clock)
        #expect(await ticks.run(3, session))
        await session.pause()
        clock.advance(to: clock.now.advanced(by: .seconds(1)))
        await session.resume()
        #expect(await session.snapshot.state == .running)
        #expect(await session.snapshot.frame == 3)
        ticks.restart() // frames are paced from the resume
        #expect(await ticks.run(2, session))
        #expect(await session.snapshot.frame == 5)
        await session.stop()
    }

    @Test func pauseAndResumeActOnlyInTheirStates() async throws {
        let session = makeSession()
        await session.pause()
        await session.resume()
        #expect(await session.snapshot.state == .poweredOff)
        #expect(clock.sleeperCount == 0)
        try await session.powerOn(bios: shellBIOS())
        await session.resume() // already running
        #expect(await isOneLoop())
        await session.pause()
        await session.pause()
        #expect(await session.snapshot.state == .paused)
        #expect(clock.sleeperCount == 0)
        await session.resume()
        await session.resume()
        #expect(await session.snapshot.state == .running)
        #expect(await isOneLoop())
        await session.stop()
    }

    /// True once exactly one frame loop waits on the clock, and still one a moment later: none started twice.
    func isOneLoop() async -> Bool {
        guard await eventually({ clock.sleeperCount == 1 }) else { return false }
        try? await Task.sleep(for: .milliseconds(20))
        return clock.sleeperCount == 1
    }

    // MARK: Reset

    @Test func resetPowersOnAgainAndBootsTheSameEXEAgain() async throws {
        let session = makeSession()
        try await session.powerOn(bios: shellBIOS(printing: "BIOS "), exe: okEXE)
        var ticks = Ticks(clock)
        #expect(await ticks.run(2, session))
        let played = await session.snapshot
        #expect(played.frame == 2 && played.reachedShell && !played.bootIsPending)
        await session.reset()
        let reset = await session.snapshot
        #expect(reset.state == .running)
        #expect(reset.frame == 0)
        #expect(!reset.reachedShell)
        #expect(reset.bootIsPending) // the same EXE, given again before the first frame
        #expect(reset.framesPerSecond == 0)
        ticks.restart()
        #expect(await ticks.run(1, session))
        let again = await session.snapshot
        #expect(again.frame == 1 && again.reachedShell && !again.bootIsPending)
        #if PERSONAL_BUILD
        #expect(again.debugSnapshot?.tty == "BIOS OK") // a fresh machine: the BIOS and the EXE once each
        #expect(again.debugSnapshot?.ttySinceEXE == "OK")
        #endif
        #expect(await isOneLoop())
        await session.stop()
    }

    @Test func resettingAPausedSessionRunsItFromFrameZero() async throws {
        let session = makeSession()
        try await session.powerOn(bios: shellBIOS())
        var ticks = Ticks(clock)
        #expect(await ticks.run(4, session))
        await session.pause()
        await session.reset()
        #expect(await session.snapshot.state == .running)
        #expect(await session.snapshot.frame == 0)
        ticks.restart()
        #expect(await ticks.run(2, session))
        #expect(await session.snapshot.frame == 2)
        await session.stop()
    }

    @Test func resetDoesNothingBeforePowerOn() async {
        let session = makeSession()
        await session.reset()
        #expect(await session.snapshot == ConsoleSessionSnapshot(state: .poweredOff))
        #expect(await !session.holdsConsole)
    }

    // MARK: Stop

    @Test func stopEndsTheLoopReleasesTheConsoleAndFinishesTheStream() async throws {
        let session = makeSession()
        try await session.powerOn(bios: shellBIOS(), exe: okEXE)
        let collector = Collector(await session.snapshots())
        var ticks = Ticks(clock)
        #expect(await ticks.run(3, session))
        await session.stop()
        let stopped = await session.snapshot
        #expect(stopped.state == .stopped)
        #expect(stopped.frame == 3) // where it stopped
        #expect(stopped.framesPerSecond == 0)
        #expect(await !session.holdsConsole)
        #expect(clock.sleeperCount == 0)
        let seen = try #require(await collector.collected(), "the stream didn't finish")
        #expect(seen.first?.state == .running)
        #expect(seen.last == stopped)
        #expect(seen.map(\.frame) == seen.map(\.frame).sorted())
        // Stopped, the controls do nothing.
        await session.pause()
        await session.resume()
        await session.reset()
        #expect(await session.snapshot == stopped)
        #expect(clock.sleeperCount == 0)
    }

    @Test func aStoppedSessionPowersOnAgainWithNewStreams() async throws {
        let session = makeSession()
        try await session.powerOn(bios: shellBIOS())
        await session.stop()
        try await session.powerOn(bios: shellBIOS())
        let collector = Collector(await session.snapshots())
        var ticks = Ticks(clock)
        #expect(await ticks.run(2, session))
        await session.stop()
        let seen = try #require(await collector.collected(), "the stream didn't finish")
        #expect(seen.first?.state == .running)
        #expect(seen.contains { $0.frame == 2 })
        #expect(seen.last?.state == .stopped)
    }

    // MARK: Snapshots

    @Test func theStreamStartsWithTheCurrentSnapshotAndFollowsTheFrames() async throws {
        let session = makeSession()
        let idle = Collector(await session.snapshots())
        #expect(await eventually { idle.latest == ConsoleSessionSnapshot(state: .poweredOff) })
        try await session.powerOn(bios: shellBIOS())
        let running = Collector(await session.snapshots())
        #expect(await eventually { running.latest?.state == .running && running.latest?.frame == 0 })
        var ticks = Ticks(clock)
        for frame in 1...3 {
            #expect(await ticks.run(1, session))
            #expect(await eventually { idle.latest?.frame == frame && running.latest?.frame == frame })
        }
        await session.pause()
        #expect(await eventually { running.latest?.state == .paused })
        await session.stop()
        let fromIdle = try #require(await idle.collected(), "the stream didn't finish")
        let fromRunning = try #require(await running.collected(), "the stream didn't finish")
        #expect(fromIdle.first == ConsoleSessionSnapshot(state: .poweredOff))
        #expect(fromRunning.first?.state == .running && fromRunning.first?.frame == 0)
        for seen in [fromIdle, fromRunning] {
            #expect(seen.map(\.frame) == seen.map(\.frame).sorted())
            #expect(seen.last?.state == .stopped && seen.last?.frame == 3)
        }
    }

    @Test func aStreamTakenOnceStoppedGivesTheStoppedSnapshotUntilTheNextStop() async throws {
        let session = makeSession()
        try await session.powerOn(bios: shellBIOS())
        await session.stop()
        let late = Collector(await session.snapshots())
        #expect(await eventually { late.latest?.state == .stopped })
        try await session.powerOn(bios: shellBIOS())
        #expect(await eventually { late.latest?.state == .running })
        await session.stop()
        let seen = try #require(await late.collected(), "the stream didn't finish")
        #expect(seen.first?.state == .stopped)
        #expect(seen.last?.state == .stopped)
    }

    @Test func anEXEGivenAtPowerOnStartsOnceTheBIOSReachesItsShell() async throws {
        let session = makeSession()
        try await session.powerOn(bios: shellBIOS(printing: "BIOS "), exe: okEXE)
        let before = await session.snapshot
        #expect(before.bootIsPending) // given before the first frame
        #expect(!before.reachedShell)
        var ticks = Ticks(clock)
        #expect(await ticks.run(1, session))
        let after = await session.snapshot
        #expect(!after.bootIsPending)
        #expect(after.reachedShell)
        #if PERSONAL_BUILD
        #expect(after.debugSnapshot?.ttySinceEXE == "OK")
        #endif
        await session.stop()
    }

    @Test func anEXEWaitsForAShellTheBIOSNeverReaches() async throws {
        let session = makeSession()
        try await session.powerOn(bios: stuckBIOS(printing: "BIOS"), exe: okEXE)
        var ticks = Ticks(clock)
        #expect(await ticks.run(30, session)) // istation-run's 30 frames, then its exit 3
        let snapshot = await session.snapshot
        #expect(snapshot.bootIsPending)
        #expect(!snapshot.reachedShell)
        #if PERSONAL_BUILD
        #expect(snapshot.debugSnapshot?.tty == "BIOS")
        #endif
        await session.stop()
    }

    @Test func withoutAnEXENothingWaitsAndTheShellIsReached() async throws {
        let session = makeSession()
        try await session.powerOn(bios: shellBIOS())
        #expect(await !session.snapshot.bootIsPending)
        #expect(await !session.snapshot.reachedShell)
        var ticks = Ticks(clock)
        #expect(await ticks.run(1, session))
        #expect(await !session.snapshot.bootIsPending)
        #expect(await session.snapshot.reachedShell)
        await session.stop()
    }
}
