// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessR3000A
import Testing

/// Branches, jumps and the branch-delay slot (psx-spx, "CPU Jump Opcodes").
@Suite struct BranchTests {
    /// Runs a branch at `origin` with a delay slot that sets `t3`, and returns where the PC goes.
    func target(of branch: UInt32, rs: UInt32 = 0, rt: UInt32 = 0) -> (pc: UInt32, delaySlotRan: Bool, cpu: TestCPU) {
        let cpu = makeCPU([branch, MIPS.addiu(t3, zero, 1)])
        cpu[t0] = rs
        cpu[t1] = rt
        cpu.run(2)
        return (cpu.pc, cpu[t3] == 1, cpu)
    }

    @Test func aTakenBranchRunsItsDelaySlotThenLandsRelativeToIt() {
        let taken = target(of: MIPS.beq(t0, t1, 4), rs: 7, rt: 7)
        #expect(taken.delaySlotRan)
        #expect(taken.pc == origin + 4 + 16)
        let back = target(of: MIPS.bne(t0, t1, -2), rs: 7, rt: 8)
        #expect(back.pc == origin + 4 - 8)
    }

    @Test func anUntakenBranchFallsThroughAfterItsDelaySlot() {
        let untaken = target(of: MIPS.beq(t0, t1, 4), rs: 7, rt: 8)
        #expect(untaken.delaySlotRan)
        #expect(untaken.pc == origin + 8)
    }

    @Test(arguments: [
        (MIPS.blez(t0, 4), UInt32(0), true), (MIPS.blez(t0, 4), UInt32(bitPattern: -1), true), (MIPS.blez(t0, 4), UInt32(1), false),
        (MIPS.bgtz(t0, 4), UInt32(1), true), (MIPS.bgtz(t0, 4), UInt32(0), false), (MIPS.bgtz(t0, 4), UInt32(0x8000_0000), false),
        (MIPS.bltz(t0, 4), UInt32(bitPattern: -1), true), (MIPS.bltz(t0, 4), UInt32(0), false),
        (MIPS.bgez(t0, 4), UInt32(0), true), (MIPS.bgez(t0, 4), UInt32(0x8000_0000), false),
    ])
    func comparesWithZeroSigned(branch: UInt32, value: UInt32, taken: Bool) {
        #expect(target(of: branch, rs: value).pc == (taken ? origin + 20 : origin + 8))
    }

    @Test(arguments: [(MIPS.bltzal(t0, 4), UInt32(bitPattern: -1), true), (MIPS.bltzal(t0, 4), UInt32(1), false),
                      (MIPS.bgezal(t0, 4), UInt32(1), true), (MIPS.bgezal(t0, 4), UInt32(bitPattern: -1), false)])
    func theLinkingFormsLinkWhetherOrNotTheyBranch(branch: UInt32, value: UInt32, taken: Bool) {
        let result = target(of: branch, rs: value)
        #expect(result.pc == (taken ? origin + 20 : origin + 8))
        #expect(result.cpu[ra] == origin + 8)
    }

    @Test func jumpsKeepThePCsTopFourBits() {
        let jump = target(of: MIPS.j(0x0012_3450))
        #expect(jump.delaySlotRan)
        #expect(jump.pc == 0x8012_3450)
        let call = target(of: MIPS.jal(0x0012_3450))
        #expect(call.pc == 0x8012_3450)
        #expect(call.cpu[ra] == origin + 8)
    }

    @Test func jumpsThroughRegisters() {
        let jump = target(of: MIPS.jr(t0), rs: 0x8000_4000)
        #expect(jump.delaySlotRan)
        #expect(jump.pc == 0x8000_4000)
        let call = target(of: MIPS.jalr(s0, t0), rs: 0x8000_4000)
        #expect(call.pc == 0x8000_4000)
        #expect(call.cpu[s0] == origin + 8)
    }

    @Test func aBranchReadsRegistersBeforeTheLoadInFrontOfItLands() {
        let cpu = makeCPU([MIPS.lw(t0, 0, s0), MIPS.beq(t0, zero, 4), MIPS.nop])
        cpu.bus.write([1], at: data)
        cpu[s0] = data
        cpu.run(3)
        #expect(cpu.pc == origin + 8 + 16)
    }

    // MARK: - Exceptions in the delay slot

    @Test func anExceptionInATakenBranchsDelaySlotPointsEPCAtTheBranch() {
        let cpu = makeCPU([MIPS.beq(zero, zero, 4), MIPS.syscall])
        cpu.run(2)
        #expect(cpu.exceptionCode == ExceptionCode.syscall.rawValue)
        #expect(cpu.epc == origin)
        #expect(cpu.inBranchDelay)
        #expect(cpu.branchTaken)
        #expect(cpu.cop0Register(COP0Register.jumpDestination) == origin + 4 + 16)
        #expect(cpu.pc == ramVector)
    }

    @Test func anExceptionInAnUntakenBranchsDelaySlotHasBDButNotBT() {
        let cpu = makeCPU([MIPS.bne(zero, zero, 4), MIPS.syscall])
        cpu.run(2)
        #expect(cpu.epc == origin)
        #expect(cpu.inBranchDelay)
        #expect(!cpu.branchTaken)
        #expect(cpu.cop0Register(COP0Register.jumpDestination) == origin + 8)
    }

    @Test func anExceptionOutsideADelaySlotHasNeither() {
        let cpu = makeCPU([MIPS.nop, MIPS.syscall])
        cpu.run(2)
        #expect(cpu.epc == origin + 4)
        #expect(!cpu.inBranchDelay)
        #expect(!cpu.branchTaken)
    }
}
