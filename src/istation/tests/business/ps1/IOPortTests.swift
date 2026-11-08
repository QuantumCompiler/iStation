// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessPS1
import BusinessR3000A
import Testing

/// The I/O ports' widths and power-on values. Expected values are ps1-tests' io-access-bitwidth log,
/// recorded on hardware, where psx-spx and it agree (the log's open-bus upper halves aren't modelled),
/// and psx-spx's "Unpredictable Things" write-width table where the log has no row.
@Suite struct IOPortTests {
    let bus = makeMachine().bus
    let pattern: UInt32 = 0x1234_5678

    @Test func aNarrowStoreToA32BitPortWritesTheWholeSourceRegister() throws {
        try bus.store8(0x1F80_10F0, pattern) // DPCR
        #expect(try bus.load32(0x1F80_10F0) == 0x1234_5678)
        try bus.store16(0x1F80_1080, pattern) // DMA0's base: 24 bits
        #expect(try bus.load32(0x1F80_1080) == 0x0034_5678)
        try bus.store8(0x1F80_1074, pattern) // I_MASK: 11 bits
        #expect(try bus.load32(0x1F80_1074) == 0x0000_0678)
        try bus.store8(0x1F80_10F4, pattern) // DICR, its bits 0–5 included
        #expect(try bus.load32(0x1F80_10F4) == 0x0034_0038)
        try bus.store16(0x1F80_1108, pattern) // timer 0's target: 16 bits
        #expect(try bus.load16(0x1F80_1108) == 0x5678)
    }

    @Test func aChannelsBCRTakesANarrowStoreInItsOwnByteLanes() throws {
        // psx-spx: DMAx.LEN is OK at every width, where DMAx.ADDR and CHCR are (w32).
        try bus.store32(0x1F80_10A4, 0x0001_0010)
        try bus.store16(0x1F80_10A4, 0x1234_0020)
        #expect(try bus.load32(0x1F80_10A4) == 0x0001_0020)
        try bus.store16(0x1F80_10A6, 0x2)
        #expect(try bus.load32(0x1F80_10A4) == 0x0002_0020)
        try bus.store8(0x1F80_10A5, 0x1)
        #expect(try bus.load32(0x1F80_10A4) == 0x0002_0120)
    }

    @Test func aNarrowLoadFromA32BitPortReadsItsByteLane() throws {
        try bus.store32(0x1F80_10F0, pattern)
        #expect(try bus.load16(0x1F80_10F2) == 0x1234)
        #expect(try bus.load8(0x1F80_10F1) == 0x56)
    }

    @Test func theCDROMStatusPortIsReadAgainForEachByteOfAWideLoad() throws {
        #expect(try bus.load8(0x1F80_1800) == 0x18)
        #expect(try bus.load32(0x1F80_1800) == 0x1818_1818)
        // A halfword store writes 0x78 and then 0x56 to the same port: the index is 0x56's low bits.
        try bus.store16(0x1F80_1800, pattern)
        #expect(try bus.load32(0x1F80_1800) == 0x1A1A_1A1A)
        try bus.store8(0x1F80_1800, pattern)
        #expect(try bus.load16(0x1F80_1800) == 0x1818)
    }

    @Test func theCDROMsInterruptPortReadsItsFixedBitsInEveryBank() throws {
        // psx-spx: HINTMSK (banks 0 and 2) and HINTSTS (1 and 3) read bits 5–7 as 1.
        for index: UInt32 in 0...3 {
            try bus.store8(0x1F80_1800, index)
            #expect(try bus.load8(0x1F80_1803) == 0xE0)
        }
    }

    @Test func theGPUAndMDECStatusAtPowerOn() throws {
        #expect(try bus.load32(0x1F80_1814) == 0x1480_2000)
        #expect(try bus.load16(0x1F80_1814) == 0x2000)
        #expect(try bus.load8(0x1F80_1814) == 0)
        #expect(try bus.load32(0x1F80_1824) == 0x8004_0000)
        #expect(try bus.load16(0x1F80_1824) == 0)
    }

    @Test func spuRegistersAre16BitsAndSPUSTATFollowsSPUCNT() throws {
        try bus.store8(0x1F80_1DAA, pattern)
        #expect(try bus.load16(0x1F80_1DAA) == 0x5678)
        #expect(try bus.load16(0x1F80_1DAE) == 0x0038)
        try bus.store32(0x1F80_1C00, pattern)
        #expect(try bus.load16(0x1F80_1C02) == 0x1234)
    }

    @Test func aByteStoreToAnOddSPUAddressIsIgnored() throws {
        try bus.store8(0x1F80_1DAB, pattern) // psx-spx's (i16)
        #expect(try bus.load16(0x1F80_1DAA) == 0)
    }

