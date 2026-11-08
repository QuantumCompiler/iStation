// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessR3000A
import SupportMIPS
import Testing

/// ALU, shifts, comparisons, and the overflow trap (psx-spx, "CPU Arithmetic Opcodes").
@Suite struct ArithmeticTests {
    @Test func addsWithAndWithoutTheTrap() {
        let cpu = makeCPU([MIPS.addu(t2, t0, t1), MIPS.addiu(t3, t0, -1), MIPS.add(s0, t0, t1), MIPS.addi(s1, t0, 0x10)])
        cpu[t0] = 0x10
        cpu[t1] = 0xFFFF_FFF0
        cpu.run(4)
        #expect(cpu[t2] == 0)
        #expect(cpu[t3] == 0xF)
        #expect(cpu[s0] == 0)
        #expect(cpu[s1] == 0x20)
    }

    @Test(arguments: [
        (MIPS.add(t2, t0, t1), UInt32(0x7FFF_FFFF), UInt32(1)),
        (MIPS.add(t2, t0, t1), UInt32(0x8000_0000), UInt32(0x8000_0000)),
        (MIPS.addi(t2, t0, 1), UInt32(0x7FFF_FFFF), UInt32(0)),
        (MIPS.addi(t2, t0, -1), UInt32(0x8000_0000), UInt32(0)),
        (MIPS.sub(t2, t0, t1), UInt32(0x8000_0000), UInt32(1)),
        (MIPS.sub(t2, t0, t1), UInt32(0x7FFF_FFFF), UInt32(0xFFFF_FFFF)),
    ])
    func signedOverflowTrapsAndWritesNothing(word: UInt32, a: UInt32, b: UInt32) {
        let cpu = makeCPU([word])
        cpu[t0] = a
        cpu[t1] = b
        cpu[t2] = 0xDEAD_BEEF
        cpu.step()
        #expect(cpu.exceptionCode == ExceptionCode.overflow.rawValue)
        #expect(cpu.epc == origin)
        #expect(cpu.pc == ramVector)
        #expect(cpu[t2] == 0xDEAD_BEEF)
    }

    @Test func unsignedFormsNeverTrap() {
        let cpu = makeCPU([MIPS.addu(t2, t0, t0), MIPS.addiu(t3, t0, 0x7FFF), MIPS.subu(s0, zero, t0)])
        cpu[t0] = 0x7FFF_FFFF
        cpu.run(3)
        #expect(cpu.pc == origin + 12)
        #expect(cpu[t2] == 0xFFFF_FFFE)
        #expect(cpu[t3] == 0x8000_7FFE)
        #expect(cpu[s0] == 0x8000_0001)
    }

    @Test func subtracts() {
        let cpu = makeCPU([MIPS.sub(t2, t0, t1), MIPS.subu(t3, t1, t0)])
        cpu[t0] = 5
        cpu[t1] = 7
        cpu.run(2)
        #expect(cpu[t2] == UInt32(bitPattern: -2))
        #expect(cpu[t3] == 2)
    }

    @Test func logicWithImmediatesZeroExtended() {
        let cpu = makeCPU([
            MIPS.andi(t2, t0, 0xFFFF), MIPS.ori(t3, zero, 0x8000), MIPS.xori(s0, t0, 0xFF00), MIPS.lui(s1, 0x8001),
            MIPS.and(a0, t0, t1), MIPS.or(a1, t0, t1), MIPS.xor(a2, t0, t1), MIPS.nor(a3, t0, t1),
        ])
        cpu[t0] = 0xFFFF_00FF
        cpu[t1] = 0x0F0F_0F0F
        cpu.run(8)
        #expect(cpu[t2] == 0x0000_00FF)
        #expect(cpu[t3] == 0x0000_8000)
        #expect(cpu[s0] == 0xFFFF_FFFF)
        #expect(cpu[s1] == 0x8001_0000)
        #expect(cpu[a0] == 0x0F0F_000F)
        #expect(cpu[a1] == 0xFFFF_0FFF)
        #expect(cpu[a2] == 0xF0F0_0FF0)
        #expect(cpu[a3] == 0x0000_F000)
    }

