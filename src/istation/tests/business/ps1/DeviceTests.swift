// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessPS1
import BusinessR3000A
import SupportMIPS
import Testing

/// The interrupt controller (psx-spx, "Interrupts").
@Suite struct InterruptControllerTests {
    @Test func aRequestReachesTheCPUOnlyWhenUnmasked() throws {
        let bus = makeMachine().bus
        bus.interrupts.request(.timer1)
        #expect(try bus.load32(0x1F80_1070) == 0x20)
        #expect(!bus.interruptPending)
        try bus.store32(0x1F80_1074, 0xFFFF_FFFF)
        #expect(try bus.load32(0x1F80_1074) == 0x7FF)
        #expect(bus.interruptPending)
    }

    @Test func writingIStatAcknowledgesTheZeroBits() throws {
        let bus = makeMachine().bus
        bus.interrupts.request(.vblank)
        bus.interrupts.request(.dma)
        try bus.store32(0x1F80_1070, ~Interrupt.vblank.rawValue)
        #expect(try bus.load32(0x1F80_1070) == Interrupt.dma.rawValue)
    }

    @Test func theCPUTakesTheVerticalBlankEveryFrame() throws {
        let machine = makeMachine()
        // The handler: acknowledge everything, count, return.
        machine.bus.copyToRAM(bytes([
            MIPS.lui(k0, 0x1F80), MIPS.sw(zero, 0x1070, k0), MIPS.addiu(s1, s1, 1),
            MIPS.mfc0(k1, UInt32(COP0Register.epc)), MIPS.nop, MIPS.jr(k1), MIPS.rfe,
        ]), at: 0x8000_0080)
        machine.load(makeEXE([
            MIPS.lui(k0, 0x1F80), MIPS.ori(t0, zero, 1), MIPS.sw(t0, 0x1074, k0), // I_MASK: the vertical blank
            MIPS.ori(t0, zero, 0x401), MIPS.mtc0(t0, UInt32(COP0Register.sr)), // IM2, IEc
        ] + halt))
        for _ in 0..<3 { machine.runFrame() }
        machine.runSlice() // the third handler runs
        #expect(machine.cpu.register(Int(s1)) == 3)
        #expect(machine.frame == 3)
    }
}

/// The root counters (psx-spx, "Timers").
@Suite struct TimerTests {
    @Test func timer2CountsTheSystemClockOrAnEighthOfIt() throws {
        let machine = makeMachine()
        try machine.bus.store32(0x1F80_1124, 0) // timer 2's mode: system clock; resets the counter
        var start = machine.cycles
        machine.run(cycles: 1000)
        #expect(UInt64(try machine.bus.load16(0x1F80_1120)) == machine.cycles - start)

        try machine.bus.store32(0x1F80_1124, 0x200) // system clock / 8
        start = machine.cycles
        machine.run(cycles: 4000)
        #expect(UInt64(try machine.bus.load16(0x1F80_1120)) == (machine.cycles - start) / 8)
    }

    @Test func reachingTheTargetResetsTheCounterAndRequestsTheInterrupt() throws {
        let machine = makeMachine()
        try machine.bus.store32(0x1F80_1108, 500) // timer 0's target
        try machine.bus.store32(0x1F80_1104, 0x58) // reset on target, IRQ on target, repeat
        machine.run(cycles: 5000)
        #expect(try machine.bus.load32(0x1F80_1070) & Interrupt.timer0.rawValue != 0)
        #expect(try machine.bus.load16(0x1F80_1100) < 500 + 200)
        // Reading the mode reports, then clears, "reached the target".
        #expect(try machine.bus.load32(0x1F80_1104) & 0x800 != 0)
        #expect(try machine.bus.load32(0x1F80_1104) & 0x800 == 0)
    }

    @Test func aTargetIs16Bits() throws {
        let bus = makeMachine().bus
        try bus.store32(0x1F80_1118, 0x0001_2345)
        #expect(try bus.load32(0x1F80_1118) == 0x2345)
    }
}

/// The DMA controller (psx-spx, "DMA Channels").
@Suite struct DMATests {
    /// Starts OTC to clear a four-entry ordering table ending at 0x100010.
    func clearOrderingTable(_ bus: PS1Bus, dicr: UInt32 = 0) throws {
        try bus.store32(0x1F80_10F0, 0x0765_4321 | 0x0800_0000) // DPCR: OTC enabled
        try bus.store32(0x1F80_10F4, dicr)
        try bus.store32(0x1F80_10E0, 0x0010_0010)
        try bus.store32(0x1F80_10E4, 4)
        try bus.store32(0x1F80_10E8, 0x1100_0002) // start, trigger, backwards
    }

