// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

#if PERSONAL_BUILD
import BusinessPS1
import BusinessSession
import Testing

/// What a personal build's session adds: the tracing console's instructions run, its debug snapshot,
/// and the BIOS's putchar captured when asked (6a, for 5f's Tools and drawer).
@Suite struct PersonalSessionTests {
    let clock = ManualClock()

    @Test func instructionsGrowFrameByFrame() async throws {
        let session = ConsoleSession(clock: clock)
        #expect(await session.snapshot.instructions == 0)
        try await session.powerOn(bios: shellBIOS(), exe: okEXE)
        #expect(await session.snapshot.instructions == 0) // powered on, nothing run yet
        var ticks = Ticks(clock)
        var counts: [UInt64] = []
        for _ in 0..<3 {
            #expect(await ticks.run(1, session))
            counts.append(await session.snapshot.instructions)
        }
        #expect(counts[0] > 0)
        #expect(counts[1] > counts[0] && counts[2] > counts[1])
        await session.reset()
        #expect(await session.snapshot.instructions == 0) // a fresh machine counts from zero
        await session.stop()
    }

    @Test func theDebugSnapshotIsThereOncePoweredOn() async throws {
        let session = ConsoleSession(clock: clock)
        #expect(await session.snapshot.debugSnapshot == nil)
        try await session.powerOn(bios: shellBIOS(printing: "BIOS "), exe: okEXE)
        let powered = try #require(await session.snapshot.debugSnapshot)
        #expect(powered.frame == 0)
        #expect(powered.pc == 0xBFC0_0000) // the reset vector
        var ticks = Ticks(clock)
        #expect(await ticks.run(2, session))
        let snapshot = await session.snapshot
        let debug = try #require(snapshot.debugSnapshot)
        #expect(debug.frame == snapshot.frame)
        #expect(debug.tty == "BIOS OK")
        #expect(debug.ttySinceEXE == "OK")
        #expect(debug.cycles > 0)
        await session.stop()
        #expect(await session.snapshot.debugSnapshot == debug) // the last values, kept once stopped
    }

    @Test func putcharIsHeardOnlyWhenCaptured() async throws {
        let captured = ConsoleSession(clock: clock)
        try await captured.powerOn(bios: putcharBIOS(), capturesBIOSPutchar: true)
        var ticks = Ticks(clock)
        #expect(await ticks.run(1, captured))
        #expect(await captured.snapshot.debugSnapshot?.tty == "A")
        let plainClock = ManualClock()
        let unheard = ConsoleSession(clock: plainClock)
        try await unheard.powerOn(bios: putcharBIOS())
        var plainTicks = Ticks(plainClock)
        #expect(await plainTicks.run(1, unheard))
        #expect(await unheard.snapshot.debugSnapshot?.tty == "")
        // Reset powers on as it was powered on: still captured.
        await captured.reset()
        ticks.restart()
        #expect(await ticks.run(1, captured))
        #expect(await captured.snapshot.debugSnapshot?.tty == "A")
        await captured.stop()
        await unheard.stop()
    }
}
#endif
