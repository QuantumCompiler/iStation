// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessR3000A
import Testing

/// Exceptions, RFE, interrupts and the COP0 moves (psx-spx, "COP0 - Exception Handling",
/// "COP0 - Register Summary").
@Suite struct ExceptionTests {
    @Test func syscallPushesTheModeStackAndVectorsToRAM() {
        let cpu = makeCPU([MIPS.syscall])
        cpu.setCOP0Register(COP0Register.sr, 0x0000_0403) // IM2, KUc, IEc
        cpu.step()
        #expect(cpu.exceptionCode == ExceptionCode.syscall.rawValue)
        #expect(cpu.epc == origin)
        #expect(cpu.pc == ramVector)
        #expect(cpu.sr == 0x0000_040C)
    }

    @Test func breakIsItsOwnException() {
        let cpu = makeCPU([MIPS.break])
        cpu.step()
        #expect(cpu.exceptionCode == ExceptionCode.breakpoint.rawValue)
        #expect(cpu.epc == origin)
    }

    @Test func bevVectorsToTheBIOS() {
        let cpu = makeCPU([MIPS.syscall])
        cpu.setCOP0Register(COP0Register.sr, 0x0040_0000)
        cpu.step()
        #expect(cpu.pc == 0xBFC0_0180)
    }

    @Test(arguments: [
        (UInt32(0xFC00_0000), UInt32(3)), // opcode 0x3F
        (UInt32(0x5000_0000), UInt32(0)), // opcode 0x14
        (MIPS.r(0x01), UInt32(0)), // SPECIAL function 0x01
        (MIPS.r(0x3F), UInt32(0)), // SPECIAL function 0x3F
        (UInt32(0x4020_0000), UInt32(0)), // COP0 with rs = 1
        (MIPS.mfc0(t0, 0), UInt32(0)), // MFC0 of an unreadable register
    ])
    func undefinedEncodingsAreReservedInstructions(word: UInt32, coprocessor: UInt32) {
        let cpu = makeCPU([word])
        cpu.step()
        #expect(cpu.exceptionCode == ExceptionCode.reservedInstruction.rawValue)
        #expect(cpu.exceptionCoprocessor == coprocessor)
        #expect(cpu.epc == origin)
    }

    @Test(arguments: [MIPS.nop, 0x4400_0000, 0x4C00_0000, 0xC000_0000, 0xC400_0000, 0xCC00_0000, 0xE000_0000, 0xE400_0000, 0xEC00_0000])
    func cop1AndCop3AndTheirLoadsAndStoresDoNothing(word: UInt32) {
        // ProjectPSX treats COP1, COP3, LWC0/1/3 and SWC0/1/3 as NOPs.
        let cpu = makeCPU([word])
        cpu.step()
        #expect(cpu.pc == origin + 4)
        #expect(cpu.exceptionCode == 0)
    }

    @Test func rfePopsTheModeStackAndKeepsTheOldestPair() {
        let cpu = makeCPU([MIPS.rfe])
        cpu.setCOP0Register(COP0Register.sr, 0xFFFF_FF3C)
        cpu.step()
        #expect(cpu.sr == 0xFFFF_FF3F)
    }

    @Test func anExceptionAndRFERestoreTheMode() {
        let cpu = makeCPU([MIPS.syscall])
        cpu.bus.write([MIPS.rfe], at: ramVector)
        cpu.setCOP0Register(COP0Register.sr, 0x05)
        cpu.step()
        #expect(cpu.sr == 0x14)
        cpu.step()
        #expect(cpu.sr == 0x15)
    }

    @Test func aMisalignedPCIsAnAddressErrorOnTheFetch() {
        let cpu = makeCPU([])
        cpu.jump(to: origin + 2)
        cpu.step()
        #expect(cpu.exceptionCode == ExceptionCode.addressErrorLoad.rawValue)
        #expect(cpu.epc == origin + 2)
        #expect(cpu.cop0Register(COP0Register.badVaddr) == origin + 2)
    }

    @Test func fetchingFromNothingIsAnInstructionBusError() {
        let cpu = makeCPU([])
        cpu.jump(to: 0x8100_0000)
        cpu.step()
        #expect(cpu.exceptionCode == ExceptionCode.busErrorInstruction.rawValue)
        #expect(cpu.epc == 0x8100_0000)
        #expect(cpu.pc == ramVector)
    }