    @Test func dpcrPowersOnWithEachChannelsPriority() throws {
        #expect(try makeMachine().bus.load32(0x1F80_10F0) == 0x0765_4321)
    }

    @Test func otcClearsAnOrderingTableDownwardsToItsEndMarker() throws {
        let bus = makeMachine().bus
        try clearOrderingTable(bus)
        #expect(try bus.load32(0x8010_0010) == 0x0010_000C)
        #expect(try bus.load32(0x8010_000C) == 0x0010_0008)
        #expect(try bus.load32(0x8010_0008) == 0x0010_0004)
        #expect(try bus.load32(0x8010_0004) == 0x00FF_FFFF)
        #expect(try bus.load32(0x1F80_10E8) == 0x2) // finished: only OTC's fixed bit
    }

    @Test func aChannelsCompletionFlagNeedsItsEnableAndRequestsTheInterrupt() throws {
        let enabled = makeMachine()
        try clearOrderingTable(enabled.bus, dicr: 0x0080_0000 | 0x0040_0000) // master enable, OTC enable
        #expect(try enabled.bus.load32(0x1F80_10F4) & 0xC000_0000 == 0xC000_0000) // its flag, the master flag
        enabled.runSlice()
        #expect(try enabled.bus.load32(0x1F80_1070) & Interrupt.dma.rawValue != 0)
        try enabled.bus.store32(0x1F80_10F4, 0x0080_0000 | 0x0040_0000 | 0x4000_0000) // acknowledge it
        #expect(try enabled.bus.load32(0x1F80_10F4) & 0xC000_0000 == 0)

        let disabled = makeMachine()
        try clearOrderingTable(disabled.bus, dicr: 0x0080_0000)
        #expect(try disabled.bus.load32(0x1F80_10F4) & 0xC000_0000 == 0)
    }

    @Test func aChannelTheMasterEnableLeavesOffDoesNotStart() throws {
        let bus = makeMachine().bus
        try bus.store32(0x8010_0004, 0xAAAA_AAAA)
        try bus.store32(0x1F80_10E0, 0x0010_0004)
        try bus.store32(0x1F80_10E4, 1)
        try bus.store32(0x1F80_10E8, 0x1100_0002) // DPCR still has OTC off
        #expect(try bus.load32(0x8010_0004) == 0xAAAA_AAAA)
    }
}

/// The GPU's timing and status (psx-spx, "GPU Timings", "GPU Display Control Commands").
@Suite struct GPUTests {
    @Test func anNTSCFrameIs263LinesOf3413VideoCycles() {
        let machine = makeMachine()
        for _ in 0..<10 { machine.runFrame() }
        let expected = 10 * 263 * 3413 * 7 / 11 // CPU cycles: the video clock is 11/7 of the CPU's
        #expect(abs(Int(machine.cycles) - expected) < 200)
        #expect(machine.frame == 10)
    }

    @Test func everyFrameRequestsTheVerticalBlank() throws {
        let machine = makeMachine()
        machine.runFrame()
        #expect(try machine.bus.load32(0x1F80_1070) & Interrupt.vblank.rawValue != 0)
    }

    @Test func theDisplayCommandsSetGPUSTAT() throws {
        let bus = makeMachine().bus
        try bus.store32(0x1F80_1814, 0x0300_0000) // display on
        #expect(try bus.load32(0x1F80_1814) & 0x0080_0000 == 0)
        try bus.store32(0x1F80_1814, 0x0400_0002) // DMA direction: CPU to GPU
        #expect(try bus.load32(0x1F80_1814) & 0x6200_0000 == 0x4200_0000) // direction 2, and its request bit
        try bus.store32(0x1F80_1814, 0x0800_0009) // display mode: 320 wide, PAL
        #expect(try bus.load32(0x1F80_1814) & 0x0017_0000 == 0x0012_0000)
        try bus.store32(0x1F80_1814, 0) // reset
        #expect(try bus.load32(0x1F80_1814) & 0x7FFF_FFFF == 0x1480_2000)
    }
}
