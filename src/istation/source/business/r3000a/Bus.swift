// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2019 Pedro Cortés
// SPDX-FileCopyrightText: 2026 iStation contributors
// Ported from BluestormDNA/ProjectPSX/ProjectPSX/Core/CPU.cs — Copyright (c) 2019 Pedro Cortés

/// A bus error: the address maps to nothing the bus answers.
public struct BusError: Error, Equatable, Sendable {
    public init() {}
}

/// An instruction word and the cycles its fetch took.
public struct Fetch: Equatable, Sendable {
    public let word: UInt32
    public let cycles: Int

    @inlinable
    public init(word: UInt32, cycles: Int) {
        self.word = word
        self.cycles = cycles
    }
}

/// What the R3000A sees of a console: its memory, its devices and its interrupt line. Used only as a
/// generic constraint, so each console's final bus class is specialized into the CPU's hot path
/// (ADR 0015). The calls are the ones ProjectPSX's CPU makes of its BUS; their shape is iStation's own.
public protocol R3000ABus: AnyObject {
    /// The instruction word at a virtual address, and the cycles its fetch takes.
    func fetch(_ address: UInt32) throws(BusError) -> Fetch
    func load8(_ address: UInt32) throws(BusError) -> UInt8
    func load16(_ address: UInt32) throws(BusError) -> UInt16
    func load32(_ address: UInt32) throws(BusError) -> UInt32
    /// A byte or halfword store passes the whole source register: memory keeps the low byte or
    /// halfword, but the PS1's 32-bit I/O ports see all of it (ps1-tests' io-access-bitwidth, on
    /// hardware).
    func store8(_ address: UInt32, _ value: UInt32) throws(BusError)
    func store16(_ address: UInt32, _ value: UInt32) throws(BusError)
    func store32(_ address: UInt32, _ value: UInt32) throws(BusError)
    /// The interrupt controller's line to COP0 CAUSE bit 10 (IP2).
    var interruptPending: Bool { get }
}
