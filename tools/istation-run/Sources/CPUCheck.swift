// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

/// The CPU-check program: R3000A code built here, never Sony's, that runs from the reset vector of a
/// 512 KB image, so the Swift console and ProjectPSX start it from the same state and their
/// instruction traces can be compared record for record (3e's guardrail, carried into 3d).
///
/// It stays inside what both implement alike: no overflow trap, misaligned access, bus error, COP2,
/// interrupt or SR write beyond the first — the places iStation departs from ProjectPSX on psx-spx's evidence.
enum CPUCheck {
    static let base: UInt32 = 0xBFC0_0000

    static var image: [UInt8] {
        var image = [UInt8](repeating: 0, count: 0x8_0000)
        for (index, word) in program().enumerated() {
            for byte in 0..<4 { image[index * 4 + byte] = UInt8(truncatingIfNeeded: word >> (8 * UInt32(byte))) }
        }
        return image
    }

    static func program() -> [UInt32] {
        // First, SR, as a BIOS's first instructions write it: ProjectPSX treats the cache as isolated —
        // loads and stores ignored — until SR is first written, though its SR reads 0 (a C# field's
        // false default); the Swift CPU follows SR's IsC from reset, as psx-spx does.
        var p: [UInt32] = [mtc0(zero, 12)]
        // The exception handler, stored into RAM at 0x80000080: return past the instruction that raised.
        let handler = [mfc0(k0, 14), nop, addiu(k0, k0, 4), jr(k0), rfe]
        p += [lui(s1, 0x8000)]
        for (index, word) in handler.enumerated() {
            p += [lui(t0, Int(word >> 16)), ori(t0, t0, Int(word & 0xFFFF)), sw(t0, 0x80 + 4 * index, s1)]
        }

        // Arithmetic, logic, shifts, comparisons.
        p += [lui(s0, 0x8001), ori(t0, zero, 0x1234), lui(t1, 0x5678), ori(t1, t1, 0x9ABC)]
        p += [addu(t2, t0, t1), subu(t3, t1, t0), add(a0, t0, t1), sub(a1, t1, t0), addi(a2, t0, -5), addiu(a3, t1, 0x7FFF)]
        p += [and(t2, t0, t1), or(t3, t0, t1), xor(a0, t0, t1), nor(a1, t0, t1), andi(a2, t1, 0xF0F0), xori(a3, t1, 0xFFFF)]
        p += [sll(t2, t1, 7), srl(t3, a1, 13), sra(a0, a1, 9), sllv(a2, t1, t0), srlv(a3, a1, t0), srav(t2, a1, t0)]
        p += [slt(t3, a1, t0), sltu(a0, a1, t0), slti(a2, a1, -1), sltiu(a3, t0, -1)]

        // Multiply and divide, with psx-spx's division edge cases: by zero, signed (a negative and a
        // positive dividend) and unsigned, and 0x80000000 ÷ −1.
        p += [mult(t1, a1), mflo(a0), mfhi(a2), multu(t1, a1), mflo(a3), mfhi(t2)]
        p += [div(a1, t0), mflo(t3), mfhi(a0), divu(a1, t0), mflo(a2), mfhi(a3), div(a1, zero), mflo(t2), mfhi(t3)]
        p += [div(t0, zero), mflo(a0), mfhi(a2), divu(a1, zero), mflo(a3), mfhi(t2)]
        p += [lui(t2, 0x8000), addiu(t3, zero, -1), div(t2, t3), mflo(a0), mfhi(a2)]
        p += [mthi(t0), mtlo(t1), mfhi(a0), mflo(a2)]

        // Loads and stores, through the load-delay slot.
        p += [sw(t1, 0, s0), sh(t0, 4, s0), sb(a1, 7, s0)]
        p += [lw(a0, 0, s0), addu(a2, a0, zero), addu(a3, a0, zero)]
        p += [lh(t2, 0, s0), lhu(t3, 2, s0), lb(a0, 3, s0), lbu(a2, 7, s0), nop]
        p += [lwr(a3, 1, s0), lwl(a3, 4, s0), nop, swr(t1, 9, s0), swl(t1, 12, s0), lw(t2, 8, s0), lw(t3, 12, s0), nop]

        // Branches, their delay slots, and the linking forms.
        p += [beq(t0, t0, 1), addiu(v0, zero, 1), addiu(v0, v0, 100), addiu(v0, v0, 2)]
        p += [bne(t0, t0, 1), addiu(v0, v0, 4), addiu(v0, v0, 8)]
        p += [blez(zero, 1), nop, addiu(v0, v0, 100), bgtz(t0, 1), nop, addiu(v0, v0, 100)]
        p += [bltz(a1, 1), nop, addiu(v0, v0, 100), bgez(t0, 1), nop, addiu(v0, v0, 100)]
        p += [bltzal(a1, 1), nop, addiu(v0, v0, 100), bgezal(a1, 1), nop, addiu(v0, v0, 16)]

        // A jump, its delay slot run, the next instruction skipped.
        let jAt = p.count
        p += [0, addiu(v0, v0, 32), addiu(v0, v0, 100)]

        // A call and return through JAL and JALR, and code copied to RAM and run there.
        let jalAt = p.count
        p += [0, nop]
        let jalrAt = p.count
        p += [0, 0, jalr(ra, t2), nop]
        let routine = [addiu(v1, v1, 5), jr(ra), nop]
        p += [lui(s2, 0x8002)]
        for (index, word) in routine.enumerated() {
            p += [lui(t0, Int(word >> 16)), ori(t0, t0, Int(word & 0xFFFF)), sw(t0, 4 * index, s2)]
        }
        p += [jalr(ra, s2), nop]

        // COP0 moves; SYSCALL and BREAK through the handler.
        p += [mtc0(t1, 3), mfc0(a0, 3), nop, syscall, break_]

        // A counted loop, for volume.
        p += [ori(s2, zero, 200), addu(v0, v0, s2), xor(v1, v1, v0), addiu(s2, s2, -1), bne(s2, zero, -4), sll(a0, v0, 1)]
        p += [beq(zero, zero, -1), nop] // the end: an endless loop

        let subroutine = UInt32(p.count) * 4 + base
        p += [addiu(v1, v1, 3), jr(ra), nop]
        p[jAt] = j(base + UInt32(jAt + 3) * 4)
        p[jalAt] = jal(subroutine)
        p[jalrAt] = lui(t2, Int(subroutine >> 16))
        p[jalrAt + 1] = ori(t2, t2, Int(subroutine & 0xFFFF))
        return p
    }

