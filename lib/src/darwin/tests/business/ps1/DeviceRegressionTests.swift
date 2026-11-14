// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessPS1
import BusinessR3000A
import SupportMIPS
import Testing

/// The GPU where review found it trapping or apart from psx-spx ("GPU Display Control Commands",
/// "GPU Status Register", "GPU Timings").
@Suite struct GPURegressionTests {
    @Test func displayMode368CountsTheDotClockBySevenWhateverHDS1Holds() throws {
        let machine = makeMachine()
        // HDS2 with HDS1 = 1: psx-spx's 368 pixels; ProjectPSX's divider table ran past its end and trapped.
        try machine.bus.store32(0x1F80_1814, 0x0800_0041)
        try machine.bus.store32(0x1F80_1104, 0x100) // timer 0 counts the dot clock
        for _ in 0..<100 { machine.runSlice() }
        #expect(machine.cycles == 100 * 100) // the BIOS loop's slices are 100 cycles each
        // psx-spx's NTSC clock makes 10,000 CPU cycles 15,853 video cycles: 2264 dots at 368 pixels'
        // divider of 7, against 1981 at 320's 8 and 3170 at 640's 5. Timer 0 drops each slice's
        // remainder (ProjectPSX's counting, kept until the 3d trace) and reads 2200; the range holds
        // either count and only the divider of 7.
        #expect(try (2100...2300).contains(machine.bus.load16(0x1F80_1100)))
        #expect(try machine.bus.load32(0x1F80_1814) & 0x0007_0000 == 0x0003_0000)
    }

    @Test func anInterlacedNTSCFieldIs262AndAHalfLines() throws {
        let machine = makeMachine()
        try machine.bus.store32(0x1F80_1814, 0x0800_0024) // 480 lines, interlaced
        for _ in 0..<10 { machine.runFrame() }
        // psx-spx: 262.5 lines a field, at the NTSC video clock, 59.940 Hz (within its 3412.5 cycles a
        // line against the 3413 it also gives).
        let expected = 5 * 525 * 3413 * 33_868_800 / 53_693_175
        #expect(abs(Int(machine.cycles) - expected) < 200)
        let rate = 33_868_800 * 10 / Double(machine.cycles)
        #expect(abs(rate - 59.940) < 0.02)
    }

    @Test func theInterlaceFieldBitReadsOneWithoutInterlaceAndAlternatesWithIt() throws {
        let machine = makeMachine()
        try machine.bus.store32(0x1F80_1814, 0x0800_0001) // 320 wide, no interlace
        // psx-spx: bit 13 is always 1 with interlace off on the v2 GPU power-on's 0x14802000 implies.
        #expect(try machine.bus.load32(0x1F80_1814) & 0x2000 != 0)
        machine.runFrame()
        #expect(try machine.bus.load32(0x1F80_1814) & 0x2000 != 0)

        // psx-spx: with GP1(08h).5 set it is the field, at 480 lines and at 240 alike.
        for mode: UInt32 in [0x0800_0024, 0x0800_0020] { // 480 lines interlaced, then 240
            try machine.bus.store32(0x1F80_1814, mode)
            var fields: [Bool] = []
            for _ in 0..<4 {
                machine.runFrame()
                fields.append(try machine.bus.load32(0x1F80_1814) & 0x2000 != 0)
            }
            #expect(fields[0] != fields[1] && fields[1] != fields[2] && fields[2] != fields[3])
        }
    }

    @Test func gpustatBit31ReadsZeroInTheVerticalBlank() throws {
        let machine = makeMachine()
        var oddInBlank = 0, oddInDisplay = 0
        for _ in 0..<6000 { // about a frame
            machine.runSlice()
            let odd = try machine.bus.load32(0x1F80_1814) & 0x8000_0000 != 0
            let line = machine.bus.gpu.scanline
            // psx-spx: "always zero during Vblank (vertical retrace and upper/lower screen border)",
            // outside GP1(07h)'s Y1 = 10h to Y2 = 100h after reset.
            if line < 0x10 || line > 0x100 {
                if odd { oddInBlank += 1 }
            } else if odd {
                oddInDisplay += 1
            }
        }
        #expect(oddInBlank == 0)
        #expect(oddInDisplay > 0)
    }

    @Test func gp1CommandsFrom40hMirrorTheFirst64() throws {
        let bus = makeMachine().bus
        // psx-spx: GP1(40h..FFh) are mirrors of GP1(00h..3Fh).
        try bus.store32(0x1F80_1814, 0x4800_0001) // GP1(08h)'s mirror: 320 wide
        #expect(try bus.load32(0x1F80_1814) & 0x0007_0000 == 0x0002_0000)
        try bus.store32(0x1F80_1814, 0xC300_0000) // GP1(03h)'s: display on
        #expect(try bus.load32(0x1F80_1814) & 0x0080_0000 == 0)
    }
}

