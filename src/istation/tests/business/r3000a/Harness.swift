// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessR3000A

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

    func store8(_ address: UInt32, _ value: UInt8) throws(BusError) {
        ram.storeBytes(of: value, toByteOffset: try offset(address, 1), as: UInt8.self)
    }

    func store16(_ address: UInt32, _ value: UInt16) throws(BusError) {
        ram.storeBytes(of: value.littleEndian, toByteOffset: try offset(address, 2), as: UInt16.self)
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

// MARK: - A small assembler

// The registers by their conventional names.
let zero: UInt32 = 0, at: UInt32 = 1, v0: UInt32 = 2, v1: UInt32 = 3
let a0: UInt32 = 4, a1: UInt32 = 5, a2: UInt32 = 6, a3: UInt32 = 7
let t0: UInt32 = 8, t1: UInt32 = 9, t2: UInt32 = 10, t3: UInt32 = 11
let s0: UInt32 = 16, s1: UInt32 = 17, ra: UInt32 = 31

/// R3000A encodings, operands in assembly order. Branch offsets count instructions from the delay slot.
enum MIPS {
    static func i(_ op: UInt32, _ rs: UInt32, _ rt: UInt32, _ imm: Int) -> UInt32 {
        op << 26 | rs << 21 | rt << 16 | (UInt32(truncatingIfNeeded: imm) & 0xFFFF)
    }

    static func r(_ function: UInt32, rs: UInt32 = 0, rt: UInt32 = 0, rd: UInt32 = 0, sa: UInt32 = 0) -> UInt32 {
        rs << 21 | rt << 16 | rd << 11 | sa << 6 | function
    }

    static let nop: UInt32 = 0

    static func sll(_ rd: UInt32, _ rt: UInt32, _ sa: UInt32) -> UInt32 { r(0x00, rt: rt, rd: rd, sa: sa) }
    static func srl(_ rd: UInt32, _ rt: UInt32, _ sa: UInt32) -> UInt32 { r(0x02, rt: rt, rd: rd, sa: sa) }
    static func sra(_ rd: UInt32, _ rt: UInt32, _ sa: UInt32) -> UInt32 { r(0x03, rt: rt, rd: rd, sa: sa) }
    static func sllv(_ rd: UInt32, _ rt: UInt32, _ rs: UInt32) -> UInt32 { r(0x04, rs: rs, rt: rt, rd: rd) }
    static func srlv(_ rd: UInt32, _ rt: UInt32, _ rs: UInt32) -> UInt32 { r(0x06, rs: rs, rt: rt, rd: rd) }
    static func srav(_ rd: UInt32, _ rt: UInt32, _ rs: UInt32) -> UInt32 { r(0x07, rs: rs, rt: rt, rd: rd) }
    static func jr(_ rs: UInt32) -> UInt32 { r(0x08, rs: rs) }
    static func jalr(_ rd: UInt32, _ rs: UInt32) -> UInt32 { r(0x09, rs: rs, rd: rd) }
    static let syscall: UInt32 = 0x0C
    static let `break`: UInt32 = 0x0D
    static func mfhi(_ rd: UInt32) -> UInt32 { r(0x10, rd: rd) }
    static func mthi(_ rs: UInt32) -> UInt32 { r(0x11, rs: rs) }
    static func mflo(_ rd: UInt32) -> UInt32 { r(0x12, rd: rd) }
    static func mtlo(_ rs: UInt32) -> UInt32 { r(0x13, rs: rs) }
    static func mult(_ rs: UInt32, _ rt: UInt32) -> UInt32 { r(0x18, rs: rs, rt: rt) }
    static func multu(_ rs: UInt32, _ rt: UInt32) -> UInt32 { r(0x19, rs: rs, rt: rt) }
    static func div(_ rs: UInt32, _ rt: UInt32) -> UInt32 { r(0x1A, rs: rs, rt: rt) }
    static func divu(_ rs: UInt32, _ rt: UInt32) -> UInt32 { r(0x1B, rs: rs, rt: rt) }
    static func add(_ rd: UInt32, _ rs: UInt32, _ rt: UInt32) -> UInt32 { r(0x20, rs: rs, rt: rt, rd: rd) }
    static func addu(_ rd: UInt32, _ rs: UInt32, _ rt: UInt32) -> UInt32 { r(0x21, rs: rs, rt: rt, rd: rd) }
    static func sub(_ rd: UInt32, _ rs: UInt32, _ rt: UInt32) -> UInt32 { r(0x22, rs: rs, rt: rt, rd: rd) }
    static func subu(_ rd: UInt32, _ rs: UInt32, _ rt: UInt32) -> UInt32 { r(0x23, rs: rs, rt: rt, rd: rd) }
    static func and(_ rd: UInt32, _ rs: UInt32, _ rt: UInt32) -> UInt32 { r(0x24, rs: rs, rt: rt, rd: rd) }
    static func or(_ rd: UInt32, _ rs: UInt32, _ rt: UInt32) -> UInt32 { r(0x25, rs: rs, rt: rt, rd: rd) }
    static func xor(_ rd: UInt32, _ rs: UInt32, _ rt: UInt32) -> UInt32 { r(0x26, rs: rs, rt: rt, rd: rd) }
    static func nor(_ rd: UInt32, _ rs: UInt32, _ rt: UInt32) -> UInt32 { r(0x27, rs: rs, rt: rt, rd: rd) }
    static func slt(_ rd: UInt32, _ rs: UInt32, _ rt: UInt32) -> UInt32 { r(0x2A, rs: rs, rt: rt, rd: rd) }
    static func sltu(_ rd: UInt32, _ rs: UInt32, _ rt: UInt32) -> UInt32 { r(0x2B, rs: rs, rt: rt, rd: rd) }

    static func bltz(_ rs: UInt32, _ offset: Int) -> UInt32 { i(0x01, rs, 0x00, offset) }
    static func bgez(_ rs: UInt32, _ offset: Int) -> UInt32 { i(0x01, rs, 0x01, offset) }
    static func bltzal(_ rs: UInt32, _ offset: Int) -> UInt32 { i(0x01, rs, 0x10, offset) }
    static func bgezal(_ rs: UInt32, _ offset: Int) -> UInt32 { i(0x01, rs, 0x11, offset) }
    static func j(_ target: UInt32) -> UInt32 { 0x02 << 26 | (target >> 2) & 0x3FF_FFFF }
    static func jal(_ target: UInt32) -> UInt32 { 0x03 << 26 | (target >> 2) & 0x3FF_FFFF }
    static func beq(_ rs: UInt32, _ rt: UInt32, _ offset: Int) -> UInt32 { i(0x04, rs, rt, offset) }
    static func bne(_ rs: UInt32, _ rt: UInt32, _ offset: Int) -> UInt32 { i(0x05, rs, rt, offset) }
    static func blez(_ rs: UInt32, _ offset: Int) -> UInt32 { i(0x06, rs, 0, offset) }
    static func bgtz(_ rs: UInt32, _ offset: Int) -> UInt32 { i(0x07, rs, 0, offset) }

    static func addi(_ rt: UInt32, _ rs: UInt32, _ imm: Int) -> UInt32 { i(0x08, rs, rt, imm) }
    static func addiu(_ rt: UInt32, _ rs: UInt32, _ imm: Int) -> UInt32 { i(0x09, rs, rt, imm) }
    static func slti(_ rt: UInt32, _ rs: UInt32, _ imm: Int) -> UInt32 { i(0x0A, rs, rt, imm) }
    static func sltiu(_ rt: UInt32, _ rs: UInt32, _ imm: Int) -> UInt32 { i(0x0B, rs, rt, imm) }
    static func andi(_ rt: UInt32, _ rs: UInt32, _ imm: Int) -> UInt32 { i(0x0C, rs, rt, imm) }
    static func ori(_ rt: UInt32, _ rs: UInt32, _ imm: Int) -> UInt32 { i(0x0D, rs, rt, imm) }
    static func xori(_ rt: UInt32, _ rs: UInt32, _ imm: Int) -> UInt32 { i(0x0E, rs, rt, imm) }
    static func lui(_ rt: UInt32, _ imm: Int) -> UInt32 { i(0x0F, 0, rt, imm) }

    static func mfc0(_ rt: UInt32, _ rd: UInt32) -> UInt32 { 0x10 << 26 | 0x00 << 21 | rt << 16 | rd << 11 }
    static func mtc0(_ rt: UInt32, _ rd: UInt32) -> UInt32 { 0x10 << 26 | 0x04 << 21 | rt << 16 | rd << 11 }
    static let rfe: UInt32 = 0x10 << 26 | 0x10 << 21 | 0x10
    static func mfc2(_ rt: UInt32, _ rd: UInt32) -> UInt32 { 0x12 << 26 | 0x00 << 21 | rt << 16 | rd << 11 }
    static func cfc2(_ rt: UInt32, _ rd: UInt32) -> UInt32 { 0x12 << 26 | 0x02 << 21 | rt << 16 | rd << 11 }
    static func mtc2(_ rt: UInt32, _ rd: UInt32) -> UInt32 { 0x12 << 26 | 0x04 << 21 | rt << 16 | rd << 11 }
    static func ctc2(_ rt: UInt32, _ rd: UInt32) -> UInt32 { 0x12 << 26 | 0x06 << 21 | rt << 16 | rd << 11 }
    /// A GTE command: bit 25 set, the command in the low 25 bits.
    static func cop2(_ command: UInt32) -> UInt32 { 0x12 << 26 | 1 << 25 | command & 0x1FF_FFFF }

    static func lb(_ rt: UInt32, _ offset: Int, _ base: UInt32) -> UInt32 { i(0x20, base, rt, offset) }
    static func lh(_ rt: UInt32, _ offset: Int, _ base: UInt32) -> UInt32 { i(0x21, base, rt, offset) }
    static func lwl(_ rt: UInt32, _ offset: Int, _ base: UInt32) -> UInt32 { i(0x22, base, rt, offset) }
    static func lw(_ rt: UInt32, _ offset: Int, _ base: UInt32) -> UInt32 { i(0x23, base, rt, offset) }
    static func lbu(_ rt: UInt32, _ offset: Int, _ base: UInt32) -> UInt32 { i(0x24, base, rt, offset) }
    static func lhu(_ rt: UInt32, _ offset: Int, _ base: UInt32) -> UInt32 { i(0x25, base, rt, offset) }
    static func lwr(_ rt: UInt32, _ offset: Int, _ base: UInt32) -> UInt32 { i(0x26, base, rt, offset) }
    static func sb(_ rt: UInt32, _ offset: Int, _ base: UInt32) -> UInt32 { i(0x28, base, rt, offset) }
    static func sh(_ rt: UInt32, _ offset: Int, _ base: UInt32) -> UInt32 { i(0x29, base, rt, offset) }
    static func swl(_ rt: UInt32, _ offset: Int, _ base: UInt32) -> UInt32 { i(0x2A, base, rt, offset) }
    static func sw(_ rt: UInt32, _ offset: Int, _ base: UInt32) -> UInt32 { i(0x2B, base, rt, offset) }
    static func swr(_ rt: UInt32, _ offset: Int, _ base: UInt32) -> UInt32 { i(0x2E, base, rt, offset) }
    static func lwc2(_ rt: UInt32, _ offset: Int, _ base: UInt32) -> UInt32 { i(0x32, base, rt, offset) }
    static func swc2(_ rt: UInt32, _ offset: Int, _ base: UInt32) -> UInt32 { i(0x3A, base, rt, offset) }
}