    @Test func noCoprocessor2MakesEveryCOP2InstructionUnusable() {
        for word in [MIPS.mfc2(t0, 1), MIPS.cop2(0x1), MIPS.lwc2(1, 0, zero), MIPS.swc2(1, 0, zero)] {
            let cpu = makeCPU([word])
            cpu.setCOP0Register(COP0Register.sr, 0x4000_0000) // CU2
            cpu.step()
            #expect(cpu.exceptionCode == ExceptionCode.coprocessorUnusable.rawValue)
            #expect(cpu.exceptionCoprocessor == 2)
        }
    }

    // MARK: - COP0 moves

    @Test func mfc0HasALoadDelay() {
        let cpu = makeCPU([MIPS.mfc0(t0, UInt32(COP0Register.prid)), MIPS.addu(t1, t0, zero), MIPS.addu(t2, t0, zero)])
        cpu.run(3)
        #expect(cpu[t1] == 0)
        #expect(cpu[t2] == 2) // PRID: the R3000A's revision
    }

    @Test func onlyCAUSEsSoftwareInterruptBitsAreWritable() {
        let cpu = makeCPU([MIPS.mtc0(t0, UInt32(COP0Register.cause))])
        cpu[t0] = 0xFFFF_FFFF
        cpu.step()
        #expect(cpu.cop0Register(COP0Register.cause) == 0x300)
    }

    @Test func otherCOP0RegistersReadBackWhatWasWritten() {
        let cpu = makeCPU([MIPS.mtc0(t0, 3), MIPS.mtc0(t0, 7), MIPS.mfc0(t1, 3), MIPS.mfc0(t2, 7), MIPS.nop])
        cpu[t0] = 0x1234_5678
        cpu.run(5)
        #expect(cpu[t1] == 0x1234_5678)
        #expect(cpu[t2] == 0x1234_5678)
    }

    // MARK: - Interrupts

    @Test func anEnabledUnmaskedInterruptIsTakenBetweenInstructions() {
        let cpu = makeCPU([MIPS.nop, MIPS.nop])
        cpu.setCOP0Register(COP0Register.sr, 0x401) // IM2, IEc
        cpu.step()
        cpu.bus.interruptPending = true
        cpu.handleInterrupts()
        #expect(cpu.cop0Register(COP0Register.cause) & 0x400 != 0)
        #expect(cpu.exceptionCode == ExceptionCode.interrupt.rawValue)
        #expect(cpu.epc == origin + 4)
        #expect(cpu.pc == ramVector)
        #expect(cpu.sr == 0x404)
    }

    @Test(arguments: [UInt32(0x001), UInt32(0x400), UInt32(0x000)])
    func aMaskedOrDisabledInterruptWaitsButShowsInCAUSE(sr: UInt32) {
        let cpu = makeCPU([MIPS.nop])
        cpu.setCOP0Register(COP0Register.sr, sr)
        cpu.bus.interruptPending = true
        cpu.handleInterrupts()
        #expect(cpu.cop0Register(COP0Register.cause) & 0x400 != 0)
        #expect(cpu.pc == origin)
        cpu.bus.interruptPending = false
        cpu.handleInterrupts()
        #expect(cpu.cop0Register(COP0Register.cause) & 0x400 == 0)
    }

    @Test func anInterruptAfterABranchReturnsToTheBranch() {
        let cpu = makeCPU([MIPS.beq(zero, zero, 4), MIPS.nop])
        cpu.setCOP0Register(COP0Register.sr, 0x401)
        cpu.step()
        cpu.bus.interruptPending = true
        cpu.handleInterrupts()
        #expect(cpu.epc == origin)
        #expect(cpu.inBranchDelay)
    }

    @Test func anInterruptWaitsWhileTheNextInstructionIsCOP2() {
        // ProjectPSX's postponement, so a GTE command isn't lost.
        let cpu = makeCPU([MIPS.cop2(0x1)])
        cpu.setCOP0Register(COP0Register.sr, 0x401)
        cpu.bus.interruptPending = true
        cpu.handleInterrupts()
        #expect(cpu.pc == origin)
        #expect(cpu.cop0Register(COP0Register.cause) == 0)
    }

    @Test func enablingInterruptsWithASoftwareInterruptPendingTakesItAtOnce() {
        let cpu = makeCPU([MIPS.mtc0(t0, UInt32(COP0Register.cause)), MIPS.mtc0(t1, UInt32(COP0Register.sr)), MIPS.nop, MIPS.nop])
        cpu[t0] = 0x100 // software interrupt 0
        cpu[t1] = 0x101 // IM0, IEc
        cpu.run(2)
        #expect(cpu.exceptionCode == ExceptionCode.interrupt.rawValue)
        #expect(cpu.pc == ramVector)
        // ProjectPSX's: EPC skips the instruction after the MTC0 (Instructions.swift notes it; 3d decides).
        #expect(cpu.epc == origin + 12)
    }
}
