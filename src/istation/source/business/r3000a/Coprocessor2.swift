// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2019 Pedro Cortés
// SPDX-FileCopyrightText: 2026 iStation contributors
// Ported from BluestormDNA/ProjectPSX/ProjectPSX/Core/CPU.cs — Copyright (c) 2019 Pedro Cortés

/// Coprocessor 2 as the CPU drives it: the PS1's GTE, or nothing (the PS2's I/O processor). The CPU
/// calls out instead of owning it, so one CPU module serves both consoles (ADR 0015).
public protocol Coprocessor2 {
    /// False when there is no coprocessor 2: COP2, LWC2 and SWC2 then raise Coprocessor Unusable.
    static var isInstalled: Bool { get }
    /// A COP2 command (the instruction word, its bit 25 set).
    mutating func execute(_ command: UInt32)
    mutating func readData(_ register: UInt32) -> UInt32
    mutating func readControl(_ register: UInt32) -> UInt32
    mutating func writeData(_ register: UInt32, _ value: UInt32)
    mutating func writeControl(_ register: UInt32, _ value: UInt32)
}

/// No coprocessor 2.
public struct NoCoprocessor2: Coprocessor2 {
    @inlinable public static var isInstalled: Bool { false }

    public init() {}

    @inlinable public mutating func execute(_ command: UInt32) {}
    @inlinable public mutating func readData(_ register: UInt32) -> UInt32 { 0 }
    @inlinable public mutating func readControl(_ register: UInt32) -> UInt32 { 0 }
    @inlinable public mutating func writeData(_ register: UInt32, _ value: UInt32) {}
    @inlinable public mutating func writeControl(_ register: UInt32, _ value: UInt32) {}
}