    // MARK: - Encodings (psx-spx's opcode tables)

    static let zero: UInt32 = 0, v0: UInt32 = 2, v1: UInt32 = 3, a0: UInt32 = 4, a1: UInt32 = 5, a2: UInt32 = 6, a3: UInt32 = 7
    static let t0: UInt32 = 8, t1: UInt32 = 9, t2: UInt32 = 10, t3: UInt32 = 11, s0: UInt32 = 16, s1: UInt32 = 17, s2: UInt32 = 18
    static let k0: UInt32 = 26, ra: UInt32 = 31
    static let nop: UInt32 = 0, syscall: UInt32 = 0x0C, break_: UInt32 = 0x0D, rfe: UInt32 = 0x4200_0010

    static func i(_ op: UInt32, _ rs: UInt32, _ rt: UInt32, _ imm: Int) -> UInt32 {
        op << 26 | rs << 21 | rt << 16 | (UInt32(truncatingIfNeeded: imm) & 0xFFFF)
    }
    static func r(_ f: UInt32, _ rs: UInt32, _ rt: UInt32, _ rd: UInt32, _ sa: UInt32 = 0) -> UInt32 {
        rs << 21 | rt << 16 | rd << 11 | sa << 6 | f
    }
    static func sll(_ d: UInt32, _ t: UInt32, _ s: UInt32) -> UInt32 { r(0x00, 0, t, d, s) }
    static func srl(_ d: UInt32, _ t: UInt32, _ s: UInt32) -> UInt32 { r(0x02, 0, t, d, s) }
    static func sra(_ d: UInt32, _ t: UInt32, _ s: UInt32) -> UInt32 { r(0x03, 0, t, d, s) }
    static func sllv(_ d: UInt32, _ t: UInt32, _ s: UInt32) -> UInt32 { r(0x04, s, t, d) }
    static func srlv(_ d: UInt32, _ t: UInt32, _ s: UInt32) -> UInt32 { r(0x06, s, t, d) }
    static func srav(_ d: UInt32, _ t: UInt32, _ s: UInt32) -> UInt32 { r(0x07, s, t, d) }
    static func jr(_ s: UInt32) -> UInt32 { r(0x08, s, 0, 0) }
    static func jalr(_ d: UInt32, _ s: UInt32) -> UInt32 { r(0x09, s, 0, d) }
    static func mfhi(_ d: UInt32) -> UInt32 { r(0x10, 0, 0, d) }
    static func mthi(_ s: UInt32) -> UInt32 { r(0x11, s, 0, 0) }
    static func mflo(_ d: UInt32) -> UInt32 { r(0x12, 0, 0, d) }
    static func mtlo(_ s: UInt32) -> UInt32 { r(0x13, s, 0, 0) }
    static func mult(_ s: UInt32, _ t: UInt32) -> UInt32 { r(0x18, s, t, 0) }
    static func multu(_ s: UInt32, _ t: UInt32) -> UInt32 { r(0x19, s, t, 0) }
    static func div(_ s: UInt32, _ t: UInt32) -> UInt32 { r(0x1A, s, t, 0) }
    static func divu(_ s: UInt32, _ t: UInt32) -> UInt32 { r(0x1B, s, t, 0) }
    static func add(_ d: UInt32, _ s: UInt32, _ t: UInt32) -> UInt32 { r(0x20, s, t, d) }
    static func addu(_ d: UInt32, _ s: UInt32, _ t: UInt32) -> UInt32 { r(0x21, s, t, d) }
    static func sub(_ d: UInt32, _ s: UInt32, _ t: UInt32) -> UInt32 { r(0x22, s, t, d) }
    static func subu(_ d: UInt32, _ s: UInt32, _ t: UInt32) -> UInt32 { r(0x23, s, t, d) }
    static func and(_ d: UInt32, _ s: UInt32, _ t: UInt32) -> UInt32 { r(0x24, s, t, d) }
    static func or(_ d: UInt32, _ s: UInt32, _ t: UInt32) -> UInt32 { r(0x25, s, t, d) }
    static func xor(_ d: UInt32, _ s: UInt32, _ t: UInt32) -> UInt32 { r(0x26, s, t, d) }
    static func nor(_ d: UInt32, _ s: UInt32, _ t: UInt32) -> UInt32 { r(0x27, s, t, d) }
    static func slt(_ d: UInt32, _ s: UInt32, _ t: UInt32) -> UInt32 { r(0x2A, s, t, d) }
    static func sltu(_ d: UInt32, _ s: UInt32, _ t: UInt32) -> UInt32 { r(0x2B, s, t, d) }
    static func bltz(_ s: UInt32, _ o: Int) -> UInt32 { i(0x01, s, 0x00, o) }
    static func bgez(_ s: UInt32, _ o: Int) -> UInt32 { i(0x01, s, 0x01, o) }
    static func bltzal(_ s: UInt32, _ o: Int) -> UInt32 { i(0x01, s, 0x10, o) }
    static func bgezal(_ s: UInt32, _ o: Int) -> UInt32 { i(0x01, s, 0x11, o) }
    static func j(_ target: UInt32) -> UInt32 { 0x02 << 26 | (target >> 2) & 0x3FF_FFFF }
    static func jal(_ target: UInt32) -> UInt32 { 0x03 << 26 | (target >> 2) & 0x3FF_FFFF }
    static func beq(_ s: UInt32, _ t: UInt32, _ o: Int) -> UInt32 { i(0x04, s, t, o) }
    static func bne(_ s: UInt32, _ t: UInt32, _ o: Int) -> UInt32 { i(0x05, s, t, o) }
    static func blez(_ s: UInt32, _ o: Int) -> UInt32 { i(0x06, s, 0, o) }
    static func bgtz(_ s: UInt32, _ o: Int) -> UInt32 { i(0x07, s, 0, o) }
    static func addi(_ t: UInt32, _ s: UInt32, _ v: Int) -> UInt32 { i(0x08, s, t, v) }
    static func addiu(_ t: UInt32, _ s: UInt32, _ v: Int) -> UInt32 { i(0x09, s, t, v) }
    static func slti(_ t: UInt32, _ s: UInt32, _ v: Int) -> UInt32 { i(0x0A, s, t, v) }
    static func sltiu(_ t: UInt32, _ s: UInt32, _ v: Int) -> UInt32 { i(0x0B, s, t, v) }
    static func andi(_ t: UInt32, _ s: UInt32, _ v: Int) -> UInt32 { i(0x0C, s, t, v) }
    static func ori(_ t: UInt32, _ s: UInt32, _ v: Int) -> UInt32 { i(0x0D, s, t, v) }
    static func xori(_ t: UInt32, _ s: UInt32, _ v: Int) -> UInt32 { i(0x0E, s, t, v) }
    static func lui(_ t: UInt32, _ v: Int) -> UInt32 { i(0x0F, 0, t, v) }
    static func mfc0(_ t: UInt32, _ d: UInt32) -> UInt32 { 0x10 << 26 | t << 16 | d << 11 }
    static func mtc0(_ t: UInt32, _ d: UInt32) -> UInt32 { 0x10 << 26 | 0x04 << 21 | t << 16 | d << 11 }
    static func lb(_ t: UInt32, _ o: Int, _ b: UInt32) -> UInt32 { i(0x20, b, t, o) }
    static func lh(_ t: UInt32, _ o: Int, _ b: UInt32) -> UInt32 { i(0x21, b, t, o) }
    static func lwl(_ t: UInt32, _ o: Int, _ b: UInt32) -> UInt32 { i(0x22, b, t, o) }
    static func lw(_ t: UInt32, _ o: Int, _ b: UInt32) -> UInt32 { i(0x23, b, t, o) }
    static func lbu(_ t: UInt32, _ o: Int, _ b: UInt32) -> UInt32 { i(0x24, b, t, o) }
    static func lhu(_ t: UInt32, _ o: Int, _ b: UInt32) -> UInt32 { i(0x25, b, t, o) }
    static func lwr(_ t: UInt32, _ o: Int, _ b: UInt32) -> UInt32 { i(0x26, b, t, o) }
    static func sb(_ t: UInt32, _ o: Int, _ b: UInt32) -> UInt32 { i(0x28, b, t, o) }
    static func sh(_ t: UInt32, _ o: Int, _ b: UInt32) -> UInt32 { i(0x29, b, t, o) }
    static func swl(_ t: UInt32, _ o: Int, _ b: UInt32) -> UInt32 { i(0x2A, b, t, o) }
    static func sw(_ t: UInt32, _ o: Int, _ b: UInt32) -> UInt32 { i(0x2B, b, t, o) }
    static func swr(_ t: UInt32, _ o: Int, _ b: UInt32) -> UInt32 { i(0x2E, b, t, o) }
}
