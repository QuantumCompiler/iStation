// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2019 Pedro Cortés
// SPDX-FileCopyrightText: 2026 iStation contributors
// Ported from BluestormDNA/ProjectPSX/ProjectPSX/Devices/InterruptController.cs — Copyright (c) 2019 Pedro Cortés

/// The PS1's interrupt sources, as I_STAT and I_MASK number them (psx-spx, "Interrupts").
public enum Interrupt: UInt32, Sendable {
    case vblank = 0x001
    case gpu = 0x002
    case cdrom = 0x004
    case dma = 0x008
    case timer0 = 0x010
    case timer1 = 0x020
    case timer2 = 0x040
    case controller = 0x080
    case sio = 0x100
    case spu = 0x200
    case lightpen = 0x400
}

/// I_STAT (0x1F801070) and I_MASK (0x1F801074). The line to the CPU's IP2 is up while a requested
/// interrupt is unmasked.
public final class InterruptController {
    /// Requests waiting for acknowledgement, eleven bits.
    public private(set) var status: UInt32 = 0
    /// Which requests reach the CPU, eleven bits.
    public private(set) var mask: UInt32 = 0

    public init() {}

    /// A device requests its interrupt.
    public func request(_ interrupt: Interrupt) {
        status |= interrupt.rawValue
    }

    public var isPending: Bool { status & mask != 0 }

    /// A 32-bit read of the register at `offset` (0 or 4); anything else in the block reads all ones.
    func read(_ offset: UInt32) -> UInt32 {
        switch offset {
        case 0: status
        case 4: mask
        default: 0xFFFF_FFFF
        }
    }

    /// Writing I_STAT acknowledges: a 0 bit clears its request, a 1 leaves it.
    func write(_ offset: UInt32, _ value: UInt32) {
        switch offset {
        case 0: status &= value & 0x7FF
        case 4: mask = value & 0x7FF
        default: break
        }
    }
}
