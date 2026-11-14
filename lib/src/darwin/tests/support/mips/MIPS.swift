// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

/// A small R3000A assembler for tests: each instruction's encoding, from psx-spx's opcode tables.

// The registers by their conventional names.
public let zero: UInt32 = 0, at: UInt32 = 1, v0: UInt32 = 2, v1: UInt32 = 3
public let a0: UInt32 = 4, a1: UInt32 = 5, a2: UInt32 = 6, a3: UInt32 = 7
public let t0: UInt32 = 8, t1: UInt32 = 9, t2: UInt32 = 10, t3: UInt32 = 11
public let s0: UInt32 = 16, s1: UInt32 = 17, s2: UInt32 = 18
public let k0: UInt32 = 26, k1: UInt32 = 27, gp: UInt32 = 28, sp: UInt32 = 29, fp: UInt32 = 30, ra: UInt32 = 31

/// R3000A encodings, operands in assembly order. Branch offsets count instructions from the delay slot.
public enum MIPS {
    public static func i(_ op: UInt32, _ rs: UInt32, _ rt: UInt32, _ imm: Int) -> UInt32 {
        op << 26 | rs << 21 | rt << 16 | (UInt32(truncatingIfNeeded: imm) & 0xFFFF)
    }

    public static func r(_ function: UInt32, rs: UInt32 = 0, rt: UInt32 = 0, rd: UInt32 = 0, sa: UInt32 = 0) -> UInt32 {
        rs << 21 | rt << 16 | rd << 11 | sa << 6 | function
    }

    public static let nop: UInt32 = 0

    public static func sll(_ rd: UInt32, _ rt: UInt32, _ sa: UInt32) -> UInt32 { r(0x00, rt: rt, rd: rd, sa: sa) }
    public static func srl(_ rd: UInt32, _ rt: UInt32, _ sa: UInt32) -> UInt32 { r(0x02, rt: rt, rd: rd, sa: sa) }
    public static func sra(_ rd: UInt32, _ rt: UInt32, _ sa: UInt32) -> UInt32 { r(0x03, rt: rt, rd: rd, sa: sa) }
    public static func sllv(_ rd: UInt32, _ rt: UInt32, _ rs: UInt32) -> UInt32 { r(0x04, rs: rs, rt: rt, rd: rd) }
    public static func srlv(_ rd: UInt32, _ rt: UInt32, _ rs: UInt32) -> UInt32 { r(0x06, rs: rs, rt: rt, rd: rd) }
    public static func srav(_ rd: UInt32, _ rt: UInt32, _ rs: UInt32) -> UInt32 { r(0x07, rs: rs, rt: rt, rd: rd) }
    public static func jr(_ rs: UInt32) -> UInt32 { r(0x08, rs: rs) }
    public static func jalr(_ rd: UInt32, _ rs: UInt32) -> UInt32 { r(0x09, rs: rs, rd: rd) }
    public static let syscall: UInt32 = 0x0C
    public static let `break`: UInt32 = 0x0D
    public static func mfhi(_ rd: UInt32) -> UInt32 { r(0x10, rd: rd) }
    public static func mthi(_ rs: UInt32) -> UInt32 { r(0x11, rs: rs) }
    public static func mflo(_ rd: UInt32) -> UInt32 { r(0x12, rd: rd) }
    public static func mtlo(_ rs: UInt32) -> UInt32 { r(0x13, rs: rs) }
    public static func mult(_ rs: UInt32, _ rt: UInt32) -> UInt32 { r(0x18, rs: rs, rt: rt) }
    public static func multu(_ rs: UInt32, _ rt: UInt32) -> UInt32 { r(0x19, rs: rs, rt: rt) }
    public static func div(_ rs: UInt32, _ rt: UInt32) -> UInt32 { r(0x1A, rs: rs, rt: rt) }
    public static func divu(_ rs: UInt32, _ rt: UInt32) -> UInt32 { r(0x1B, rs: rs, rt: rt) }
    public static func add(_ rd: UInt32, _ rs: UInt32, _ rt: UInt32) -> UInt32 { r(0x20, rs: rs, rt: rt, rd: rd) }
    public static func addu(_ rd: UInt32, _ rs: UInt32, _ rt: UInt32) -> UInt32 { r(0x21, rs: rs, rt: rt, rd: rd) }
    public static func sub(_ rd: UInt32, _ rs: UInt32, _ rt: UInt32) -> UInt32 { r(0x22, rs: rs, rt: rt, rd: rd) }
    public static func subu(_ rd: UInt32, _ rs: UInt32, _ rt: UInt32) -> UInt32 { r(0x23, rs: rs, rt: rt, rd: rd) }
    public static func and(_ rd: UInt32, _ rs: UInt32, _ rt: UInt32) -> UInt32 { r(0x24, rs: rs, rt: rt, rd: rd) }
    public static func or(_ rd: UInt32, _ rs: UInt32, _ rt: UInt32) -> UInt32 { r(0x25, rs: rs, rt: rt, rd: rd) }
    public static func xor(_ rd: UInt32, _ rs: UInt32, _ rt: UInt32) -> UInt32 { r(0x26, rs: rs, rt: rt, rd: rd) }
    public static func nor(_ rd: UInt32, _ rs: UInt32, _ rt: UInt32) -> UInt32 { r(0x27, rs: rs, rt: rt, rd: rd) }
    public static func slt(_ rd: UInt32, _ rs: UInt32, _ rt: UInt32) -> UInt32 { r(0x2A, rs: rs, rt: rt, rd: rd) }
    public static func sltu(_ rd: UInt32, _ rs: UInt32, _ rt: UInt32) -> UInt32 { r(0x2B, rs: rs, rt: rt, rd: rd) }

