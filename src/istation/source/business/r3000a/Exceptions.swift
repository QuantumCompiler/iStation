// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2019 Pedro Cortés
// SPDX-FileCopyrightText: 2026 iStation contributors
// Ported from BluestormDNA/ProjectPSX/ProjectPSX/Core/CPU.cs — Copyright (c) 2019 Pedro Cortés

/// COP0 CAUSE's exception codes (psx-spx, "COP0 - Exception Handling").
public enum ExceptionCode: UInt32, Sendable {
    case interrupt = 0x00
    /// Address error on a load or an instruction fetch.
    case addressErrorLoad = 0x04
    case addressErrorStore = 0x05
    case busErrorInstruction = 0x06
    case busErrorData = 0x07
    case syscall = 0x08
    case breakpoint = 0x09
    case reservedInstruction = 0x0A
    case coprocessorUnusable = 0x0B
    case overflow = 0x0C
}

/// COP0's registers by number.
public enum COP0Register {
    @inlinable public static var badVaddr: Int { 8 }
    @inlinable public static var jumpDestination: Int { 6 }
    @inlinable public static var sr: Int { 12 }
    @inlinable public static var cause: Int { 13 }
    @inlinable public static var epc: Int { 14 }
    @inlinable public static var prid: Int { 15 }
}
