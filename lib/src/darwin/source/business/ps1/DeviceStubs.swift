// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2019 Pedro Cortés
// SPDX-FileCopyrightText: 2026 iStation contributors
// Ported from BluestormDNA/ProjectPSX/ProjectPSX/Core/BUS.cs — Copyright (c) 2019 Pedro Cortés
// Ported from BluestormDNA/ProjectPSX/ProjectPSX/Devices/Input/JOYPAD.cs — Copyright (c) 2019 Pedro Cortés

// The devices the BIOS touches but v0.0.1 doesn't emulate, each answering as psx-spx documents its
// power-on state: what the BIOS asks of them is read from ProjectPSX's and SwanStation's traces (3d)
// before any of them does more. CD-ROM commands, SPU sound, MDEC decoding and the pads are v0.2.0's.

// Their stored `var`s are unchecked: a load from the device reads them (ADR 0015 §4).

/// The CD-ROM controller's four byte-wide ports, 0x1F801800–0x1F801803: the status register and its
/// index; no disc, no commands, no interrupts.
public final class CDROMStub {
    /// The register bank the index selects (bits 0–1 of a write to 0x1F801800).
    @exclusivity(unchecked) public private(set) var index: UInt8 = 0

    public init() {}

    /// The status register: parameter FIFO empty (bit 3) and not full (bit 4), nothing busy, and the
    /// index. Port 3 is HINTMSK in banks 0 and 2 and HINTSTS in banks 1 and 3: no interrupt enabled or
    /// flagged, and bits 5–7, which psx-spx says always read 1.
    func read(_ port: UInt32) -> UInt8 {
        switch port {
        case 0: 0x18 | index
        case 3: 0xE0
        default: 0
        }
    }

    func write(_ port: UInt32, _ value: UInt8) {
        if port == 0 { index = value & 0x3 }
    }
}

/// The SPU's 16-bit registers, 0x1F801C00–0x1F801FFF, kept as written. SPUSTAT's mode bits follow
/// SPUCNT's (psx-spx), which the BIOS waits for.
public final class SPUStub {
    @exclusivity(unchecked) var registers = [UInt16](repeating: 0, count: 0x200)

    public init() {}

    static let control: UInt32 = 0x1AA
    static let status: UInt32 = 0x1AE

    /// The register at `offset`, wrapped into the 512 so no offset reaches past them.
    static func index(_ offset: UInt32) -> Int { Int(offset >> 1) & 0x1FF }

    func read(_ offset: UInt32) -> UInt16 {
        let index = Self.index(offset)
        return index == Self.index(Self.status) ? registers[Self.index(Self.control)] & 0x3F : registers[index]
    }

    func write(_ offset: UInt32, _ value: UInt16) {
        registers[Self.index(offset)] = value
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

/// The controller and serial ports, 0x1F801040–0x1F80105F, with nothing plugged in. A byte sent through
/// the controller port comes back as 0xFF with no acknowledge, as ProjectPSX's JOYPAD answers when no
/// device responds (psx-spx: an unconnected port reads FFh) — at once, where hardware takes the baud
/// rate's time; SIO1's stat reads idle; the rest keep what is written, through psx-spx's read masks.
public final class PortsStub {
    @exclusivity(unchecked) var registers = [UInt16](repeating: 0, count: 0x10)
    /// JOY_STAT bit 1, RX FIFO not empty: set by a byte sent, cleared by reading JOY_RX_DATA.
    @exclusivity(unchecked) var joyReceived = false
    /// JOY_STAT bit 2, TX ready 2: a byte sent completes only with JOY_CTRL's /JOYn output (bit 1) on.
    @exclusivity(unchecked) var joySent = true

    public init() {}

    /// The halfword register at `offset`, wrapped into the 16 so no offset reaches past them.
    static func index(_ offset: UInt32) -> Int { Int(offset >> 1) & 0xF }

    /// The 32-bit slot at `offset`: two halfword registers, or a stat or data register.
    func read(_ offset: UInt32) -> UInt32 {
        switch offset {
        case 0x00: // JOY_RX_DATA: nothing answers, and the byte is taken
            joyReceived = false
            return 0xFF
        case 0x04: // JOY_STAT: TX ready 1 always; no acknowledge, no interrupt
            return 0x1 | (joyReceived ? 0x2 : 0) | (joySent ? 0x4 : 0)
        case 0x14: return 0x0000_0805 // SIO_STAT, as ProjectPSX hard-codes it
        default: return UInt32(registers[Self.index(offset)]) | UInt32(registers[Self.index(offset + 2)]) << 16
        }
    }

    /// The halfword register at `offset`.
    func write(_ offset: UInt32, _ value: UInt16) {
        switch offset {
        case 0x00: // JOY_TX_DATA: the exchange happens at once, and an empty port answers 0xFF
            joyReceived = true
            joySent = registers[5] & 0x2 != 0
        case 0x08: registers[4] = value & 0x013F // JOY_MODE's defined bits
        case 0x18: registers[0xC] = value & 0x00FF // SIO_MODE's (ProjectPSX's SIO1 keeps every bit)
        case 0x0A, 0x1A:
            // JOY_CTRL and SIO_CTRL (psx-spx). Bit 6 resets the port's mode, control and baud registers:
            // psx-spx's "most registers", which ProjectPSX's JOYPAD names. It and the acknowledge bit 4
            // are write-only, and bits 14–15 read 0, as does bit 7 but on SIO1 while its baud factor
            // (mode bits 0–1) is non-zero. ProjectPSX's SIO1 is plain memory: no reset, no read masks.
            let port = Int(offset & 0x10) >> 1
            if value & 0x40 != 0 {
                registers[port + 4] = 0
                registers[port + 5] = 0
                registers[port + 7] = 0
                if port == 0 {
                    joyReceived = false
                    joySent = true
                }
            } else {
                let keepsBit7 = offset == 0x1A && registers[0xC] & 0x3 != 0
                registers[port + 5] = value & (keepsBit7 ? 0x3FAF : 0x3F2F)
            }
        default: registers[Self.index(offset)] = value
        }
    }
}