    public static func bltz(_ rs: UInt32, _ offset: Int) -> UInt32 { i(0x01, rs, 0x00, offset) }
    public static func bgez(_ rs: UInt32, _ offset: Int) -> UInt32 { i(0x01, rs, 0x01, offset) }
    public static func bltzal(_ rs: UInt32, _ offset: Int) -> UInt32 { i(0x01, rs, 0x10, offset) }
    public static func bgezal(_ rs: UInt32, _ offset: Int) -> UInt32 { i(0x01, rs, 0x11, offset) }
    public static func j(_ target: UInt32) -> UInt32 { 0x02 << 26 | (target >> 2) & 0x3FF_FFFF }
    public static func jal(_ target: UInt32) -> UInt32 { 0x03 << 26 | (target >> 2) & 0x3FF_FFFF }
    public static func beq(_ rs: UInt32, _ rt: UInt32, _ offset: Int) -> UInt32 { i(0x04, rs, rt, offset) }
    public static func bne(_ rs: UInt32, _ rt: UInt32, _ offset: Int) -> UInt32 { i(0x05, rs, rt, offset) }
    public static func blez(_ rs: UInt32, _ offset: Int) -> UInt32 { i(0x06, rs, 0, offset) }
    public static func bgtz(_ rs: UInt32, _ offset: Int) -> UInt32 { i(0x07, rs, 0, offset) }

    public static func addi(_ rt: UInt32, _ rs: UInt32, _ imm: Int) -> UInt32 { i(0x08, rs, rt, imm) }
    public static func addiu(_ rt: UInt32, _ rs: UInt32, _ imm: Int) -> UInt32 { i(0x09, rs, rt, imm) }
    public static func slti(_ rt: UInt32, _ rs: UInt32, _ imm: Int) -> UInt32 { i(0x0A, rs, rt, imm) }
    public static func sltiu(_ rt: UInt32, _ rs: UInt32, _ imm: Int) -> UInt32 { i(0x0B, rs, rt, imm) }
    public static func andi(_ rt: UInt32, _ rs: UInt32, _ imm: Int) -> UInt32 { i(0x0C, rs, rt, imm) }
    public static func ori(_ rt: UInt32, _ rs: UInt32, _ imm: Int) -> UInt32 { i(0x0D, rs, rt, imm) }
    public static func xori(_ rt: UInt32, _ rs: UInt32, _ imm: Int) -> UInt32 { i(0x0E, rs, rt, imm) }
    public static func lui(_ rt: UInt32, _ imm: Int) -> UInt32 { i(0x0F, 0, rt, imm) }

