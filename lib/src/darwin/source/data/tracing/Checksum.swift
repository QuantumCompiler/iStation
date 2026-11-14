// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

/// FNV-1a, 64-bit: the checksum every trace source computes the same way, over little-endian
/// bytes (reference/trace-formats.md). Chosen for being trivial to write identically in Swift, C#
/// and C, not for strength.
public struct FNV1a64: Sendable {
    public static let offsetBasis: UInt64 = 0xCBF2_9CE4_8422_2325
    public static let prime: UInt64 = 0x0000_0100_0000_01B3

    /// The checksum of everything added so far.
    public var value: UInt64 = FNV1a64.offsetBasis

    public init() {}

    @inlinable
    public mutating func add(byte: UInt8) {
        value = (value ^ UInt64(byte)) &* Self.prime
    }

    @inlinable
    public mutating func add<Bytes: Sequence>(bytes: Bytes) where Bytes.Element == UInt8 {
        for byte in bytes { add(byte: byte) }
    }

    /// A 32-bit value, as its four little-endian bytes.
    @inlinable
    public mutating func add(word: UInt32) {
        add(byte: UInt8(truncatingIfNeeded: word))
        add(byte: UInt8(truncatingIfNeeded: word >> 8))
        add(byte: UInt8(truncatingIfNeeded: word >> 16))
        add(byte: UInt8(truncatingIfNeeded: word >> 24))
    }
}

/// The per-instruction register checksum: FNV-1a 64 over the 32 general registers, HI, LO and
/// COP0's SR, CAUSE and EPC — 37 words, in that order, each little-endian.
public enum RegisterChecksum {
    public static func of<Registers: Collection>(
        gpr: Registers, hi: UInt32, lo: UInt32, sr: UInt32, cause: UInt32, epc: UInt32
    ) -> UInt64 where Registers.Element == UInt32 {
        precondition(gpr.count == 32, "the R3000A has 32 general registers")
        var checksum = FNV1a64()
        for register in gpr { checksum.add(word: register) }
        for word in [hi, lo, sr, cause, epc] { checksum.add(word: word) }
        return checksum.value
    }
}
