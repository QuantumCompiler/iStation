// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2019 Pedro Cortés
// SPDX-FileCopyrightText: 2026 iStation contributors
// Ported from BluestormDNA/ProjectPSX/ProjectPSX/Devices/Expansion/Exp2.cs — Copyright (c) 2019 Pedro Cortés

/// Expansion region 2, 0x1F802000–0x1F803FFF: the DUART's transmit register (0x1F802023) and
/// 0x1F802080 are the TTY, and 0x1F802041 the POST display. Reads are all ones, every width (ps1-tests'
/// io-access-bitwidth, on hardware; ProjectPSX reads 0xFF).
public final class Expansion2 {
    /// Every byte written to the TTY, in order.
    public private(set) var output: [UInt8] = []
    /// The last value written to the POST display.
    public private(set) var post: UInt8 = 0

    public init() {}

    func write(_ address: UInt32, _ value: UInt8) {
        switch address {
        case 0x1F80_2023, 0x1F80_2080: output.append(value)
        case 0x1F80_2041: post = value
        default: break
        }
    }

    /// The console's own TTY capture (the BIOS's putchar) appends here, so the two stay in order.
    func append(_ byte: UInt8) {
        output.append(byte)
    }
}