    public static func mfc0(_ rt: UInt32, _ rd: UInt32) -> UInt32 { 0x10 << 26 | 0x00 << 21 | rt << 16 | rd << 11 }
    public static func mtc0(_ rt: UInt32, _ rd: UInt32) -> UInt32 { 0x10 << 26 | 0x04 << 21 | rt << 16 | rd << 11 }
    public static func bc0f(_ offset: Int) -> UInt32 { i(0x10, 0x08, 0x00, offset) }
    public static func bc0t(_ offset: Int) -> UInt32 { i(0x10, 0x08, 0x01, offset) }
    /// A COP0 command: bit 25 set, the command in the low 25 bits. 10h is RFE; 01h, 02h, 06h and 08h
    /// are TLBR, TLBWI, TLBWR and TLBP.
    public static func cop0(_ command: UInt32) -> UInt32 { 0x10 << 26 | 1 << 25 | command & 0x1FF_FFFF }
    public static let rfe: UInt32 = cop0(0x10)
    public static func mfc2(_ rt: UInt32, _ rd: UInt32) -> UInt32 { 0x12 << 26 | 0x00 << 21 | rt << 16 | rd << 11 }
    public static func cfc2(_ rt: UInt32, _ rd: UInt32) -> UInt32 { 0x12 << 26 | 0x02 << 21 | rt << 16 | rd << 11 }
    public static func mtc2(_ rt: UInt32, _ rd: UInt32) -> UInt32 { 0x12 << 26 | 0x04 << 21 | rt << 16 | rd << 11 }
    public static func ctc2(_ rt: UInt32, _ rd: UInt32) -> UInt32 { 0x12 << 26 | 0x06 << 21 | rt << 16 | rd << 11 }
    /// A GTE command: bit 25 set, the command in the low 25 bits.
    public static func cop2(_ command: UInt32) -> UInt32 { 0x12 << 26 | 1 << 25 | command & 0x1FF_FFFF }

    public static func lb(_ rt: UInt32, _ offset: Int, _ base: UInt32) -> UInt32 { i(0x20, base, rt, offset) }
    public static func lh(_ rt: UInt32, _ offset: Int, _ base: UInt32) -> UInt32 { i(0x21, base, rt, offset) }
    public static func lwl(_ rt: UInt32, _ offset: Int, _ base: UInt32) -> UInt32 { i(0x22, base, rt, offset) }
    public static func lw(_ rt: UInt32, _ offset: Int, _ base: UInt32) -> UInt32 { i(0x23, base, rt, offset) }
    public static func lbu(_ rt: UInt32, _ offset: Int, _ base: UInt32) -> UInt32 { i(0x24, base, rt, offset) }
    public static func lhu(_ rt: UInt32, _ offset: Int, _ base: UInt32) -> UInt32 { i(0x25, base, rt, offset) }
    public static func lwr(_ rt: UInt32, _ offset: Int, _ base: UInt32) -> UInt32 { i(0x26, base, rt, offset) }
    public static func sb(_ rt: UInt32, _ offset: Int, _ base: UInt32) -> UInt32 { i(0x28, base, rt, offset) }
    public static func sh(_ rt: UInt32, _ offset: Int, _ base: UInt32) -> UInt32 { i(0x29, base, rt, offset) }
    public static func swl(_ rt: UInt32, _ offset: Int, _ base: UInt32) -> UInt32 { i(0x2A, base, rt, offset) }
    public static func sw(_ rt: UInt32, _ offset: Int, _ base: UInt32) -> UInt32 { i(0x2B, base, rt, offset) }
    public static func swr(_ rt: UInt32, _ offset: Int, _ base: UInt32) -> UInt32 { i(0x2E, base, rt, offset) }
    public static func lwc2(_ rt: UInt32, _ offset: Int, _ base: UInt32) -> UInt32 { i(0x32, base, rt, offset) }
    public static func swc2(_ rt: UInt32, _ offset: Int, _ base: UInt32) -> UInt32 { i(0x3A, base, rt, offset) }
}
