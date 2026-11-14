// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2019 Pedro Cortés
// SPDX-FileCopyrightText: 2026 iStation contributors
// Ported from BluestormDNA/ProjectPSX/ProjectPSX/Devices/Expansion/Exp2.cs — Copyright (c) 2019 Pedro Cortés

/// Expansion region 2, 0x1F802000–0x1F803FFF: the DUART's transmit register (0x1F802023) and
/// 0x1F802080 are the TTY, and 0x1F802041 the POST display. Reads are all ones, every width (ps1-tests'
/// io-access-bitwidth, on hardware; ProjectPSX reads 0xFF).
public final class Expansion2 {
    /// How many of the TTY's most recent bytes are kept: 1 MB. A guest printing without end would
    /// otherwise grow the host's memory without limit; ProjectPSX prints each byte and keeps none.
    public static var ttyCapacity: Int { 0x10_0000 }

    // Unchecked: a guest store reaches these, and a checked access costs every one (ADR 0015 §4).

    /// The TTY's bytes: in order until `ttyCapacity`, then a ring whose oldest byte is at `ttyStart`.
    @exclusivity(unchecked) var ttyBytes: [UInt8] = []
    @exclusivity(unchecked) var ttyStart = 0

    /// The bytes written to the TTY, oldest first: every one, or the most recent `ttyCapacity` once
    /// there have been more.
    public var output: [UInt8] {
        ttyStart == 0 ? ttyBytes : Array(ttyBytes[ttyStart...] + ttyBytes[..<ttyStart])
    }

    /// Every byte the TTY has been given, the ones the ring has dropped included.
    @exclusivity(unchecked) public private(set) var ttyCount = 0

    /// The last value written to the POST display.
    @exclusivity(unchecked) public private(set) var post: UInt8 = 0

    public init() {}

    func write(_ address: UInt32, _ value: UInt8) {
        switch address {
        case 0x1F80_2023, 0x1F80_2080: append(value)
        case 0x1F80_2041: post = value
        default: break
        }
    }

    /// A byte for the TTY. The console's own TTY capture (the BIOS's putchar) appends here too, so the
    /// two stay in order.
    func append(_ byte: UInt8) {
        ttyCount += 1
        guard ttyBytes.count == Self.ttyCapacity else {
            ttyBytes.append(byte)
            return
        }
        ttyBytes[ttyStart] = byte // the ring is full: the newest byte replaces the oldest
        ttyStart = ttyStart + 1 == Self.ttyCapacity ? 0 : ttyStart + 1
    }
}