/// The DMA controller where review found it apart from psx-spx ("DMA Channels", "Memory Map").
@Suite struct DMARegressionTests {
    static let dpcrOTC: UInt32 = 0x0765_4321 | 0x0800_0000
    static let dpcrGPU: UInt32 = 0x0765_4321 | 0x0000_0800
    static let dpcrSPU: UInt32 = 0x0765_4321 | 0x0008_0000

    /// Starts OTC on a four-entry ordering table from `base` down, with DICR set to `dicr` first.
    func clearOrderingTable(_ bus: PS1Bus, base: UInt32 = 0x0010_0010, dicr: UInt32 = 0) throws {
        try bus.store32(0x1F80_10F0, Self.dpcrOTC)
        try bus.store32(0x1F80_10F4, dicr)
        try bus.store32(0x1F80_10E0, base)
        try bus.store32(0x1F80_10E4, 4)
        try bus.store32(0x1F80_10E8, 0x1100_0002)
    }

    func dmaRequested(_ bus: PS1Bus) throws -> Bool {
        try bus.load32(0x1F80_1070) & Interrupt.dma.rawValue != 0
    }

    @Test func eachChannelsControlRegisterIsMirroredFourBytesOn() throws {
        let bus = makeMachine().bus
        // psx-spx: "The seven DMA Control Registers at 1F8010x8h are mirrored to 1F8010xCh".
        try bus.store32(0x1F80_10A8, 0x0000_0201) // GPU: not started
        #expect(try bus.load32(0x1F80_10AC) == 0x0000_0201)
        try bus.store32(0x1F80_10AC, 0x0000_0401)
        #expect(try bus.load32(0x1F80_10A8) == 0x0000_0401)
    }

    @Test func otcsControlRegisterKeepsOnlyBits24_28And30() throws {
        let bus = makeMachine().bus
        // psx-spx: "D6_CHCR has only three read/write-able bits: 24,28,30", and bit 1 is always 1,
        // before any write too, at 1F8010E8h and its mirror 1F8010ECh.
        #expect(try bus.load32(0x1F80_10E8) == 0x0000_0002)
        #expect(try bus.load32(0x1F80_10EC) == 0x0000_0002)
        try bus.store32(0x1F80_10E8, 0x1100_0002) // DPCR leaves OTC off: it stays busy
        #expect(try bus.load32(0x1F80_10E8) == 0x1100_0002)
        try bus.store32(0x1F80_10E8, 0x7FFF_FFFF)
        #expect(try bus.load32(0x1F80_10E8) == 0x5100_0002)
        try bus.store32(0x1F80_10E8, 0)
        #expect(try bus.load32(0x1F80_10E8) == 0x0000_0002)

        // A linked-list mode can't be set: OTC waits for its trigger and MADR stays.
        try bus.store32(0x1F80_10F0, Self.dpcrOTC)
        try bus.store32(0x1F80_10E0, 0x0010_0010)
        try bus.store32(0x1F80_10E8, 0x0100_0401)
        #expect(try bus.load32(0x1F80_10E8) == 0x0100_0002)
        #expect(try bus.load32(0x1F80_10E0) == 0x0010_0010)
    }

    @Test func otcKeepsMADRAndWritesNothingPastAddress0() throws {
        let bus = makeMachine().bus
        try bus.store32(0x801F_FFFC, 0x1234_5678)
        try clearOrderingTable(bus, base: 0x0000_0008)
        #expect(try bus.load32(0x8000_0008) == 0x0000_0004)
        #expect(try bus.load32(0x8000_0004) == 0x0000_0000)
        // psx-spx: the address wraps from 000000h to FFFFFCh, past RAM, and the words after it aren't
        // written: not the end marker, and not the top of RAM.
        #expect(try bus.load32(0x8000_0000) == 0x00FF_FFFC)
        #expect(try bus.load32(0x801F_FFFC) == 0x1234_5678)
        // psx-spx: sync mode 0 leaves MADR at its start, and BCR as written.
        #expect(try bus.load32(0x1F80_10E0) == 0x0000_0008)
        #expect(try bus.load32(0x1F80_10E4) == 4)
    }

    @Test func aLinkedListLeavesMADRHoldingTheEndMarker() throws {
        let bus = makeMachine().bus
        try bus.store32(0x8000_1000, 0x0100_2000) // one word, then the node at 0x2000
        try bus.store32(0x8000_1004, 0x0000_0000)
        try bus.store32(0x8000_2000, 0x00FF_FFFF) // the end
        try bus.store32(0x1F80_10F0, Self.dpcrGPU)
        try bus.store32(0x1F80_10A0, 0x0000_1000)
        try bus.store32(0x1F80_10A8, 0x0100_0401)
        #expect(try bus.load32(0x1F80_10A0) == 0x00FF_FFFF) // psx-spx: "the end marker in SyncMode=2"
        #expect(try bus.load32(0x1F80_10A8) == 0x0000_0401) // done
    }