    @Test func comparisonsSignedAndUnsigned() {
        let cpu = makeCPU([
            MIPS.slt(t2, t0, t1), MIPS.sltu(t3, t0, t1), MIPS.slti(s0, t0, 0), MIPS.sltiu(s1, t1, -1),
            MIPS.sltiu(a0, t0, -1),
        ])
        cpu[t0] = 0xFFFF_FFFF // -1
        cpu[t1] = 1
        cpu.run(5)
        #expect(cpu[t2] == 1)
        #expect(cpu[t3] == 0)
        #expect(cpu[s0] == 1)
        // SLTIU sign-extends its immediate, then compares unsigned: 1 < 0xFFFFFFFF.
        #expect(cpu[s1] == 1)
        #expect(cpu[a0] == 0)
    }

    @Test func shifts() {
        let cpu = makeCPU([
            MIPS.sll(t2, t0, 4), MIPS.srl(t3, t0, 4), MIPS.sra(s0, t0, 4),
            MIPS.sllv(s1, t0, t1), MIPS.srlv(a0, t0, t1), MIPS.srav(a1, t0, t1),
        ])
        cpu[t0] = 0x8000_00F1
        cpu[t1] = 33 // only the low five bits count: a shift of 1
        cpu.run(6)
        #expect(cpu[t2] == 0x0000_0F10)
        #expect(cpu[t3] == 0x0800_000F)
        #expect(cpu[s0] == 0xF800_000F)
        #expect(cpu[s1] == 0x0000_01E2)
        #expect(cpu[a0] == 0x4000_0078)
        #expect(cpu[a1] == 0xC000_0078)
    }

    @Test func registerZeroStaysZero() {
        let cpu = makeCPU([MIPS.addiu(zero, zero, 5), MIPS.lw(zero, 0, zero), MIPS.nop])
        cpu.bus.write([0x1234_5678], at: 0)
        cpu.run(3)
        #expect(cpu[zero] == 0)
    }
}

/// MULT, MULTU, DIV, DIVU and the HI/LO moves (psx-spx, "CPU Multiply/Divide Opcodes").
@Suite struct MultiplyDivideTests {
    /// HI and LO after `word` runs on `a` and `b`.
    func hiLo(_ word: UInt32, _ a: UInt32, _ b: UInt32) -> [UInt32] {
        let cpu = makeCPU([word])
        cpu[t0] = a
        cpu[t1] = b
        cpu.step()
        return [cpu.hi, cpu.lo]
    }

    @Test func multipliesSignedAndUnsigned() {
        #expect(hiLo(MIPS.mult(t0, t1), UInt32(bitPattern: -2), 3) == [0xFFFF_FFFF, 0xFFFF_FFFA])
        #expect(hiLo(MIPS.mult(t0, t1), 0x8000_0000, 0x8000_0000) == [0x4000_0000, 0])
        #expect(hiLo(MIPS.multu(t0, t1), 0xFFFF_FFFF, 2) == [1, 0xFFFF_FFFE])
        #expect(hiLo(MIPS.multu(t0, t1), 0xFFFF_FFFF, 0xFFFF_FFFF) == [0xFFFF_FFFE, 1])
    }

    @Test func dividesRoundingTowardZero() {
        #expect(hiLo(MIPS.div(t0, t1), 7, 2) == [1, 3])
        #expect(hiLo(MIPS.div(t0, t1), UInt32(bitPattern: -7), 2) == [UInt32(bitPattern: -1), UInt32(bitPattern: -3)])
        #expect(hiLo(MIPS.divu(t0, t1), 0xFFFF_FFFF, 0x10) == [0xF, 0x0FFF_FFFF])
    }

    @Test func divisionEdgeCasesNeverTrap() {
        // psx-spx: n/0 gives HI = n and LO = -1 (n ≥ 0) or +1 (n < 0); 0x80000000 / -1 gives LO = 0x80000000.
        #expect(hiLo(MIPS.div(t0, t1), 5, 0) == [5, 0xFFFF_FFFF])
        #expect(hiLo(MIPS.div(t0, t1), UInt32(bitPattern: -5), 0) == [UInt32(bitPattern: -5), 1])
        #expect(hiLo(MIPS.div(t0, t1), 0x8000_0000, 0xFFFF_FFFF) == [0, 0x8000_0000])
        #expect(hiLo(MIPS.divu(t0, t1), 5, 0) == [5, 0xFFFF_FFFF])
    }

    @Test func movesToAndFromHiLo() {
        let cpu = makeCPU([MIPS.mthi(t0), MIPS.mtlo(t1), MIPS.mfhi(t2), MIPS.mflo(t3)])
        cpu[t0] = 0x1111_1111
        cpu[t1] = 0x2222_2222
        cpu.run(4)
        #expect(cpu[t2] == 0x1111_1111)
        #expect(cpu[t3] == 0x2222_2222)
    }
}
