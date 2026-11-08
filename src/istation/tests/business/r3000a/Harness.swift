// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessR3000A
import SupportMIPS

// MARK: - An in-memory bus

/// 2 MB of RAM at physical 0, seen through every segment (KUSEG, KSEG0, KSEG1); anything else is a
/// bus error. The CPU's exception vector in RAM, 0x8000_0080, is NOPs unless a test writes there.
/// Nothing the hot path reads is a stored `var`: each would cost a dynamic exclusivity check.
final class TestBus: R3000ABus {
    static let ramSize = 0x20_0000
    static let fetchCycles = 1
    let ram: UnsafeMutableRawPointer
    var interruptPending = false

    init() {
        ram = .allocate(byteCount: Self.ramSize, alignment: 4)
        ram.initializeMemory(as: UInt8.self, repeating: 0, count: Self.ramSize)
    }

    deinit { ram.deallocate() }

    @inline(__always)
    func offset(_ address: UInt32, _ size: Int) throws(BusError) -> Int {
        let physical = Int(address & 0x1FFF_FFFF)
        guard physical + size <= Self.ramSize else { throw BusError() }
        return physical
    }

    func fetch(_ address: UInt32) throws(BusError) -> Fetch {
        Fetch(word: try load32(address), cycles: Self.fetchCycles)
    }

    func load8(_ address: UInt32) throws(BusError) -> UInt8 {
        ram.load(fromByteOffset: try offset(address, 1), as: UInt8.self)
    }

    func load16(_ address: UInt32) throws(BusError) -> UInt16 {
        UInt16(littleEndian: ram.loadUnaligned(fromByteOffset: try offset(address, 2), as: UInt16.self))
    }

    func load32(_ address: UInt32) throws(BusError) -> UInt32 {
        UInt32(littleEndian: ram.loadUnaligned(fromByteOffset: try offset(address, 4), as: UInt32.self))
    }

    func store8(_ address: UInt32, _ value: UInt32) throws(BusError) {
        ram.storeBytes(of: UInt8(truncatingIfNeeded: value), toByteOffset: try offset(address, 1), as: UInt8.self)
    }

    func store16(_ address: UInt32, _ value: UInt32) throws(BusError) {
        ram.storeBytes(of: UInt16(truncatingIfNeeded: value).littleEndian, toByteOffset: try offset(address, 2), as: UInt16.self)
    }

    func store32(_ address: UInt32, _ value: UInt32) throws(BusError) {
        ram.storeBytes(of: value.littleEndian, toByteOffset: try offset(address, 4), as: UInt32.self)
    }

    /// Writes words from `address` on, outside the CPU.
    func write(_ words: [UInt32], at address: UInt32) {
        for (index, word) in words.enumerated() {
            try! store32(address &+ UInt32(index * 4), word)
        }
    }

    func word(at address: UInt32) -> UInt32 { try! load32(address) }
}

// MARK: - Running a program

typealias TestCPU = R3000A<TestBus, NoCoprocessor2, NoTracer>

/// Where test programs start: RAM, through KSEG0.
let origin: UInt32 = 0x8000_1000
/// Where tests keep data.
let data: UInt32 = 0x8000_2000
/// The exception vector with SR's BEV clear.
let ramVector: UInt32 = 0x8000_0080

/// A CPU over a fresh `TestBus`, with `program` at `origin` and the PC on it.
func makeCPU<Cop2: Coprocessor2, Tracer: R3000ATracer>(
    _ program: [UInt32], cop2: Cop2, tracer: Tracer
) -> R3000A<TestBus, Cop2, Tracer> {
    let bus = TestBus()
    bus.write(program, at: origin)
    let cpu = R3000A(bus: bus, cop2: cop2, tracer: tracer)
    cpu.jump(to: origin)
    return cpu
}

func makeCPU(_ program: [UInt32]) -> TestCPU {
    makeCPU(program, cop2: NoCoprocessor2(), tracer: NoTracer())
}

extension R3000A {
    func run(_ steps: Int) {
        for _ in 0..<steps { step() }
    }

    /// General register `r`, read or set directly.
    subscript(_ r: UInt32) -> UInt32 {
        get { register(Int(r)) }
        set { setRegister(Int(r), newValue) }
    }

    /// CAUSE's exception code (bits 2–6).
    var exceptionCode: UInt32 { (cop0Register(COP0Register.cause) >> 2) & 0x1F }
    /// CAUSE's coprocessor number (bits 28–29).
    var exceptionCoprocessor: UInt32 { (cop0Register(COP0Register.cause) >> 28) & 0x3 }
    var inBranchDelay: Bool { cop0Register(COP0Register.cause) & 0x8000_0000 != 0 }
    var branchTaken: Bool { cop0Register(COP0Register.cause) & 0x4000_0000 != 0 }
    var epc: UInt32 { cop0Register(COP0Register.epc) }
    var sr: UInt32 { cop0Register(COP0Register.sr) }
}