    @Test func thePortsReadIdleWithNothingPluggedIn() throws {
        #expect(try bus.load32(0x1F80_1044) & 0x5 == 0x5) // JOY_STAT: ready to send
        #expect(try bus.load8(0x1F80_1040) == 0xFF)
        try bus.store16(0x1F80_1048, pattern)
        #expect(try bus.load16(0x1F80_1048) == 0x38) // JOY_MODE's defined bits
        try bus.store16(0x1F80_104A, pattern)
        #expect(try bus.load16(0x1F80_104A) == 0) // bit 6 reset JOY_CTRL
        try bus.store16(0x1F80_1058, pattern)
        #expect(try bus.load16(0x1F80_1058) == 0x78)
    }

    @Test func aWordStoreToTheSerialPortsWritesOnlyItsLowHalfword() throws {
        // The log's 32-bit column (psx-spx: CROP).
        for (address, expected) in [(UInt32(0x1F80_1048), UInt32(0x38)), (0x1F80_1058, 0x78)] {
            try bus.store32(address, 0)
            try bus.store32(address, pattern)
            #expect(try bus.load32(address) == expected)
        }
        try bus.store16(0x1F80_104A, 0x3)
        try bus.store32(0x1F80_1048, 0x0040_0000) // bit 6 in the upper half doesn't reach JOY_CTRL
        #expect(try bus.load16(0x1F80_104A) == 0x3)
    }

    @Test func aByteStoreToAnOddSerialAddressIsShiftedLeft() throws {
        // psx-spx's (w16): the source's low halfword, shifted left 8.
        try bus.store16(0x1F80_1048, 0x0D)
        try bus.store8(0x1F80_104B, 0x0743) // JOY_CTRL gets 0x4300: bit 6 lands in bit 14, so no reset
        #expect(try bus.load16(0x1F80_104A) == 0x0300)
        #expect(try bus.load16(0x1F80_1048) == 0x0D)
        try bus.store8(0x1F80_1049, 0x1234_0138)
        #expect(try bus.load16(0x1F80_1048) == 0) // 0x3800 through JOY_MODE's mask
    }

    @Test func serialControlKeepsPSXSPXsBitsAndItsResetClearsThePort() throws {
        // psx-spx: bits 4 and 6 are write-only, 14–15 read 0, and 7 too, but on SIO1 with a baud factor.
        try bus.store16(0x1F80_104A, 0xC0BF)
        #expect(try bus.load16(0x1F80_104A) == 0x002F)
        try bus.store16(0x1F80_105A, 0x0080)
        #expect(try bus.load16(0x1F80_105A) == 0)
        try bus.store16(0x1F80_1058, 0x4E)
        try bus.store16(0x1F80_105A, 0x0080)
        #expect(try bus.load16(0x1F80_105A) == 0x0080)
        // Bit 6 zeroes the port's mode, control and baud, and leaves the other port.
        try bus.store16(0x1F80_1048, 0x0D)
        try bus.store16(0x1F80_104E, 0x88)
        try bus.store16(0x1F80_104A, 0x0003)
        try bus.store16(0x1F80_104A, 0x0040)
        #expect(try bus.load32(0x1F80_1048) == 0)
        #expect(try bus.load16(0x1F80_104E) == 0)
        #expect(try bus.load16(0x1F80_1058) == 0x4E)
    }

    @Test func memoryControlKeepsItsRegistersAndRecomputesTimings() throws {
        try bus.store32(0x1F80_1020, 0x0000_1325)
        #expect(try bus.load32(0x1F80_1020) == 0x0000_1325)
        try bus.store32(0x1F80_1000, 0xFFFF_FFFF)
        #expect(try bus.load32(0x1F80_1000) == 0x1FFF_FFFF) // the base's top byte is fixed
        try bus.store32(0x1F80_1060, 0x0000_0888)
        #expect(try bus.load32(0x1F80_1060) == 0x0000_0888)
        let before = bus.memoryControl.bios
        try bus.store32(0x1F80_1010, 0x0013_24FF) // the BIOS's read delay at its slowest
        #expect(bus.memoryControl.bios.byte > before.byte)
    }

    @Test func memoryControlReadsBackPSXSPXsFixedBits() throws {
        #expect(try bus.load32(0x1F80_1020) == 0x1125) // the usual 0x31125: COM_DELAY's top half reads 0
        try bus.store32(0x1F80_1008, 0x1013_243F) // bit 28 acknowledges an address error
        #expect(try bus.load32(0x1F80_1008) == 0x0013_243F)
        try bus.store32(0xFFFE_0130, 0xFFFF_FFFF)
        #expect(try bus.load32(0xFFFE_0130) == 0xFFFF_FBBF) // BCC's bits 6 and 10 read 0
    }
}
