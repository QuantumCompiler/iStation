// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2019 Pedro Cortés
// SPDX-FileCopyrightText: 2026 iStation contributors
// Ported from BluestormDNA/ProjectPSX/ProjectPSX/Core/ProjectPSX.cs — Copyright (c) 2019 Pedro Cortés

#if PERSONAL_BUILD
import BusinessR3000A

/// The console's debug values at one moment between frames, for a personal build's Tools pane and
/// debug drawer: one value, copied out, so the narrow interface hands over no reference to the machine
/// (ADR 0015 §5). The CPU's fields are those of TraceKit's full-state record. Personal builds only
/// (ADR 0016).
public struct PS1DebugSnapshot: Sendable, Equatable {
    /// The address of the next instruction the CPU fetches.
    public var pc: UInt32
    /// The 32 general registers, r0 (always 0) first.
    public var registers: [UInt32]
    /// The multiplier's high word.
    public var hi: UInt32
    /// The multiplier's low word.
    public var lo: UInt32
    /// COP0's status register (12).
    public var sr: UInt32
    /// COP0's cause register (13): why the last exception was taken.
    public var cause: UInt32
    /// COP0's EPC (14): where the last exception was taken.
    public var epc: UInt32
    /// The CPU's cycles so far, by its fetches' timings — the count TraceKit's records carry, not the
    /// system clock's, which loads' wait states also advance.
    public var cycles: UInt64
    /// Vertical blanks since power-on.
    public var frame: Int
    /// Everything the console printed: expansion 2's TTY, and the BIOS's putchar when captured.
    public var tty: String
    /// What it printed since the last PS-EXE started, or everything when none has.
    public var ttySinceEXE: String

    /// A snapshot of these values: the console takes its own, and previews and tests build theirs.
    public init(pc: UInt32, registers: [UInt32], hi: UInt32, lo: UInt32, sr: UInt32, cause: UInt32, epc: UInt32,
                cycles: UInt64, frame: Int, tty: String, ttySinceEXE: String) {
        self.pc = pc
        self.registers = registers
        self.hi = hi
        self.lo = lo
        self.sr = sr
        self.cause = cause
        self.epc = epc
        self.cycles = cycles
        self.frame = frame
        self.tty = tty
        self.ttySinceEXE = ttySinceEXE
    }
}

extension PS1Machine {
    /// The machine's debug values now: what both consoles' `debugSnapshot` read, between frames.
    public var debugSnapshot: PS1DebugSnapshot {
        PS1DebugSnapshot(
            pc: cpu.pc, registers: (0..<32).map(cpu.register), hi: cpu.hi, lo: cpu.lo,
            sr: cpu.cop0Register(COP0Register.sr), cause: cpu.cop0Register(COP0Register.cause),
            epc: cpu.cop0Register(COP0Register.epc), cycles: cpu.cycles, frame: frame, tty: tty, ttySinceEXE: ttySinceEXE
        )
    }
}
#endif
