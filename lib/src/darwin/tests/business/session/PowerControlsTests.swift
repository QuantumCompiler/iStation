// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessPS1
import BusinessSession
import Testing

/// `ConsoleSession` driven only through `ConsoleSessionPowerControls`, as a starter drives it — the BIOS
/// check, Run the BIOS: a wrong-size image refused with its byte count, the shell's reaching seen in the
/// snapshot or its not reaching it, and the controls and stream it inherits — over images built in code
/// and the test's clock.
@Suite struct PowerControlsTests {
    let clock = ManualClock()

    /// A session over the test's clock, seen only as a starter sees it.
    func makeStarter() -> some ConsoleSessionPowerControls { ConsoleSession(clock: clock) }

    @Test func aWrongSizeBIOSThrowsItsSizeAndNothingRuns() async {
        let starter = makeStarter()
        await #expect(throws: PS1Error.biosSize(1000)) { try await starter.powerOn(bios: wrongSizeBIOS, exe: nil) }
        await #expect(throws: PS1Error.biosSize(0)) { try await starter.powerOn(bios: [], exe: okEXE) }
        #expect(await starter.snapshot == ConsoleSessionSnapshot(state: .poweredOff))
        #expect(clock.sleeperCount == 0) // no frame loop was started
    }

    @Test func aBIOSThatReachesItsShellIsSeenReachingIt() async throws {
        let starter = makeStarter()
        try await starter.powerOn(bios: shellBIOS(), exe: nil)
        let poweredOn = await starter.snapshot
        #expect(poweredOn.state == .running && poweredOn.frame == 0 && !poweredOn.reachedShell && !poweredOn.bootIsPending)
        var ticks = Ticks(clock)
        #expect(await ticks.run(1, starter))
        let shell = await starter.snapshot
        #expect(shell.frame == 1 && shell.reachedShell)
        #expect(await ticks.run(59, starter))
        let second = await starter.snapshot
        #expect(second.frame == 60 && second.reachedShell) // true from then on
        await starter.stop()
        let stopped = await starter.snapshot
        #expect(stopped.state == .stopped && stopped.frame == 60)
    }

    @Test func aBIOSThatNeverReachesItsShellIsSeenNotReachingIt() async throws {
        let starter = makeStarter()
        try await starter.powerOn(bios: stuckBIOS(), exe: nil)
        var ticks = Ticks(clock)
        #expect(await ticks.run(60, starter))
        let snapshot = await starter.snapshot
        #expect(snapshot.state == .running && snapshot.frame == 60 && !snapshot.reachedShell)
        await starter.stop()
    }

    @Test func aWrongSizeBIOSLeavesARunningSessionAsItWas() async throws {
        let starter = makeStarter()
        try await starter.powerOn(bios: shellBIOS(), exe: nil)
        var ticks = Ticks(clock)
        #expect(await ticks.run(2, starter))
        await #expect(throws: PS1Error.biosSize(1000)) { try await starter.powerOn(bios: wrongSizeBIOS, exe: nil) }
        let kept = await starter.snapshot
        #expect(kept.state == .running && kept.frame == 2 && kept.reachedShell)
        #expect(await ticks.run(1, starter))
        #expect(await starter.snapshot.frame == 3)
        await starter.stop()
    }

    @Test func poweringOnAgainThroughTheProtocolStartsAfresh() async throws {
        let starter = makeStarter()
        try await starter.powerOn(bios: shellBIOS(), exe: nil)
        var ticks = Ticks(clock)
        #expect(await ticks.run(3, starter))
        await starter.stop()
        try await starter.powerOn(bios: stuckBIOS(), exe: okEXE) // a stopped session runs again
        let fresh = await starter.snapshot
        #expect(fresh.state == .running && fresh.frame == 0 && !fresh.reachedShell && fresh.bootIsPending)
        ticks.restart()
        #expect(await ticks.run(2, starter))
        let stuck = await starter.snapshot
        #expect(stuck.frame == 2 && !stuck.reachedShell && stuck.bootIsPending) // the EXE waits for good
        await starter.stop()
    }

    @Test func theInheritedControlsAndStreamFollowAPowerOn() async throws {
        let starter = makeStarter()
        try await starter.powerOn(bios: shellBIOS(), exe: okEXE)
        let collector = Collector(await starter.snapshots())
        // The stream keeps only the newest snapshot for a reader that falls behind, so each snapshot the
        // test looks for is waited for before the next control can take its place.
        #expect(await eventually { collector.latest?.bootIsPending == true }, "the first snapshot never came")
        var ticks = Ticks(clock)
        #expect(await ticks.run(1, starter))
        #expect(await eventually { collector.latest.map { $0.reachedShell && !$0.bootIsPending } == true })
        await starter.pause()
        #expect(await starter.snapshot.state == .paused)
        #expect(await eventually { collector.latest?.state == .paused }, "the paused snapshot never came")
        await starter.resume()
        ticks.restart()
        #expect(await ticks.run(1, starter))
        await starter.reset()
        #expect(await starter.snapshot.frame == 0)
        await starter.stop()
        let seen = try #require(await collector.collected(), "the stream didn't finish")
        #expect(seen.first?.state == .running && seen.first?.bootIsPending == true)
        #expect(seen.contains { $0.reachedShell && !$0.bootIsPending })
        #expect(seen.contains { $0.state == .paused })
        #expect(seen.last?.state == .stopped)
    }
}
