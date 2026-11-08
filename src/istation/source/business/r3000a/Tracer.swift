// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2019 Pedro Cortés
// SPDX-FileCopyrightText: 2026 iStation contributors
// Ported from BluestormDNA/ProjectPSX/ProjectPSX/Core/CPU.cs — Copyright (c) 2019 Pedro Cortés

/// One instruction as it retires, for a tracer. `gpr` points at the 32 general registers and is
/// valid only during the call.
public struct RetiredInstruction {
    public let pc: UInt32
    public let word: UInt32
    public let cycles: UInt64
    public let gpr: UnsafePointer<UInt32>
    public let hi: UInt32
    public let lo: UInt32
    public let sr: UInt32
    public let cause: UInt32
    public let epc: UInt32

    @inlinable
    init(pc: UInt32, word: UInt32, cycles: UInt64, gpr: UnsafePointer<UInt32>, hi: UInt32, lo: UInt32, sr: UInt32, cause: UInt32, epc: UInt32) {
        self.pc = pc
        self.word = word
        self.cycles = cycles
        self.gpr = gpr
        self.hi = hi
        self.lo = lo
        self.sr = sr
        self.cause = cause
        self.epc = epc
    }
}

/// Watches every retired instruction. A release build uses `NoTracer`, which specializes the call
/// to nothing; a personal build hands TraceKit a tracer (ADR 0016). The core never imports TraceKit.
public protocol R3000ATracer {
    static var isEnabled: Bool { get }
    mutating func retired(_ instruction: RetiredInstruction)
}

/// No tracing.
public struct NoTracer: R3000ATracer {
    @inlinable public static var isEnabled: Bool { false }

    public init() {}

    @inlinable public mutating func retired(_ instruction: RetiredInstruction) {}
}
