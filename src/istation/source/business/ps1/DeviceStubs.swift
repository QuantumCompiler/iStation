// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2019 Pedro Cortés
// SPDX-FileCopyrightText: 2026 iStation contributors
// Ported from BluestormDNA/ProjectPSX/ProjectPSX/Core/BUS.cs — Copyright (c) 2019 Pedro Cortés

// The devices the BIOS touches but v0.0.1 doesn't emulate, each answering as psx-spx documents its
// power-on state: what the BIOS asks of them is read from ProjectPSX's and SwanStation's traces (3d)
// before any of them does more. CD-ROM commands, SPU sound, MDEC decoding and the pads are v0.2.0's.

/// The CD-ROM controller's four byte-wide ports, 0x1F801800–0x1F801803: the status register and its
/// index; no disc, no commands, no interrupts.
public final class CDROMStub {
    /// The register bank the index selects (bits 0–1 of a write to 0x1F801800).
    public private(set) var index: UInt8 = 0

    public init() {}

    /// The status register: parameter FIFO empty (bit 3) and not full (bit 4), nothing busy, and the index.
    func read(_ port: UInt32) -> UInt8 {
        port == 0 ? 0x18 | index : 0
    }

    func write(_ port: UInt32, _ value: UInt8) {
        if port == 0 { index = value & 0x3 }
    }
}

/// The SPU's 16-bit registers, 0x1F801C00–0x1F801FFF, kept as written. SPUSTAT's mode bits follow
/// SPUCNT's (psx-spx), which the BIOS waits for.
public final class SPUStub {
    var registers = [UInt16](repeating: 0, count: 0x200)

    public init() {}

    static let control: UInt32 = 0x1AA
    static let status: UInt32 = 0x1AE

    func read(_ offset: UInt32) -> UInt16 {
        if offset == Self.status { return registers[Int(Self.control >> 1)] & 0x3F }
        return registers[Int(offset >> 1)]
    }

    func write(_ offset: UInt32, _ value: UInt16) {
        registers[Int(offset >> 1)] = value
    }

    /// A DMA transfer to the SPU's RAM: accepted and dropped until v0.2.0.
    func receive(_ words: UnsafeBufferPointer<UInt32>) {}
}

/// The MDEC's two ports, 0x1F801820 and 0x1F801824: its status after reset (data-out FIFO empty, no
/// block), and nothing decoded.
public final class MDECStub {
    public init() {}

    func read(_ offset: UInt32) -> UInt32 { offset == 4 ? 0x8004_0000 : 0 }

    func write(_ offset: UInt32, _ value: UInt32) {}
}

/// The controller and serial ports, 0x1F801040–0x1F80105F, with nothing plugged in: the stat
/// registers report idle and the data register reads 0xFF; the rest keep what is written, through
/// psx-spx's read masks.
public final class PortsStub {
    var registers = [UInt16](repeating: 0, count: 0x10)

    public init() {}

    /// The 32-bit slot at `offset`: two halfword registers, or a stat or data register.
    func read(_ offset: UInt32) -> UInt32 {
        switch offset {
        case 0x00: 0xFF // JOY_RX_DATA: nothing answers
        case 0x04: 0x0000_0005 // JOY_STAT: both TX-ready flags set
        case 0x14: 0x0000_0805 // SIO_STAT, as ProjectPSX hard-codes it
        default: UInt32(registers[Int(offset >> 1)]) | UInt32(registers[Int(offset >> 1) + 1]) << 16
        }
    }

    /// The halfword register at `offset`.
    func write(_ offset: UInt32, _ value: UInt16) {
        switch offset {
        case 0x08: registers[4] = value & 0x013F // JOY_MODE's defined bits
        case 0x18: registers[0xC] = value & 0x00FF // SIO_MODE's
        case 0x0A, 0x1A:
            // JOY_CTRL and SIO_CTRL: bit 6 resets the register; it and the acknowledge bit 4 read 0.
            registers[Int(offset >> 1)] = value & 0x40 != 0 ? 0 : value & ~UInt16(0x50)
        default: registers[Int(offset >> 1)] = value
        }
    }
}
