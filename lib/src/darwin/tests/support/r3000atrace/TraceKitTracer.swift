// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessR3000A
// Tests that trace a CPU get TraceKit's files and diff with this module, through its declared edge.
@_exported import DataTracing

/// An R3000A tracer that writes TraceKit's instruction records (reference/trace-formats.md), with a
/// full-state record after every `header.fullStateInterval` of them. Tests and personal runs only.
public struct TraceKitTracer: R3000ATracer {
    public static var isEnabled: Bool { true }

    public let writer: TraceWriter
    /// The first write that failed; tracing stops there, since `retired` can't throw.
    public private(set) var error: (any Error)?
    private var sinceFullState: UInt32 = 0

    public init(writer: TraceWriter) {
        self.writer = writer
    }

    public mutating func retired(_ instruction: RetiredInstruction) {
        guard error == nil else { return }
        let gpr = UnsafeBufferPointer(start: instruction.gpr, count: 32)
        do {
            try writer.append(InstructionRecord(
                pc: instruction.pc, word: instruction.word, cycles: instruction.cycles,
                registerChecksum: RegisterChecksum.of(
                    gpr: gpr, hi: instruction.hi, lo: instruction.lo,
                    sr: instruction.sr, cause: instruction.cause, epc: instruction.epc
                )
            ))
            let interval = writer.header.fullStateInterval
            guard interval > 0 else { return }
            sinceFullState += 1
            if sinceFullState == interval {
                sinceFullState = 0
                try writer.append(FullStateRecord(
                    cycles: instruction.cycles, pc: instruction.pc, gpr: Array(gpr), hi: instruction.hi,
                    lo: instruction.lo, sr: instruction.sr, cause: instruction.cause, epc: instruction.epc
                ))
            }
        } catch {
            self.error = error
        }
    }
}