    @Test func syncMode1CountsBlocksDownAndMovesMADRBlockByBlock() throws {
        let machine = makeMachine(), bus = machine.bus
        try bus.store32(0x1F80_10F0, Self.dpcrSPU)
        try bus.store32(0x1F80_10C0, 0x0000_1000)
        try bus.store32(0x1F80_10C4, 0x0002_0004) // two blocks of four words
        try bus.store32(0x1F80_10C8, 0x0100_0201) // from RAM, sync mode 1, start
        // psx-spx: MADR holds the next block's start, and BA counts down to zero.
        #expect(try bus.load32(0x1F80_10C0) == 0x0000_1010)
        #expect(try bus.load32(0x1F80_10C4) == 0x0001_0004)
        #expect(try bus.load32(0x1F80_10C8) == 0x0100_0201)
        machine.runSlice()
        #expect(try bus.load32(0x1F80_10C0) == 0x0000_1020) // the end address
        #expect(try bus.load32(0x1F80_10C4) == 0x0000_0004)
        #expect(try bus.load32(0x1F80_10C8) == 0x0000_0201)
    }

    @Test func aBlockSizeOrCountOf0Means10000h() throws {
        let machine = makeMachine(), bus = machine.bus
        try bus.store32(0x1F80_10F0, Self.dpcrSPU)
        // psx-spx: "BC/BS/BA can be in range 0001h..FFFFh (or 0=10000h)".
        try bus.store32(0x1F80_10C0, 0x0000_1000)
        try bus.store32(0x1F80_10C4, 0x0001_0000) // one block of 10000h words
        try bus.store32(0x1F80_10C8, 0x0100_0201)
        #expect(try bus.load32(0x1F80_10C0) == 0x0004_1000)
        #expect(try bus.load32(0x1F80_10C8) == 0x0000_0201)

        try bus.store32(0x1F80_10C4, 0x0000_0001) // 10000h blocks of a word: counting down, not stuck
        try bus.store32(0x1F80_10C8, 0x0100_0201)
        #expect(try bus.load32(0x1F80_10C4) == 0xFFFF_0001)
        machine.runSlice()
        #expect(try bus.load32(0x1F80_10C4) == 0xFFFE_0001)
        #expect(try bus.load32(0x1F80_10C8) == 0x0100_0201)
    }

    @Test func theAllAtOnceTransfersEndLikeTheirBlocks() throws {
        let bus = makeMachine().bus
        try bus.store32(0x1F80_10F0, Self.dpcrGPU)
        try bus.store32(0x1F80_10A0, 0x001F_F000)
        try bus.store32(0x1F80_10A4, 0x0100_0010) // 256 blocks of 16 words, on past 2 MB into the mirror
        try bus.store32(0x1F80_10A8, 0x0100_0201)
        // psx-spx: MADR ends at the end address, and BA at 0.
        #expect(try bus.load32(0x1F80_10A0) == 0x0020_3000)
        #expect(try bus.load32(0x1F80_10A4) == 0x0000_0010)
        #expect(try bus.load32(0x1F80_10A8) == 0x0000_0201)
    }

    @Test func noStoreMovesMoreThan10000hWords() throws {
        let machine = makeMachine(), bus = machine.bus
        try bus.store32(0x1F80_10F0, Self.dpcrGPU | 0x8) // GPU and MDEC in
        // 1001h blocks of 16 words: the store moves the first 1000h (10000h words), the next tick the last.
        try bus.store32(0x1F80_10A0, 0x0000_1000)
        try bus.store32(0x1F80_10A4, 0x1001_0010)
        try bus.store32(0x1F80_10A8, 0x0100_0201)
        #expect(try bus.load32(0x1F80_10A0) == 0x0004_1000)
        #expect(try bus.load32(0x1F80_10A4) == 0x0001_0010)
        #expect(try bus.load32(0x1F80_10A8) == 0x0100_0201) // still busy
        machine.runSlice()
        #expect(try bus.load32(0x1F80_10A0) == 0x0004_1040)
        #expect(try bus.load32(0x1F80_10A4) == 0x0000_0010)
        #expect(try bus.load32(0x1F80_10A8) == 0x0000_0201)

        // 10000h × 10000h words (BS = BA = 0) to MDEC in: a block a store or tick, not 2³² words at once.
        try bus.store32(0x1F80_1080, 0x0000_1000)
        try bus.store32(0x1F80_1084, 0)
        try bus.store32(0x1F80_1088, 0x0100_0201)
        #expect(try bus.load32(0x1F80_1080) == 0x0004_1000)
        #expect(try bus.load32(0x1F80_1084) == 0xFFFF_0000)
        machine.runSlice()
        #expect(try bus.load32(0x1F80_1080) == 0x0008_1000)
        #expect(try bus.load32(0x1F80_1084) == 0xFFFE_0000)
        #expect(try bus.load32(0x1F80_1088) == 0x0100_0201)
    }

