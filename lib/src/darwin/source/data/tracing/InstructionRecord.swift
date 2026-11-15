// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

/// One executed instruction, written after it completes — including any exception it raised
/// (reference/trace-formats.md). 24 bytes after its tag.
public struct InstructionRecord: Equatable, Sendable {
    /// The instruction's address.
    public var pc: UInt32
    /// Its encoding.
    public var word: UInt32
    /// The CPU's cycle count after it.
    public var cycles: UInt64
    /// `RegisterChecksum` of the registers after it.
    public var registerChecksum: UInt64

    public init(pc: UInt32, word: UInt32, cycles: UInt64, registerChecksum: UInt64) {
        self.pc = pc
        self.word = word
        self.cycles = cycles
        self.registerChecksum = registerChecksum
    }

    static let tag: UInt8 = 0x01
    static let payloadSize = 24
}

/// The whole CPU state, at a fixed interval and on demand, so a divergence can be read field by
/// field rather than only through a checksum. 160 bytes after its tag.
public struct FullStateRecord: Equatable, Sendable {
    public var cycles: UInt64
    public var pc: UInt32
    /// The 32 general registers.
    public var gpr: [UInt32]
    public var hi: UInt32
    public var lo: UInt32
    /// COP0 register 12.
    public var sr: UInt32
    /// COP0 register 13.
    public var cause: UInt32
    /// COP0 register 14.
    public var epc: UInt32

    public init(cycles: UInt64, pc: UInt32, gpr: [UInt32], hi: UInt32, lo: UInt32, sr: UInt32, cause: UInt32, epc: UInt32) {
        precondition(gpr.count == 32, "the R3000A has 32 general registers")
        self.cycles = cycles
        self.pc = pc
        self.gpr = gpr
        self.hi = hi
        self.lo = lo
        self.sr = sr
        self.cause = cause
        self.epc = epc
    }

    /// The same checksum an instruction record carries for this state.
    public var registerChecksum: UInt64 {
        RegisterChecksum.of(gpr: gpr, hi: hi, lo: lo, sr: sr, cause: cause, epc: epc)
    }

    static let tag: UInt8 = 0x02
    static let payloadSize = 160
}