    @Test func aTransferWalksMemoryByItsStep() throws {
        let bus = makeMachine().bus
        for address: UInt32 in [0x8000_0FF0, 0x8000_0FF4, 0x8000_1000, 0x8000_1004] { try bus.store32(address, 0xAAAA_AAAA) }
        try bus.store32(0x1F80_10F0, Self.dpcrGPU)
        try bus.store32(0x1F80_10A0, 0x0000_1000)
        try bus.store32(0x1F80_10A4, 0x0001_0004)
        try bus.store32(0x1F80_10A8, 0x0100_0202) // GPU to RAM, step −4 (psx-spx: CHCR bit 1), sync mode 1
        #expect(try bus.load32(0x8000_1004) == 0xAAAA_AAAA)
        #expect(try bus.load32(0x8000_1000) == 0) // GPUREAD's 0, at 1000h, FFCh, FF8h and FF4h
        #expect(try bus.load32(0x8000_0FF4) == 0)
        #expect(try bus.load32(0x8000_0FF0) == 0xAAAA_AAAA)
        #expect(try bus.load32(0x1F80_10A0) == 0x0000_0FF0)
    }

    @Test func dicrsMasterFlagAndItsInterruptFollowPsxSpx() throws {
        let machine = makeMachine(), bus = machine.bus
        // psx-spx: a completion sets its flag only with both its enable bit and bit 23.
        try clearOrderingTable(bus, dicr: 0x0040_0000)
        #expect(try bus.load32(0x1F80_10F4) == 0x0040_0000)
        try clearOrderingTable(bus, dicr: 0x00C0_0000)
        #expect(try bus.load32(0x1F80_10F4) == 0xC0C0_0000)
        machine.runSlice()
        #expect(try dmaRequested(bus)) // bit 31 rose
        try bus.store32(0x1F80_1070, 0)

        // psx-spx: bit 31 is b15 or (b23 and any flag); a channel's enable bit doesn't count.
        try bus.store32(0x1F80_10F4, 0x0080_0000)
        #expect(try bus.load32(0x1F80_10F4) == 0xC080_0000)

        // Only a 0-to-1 transition requests the interrupt: a completion while bit 31 is set doesn't...
        try bus.store32(0x1F80_10F4, 0x00C0_0000)
        try bus.store32(0x1F80_10E8, 0x1100_0002)
        machine.runSlice()
        #expect(try !dmaRequested(bus))

        // ...and a write that raises it does, from bit 23 with a flag pending...
        try bus.store32(0x1F80_10F4, 0x0040_0000)
        #expect(try bus.load32(0x1F80_10F4) == 0x4040_0000)
        try bus.store32(0x1F80_10F4, 0x00C0_0000)
        machine.runSlice()
        #expect(try dmaRequested(bus))

        // ...or from bit 15 alone.
        try bus.store32(0x1F80_10F4, 0x7F00_0000) // acknowledge every flag
        try bus.store32(0x1F80_1070, 0)
        try bus.store32(0x1F80_10F4, 0x0000_8000)
        #expect(try bus.load32(0x1F80_10F4) == 0x8000_8000)
        machine.runSlice()
        #expect(try dmaRequested(bus))
    }
}

/// Expansion 2's TTY, which a guest can write without end.
@Suite struct TTYRegressionTests {
    @Test func theTTYKeepsItsMostRecentMegabyte() {
        let machine = makeMachine()
        let total = Expansion2.ttyCapacity + 300
        machine.load(makeEXE([
            MIPS.lui(t0, 0x1F80), MIPS.ori(s0, zero, 0),
            MIPS.lui(s1, total >> 16), MIPS.ori(s1, s1, total & 0xFFFF),
            MIPS.sb(s0, 0x2023, t0), MIPS.addiu(s0, s0, 1), MIPS.bne(s0, s1, -3), MIPS.nop, // a byte a count
        ] + halt))
        machine.run(cycles: UInt64(total) * 5)
        let output = machine.bus.expansion2.output
        #expect(output.count == Expansion2.ttyCapacity)
        #expect(output.first == UInt8(truncatingIfNeeded: 300)) // the 300 oldest bytes are gone
        #expect(output.enumerated().allSatisfy { $0.element == UInt8(truncatingIfNeeded: 300 + $0.offset) })
    }
}
