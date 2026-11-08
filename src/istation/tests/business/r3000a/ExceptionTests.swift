// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessR3000A
import SupportMIPS
import Testing

/// Exceptions, RFE, interrupts and the COP0 moves (psx-spx, "COP0 - Exception Handling",
/// "COP0 - Register Summary").
@Suite struct ExceptionTests {
    @Test func syscallPushesTheModeStackAndVectorsToRAM() {
        let cpu = makeCPU([MIPS.syscall])
        cpu.setCOP0Register(COP0Register.sr, 0x0000_0403) // IM2, KUc, IEc
        cpu.jump(to: userOrigin)
        cpu.step()
        #expect(cpu.exceptionCode == ExceptionCode.syscall.rawValue)
        #expect(cpu.epc == userOrigin)
        #expect(cpu.pc == ramVector)
        #expect(cpu.sr == 0x0000_040C)
        // The push cleared KUc, so the handler runs from KSEG0 in kernel mode.
        cpu.step()
        #expect(cpu.exceptionCode == ExceptionCode.syscall.rawValue)
        #expect(cpu.pc == ramVector + 4)
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
        (MIPS.mfc0(t0, 10), UInt32(0)),
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

    @Test(arguments: [MIPS.cop0(0x01), MIPS.cop0(0x02), MIPS.cop0(0x06), MIPS.cop0(0x08)])
    func theTLBCommandsAreReservedInstructionsNotRFE(word: UInt32) {
        // psx-spx, "COP0 - Misc": RFE is the only COP0 command; TLBR, TLBWI, TLBWR and TLBP raise RI.
        let cpu = makeCPU([word])
        cpu.setCOP0Register(COP0Register.sr, 0x3C)
        cpu.step()
        #expect(cpu.exceptionCode == ExceptionCode.reservedInstruction.rawValue)
        #expect(cpu.epc == origin)
        #expect(cpu.sr == 0x30) // the exception's push of 0x3C, not RFE's pop (0x3F)
    }

    @Test(arguments: [MIPS.bc0f(4), MIPS.bc0t(4)])
    func bc0fAndBC0TAreCoprocessorUnusable(word: UInt32) {
        // psx-spx, "COP0 - Misc": the COP0 jumps aren't supported, excode 0Bh, unlike the TLB commands.
        let cpu = makeCPU([word, MIPS.nop])
        cpu.step()
        #expect(cpu.exceptionCode == ExceptionCode.coprocessorUnusable.rawValue)
        #expect(cpu.exceptionCoprocessor == 0)
        #expect(cpu.epc == origin)
        #expect(cpu.pc == ramVector)
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

    @Test(arguments: [UInt32(3), 5, 9, 11])
    func theReadWriteCOP0RegistersReadBackWhatWasWritten(register: UInt32) {
        // psx-spx, "COP0 - Register Summary": BPC, BDA, BDAM and BPCM are R/W.
        let cpu = makeCPU([MIPS.mtc0(t0, register), MIPS.mfc0(t1, register), MIPS.nop])
        cpu[t0] = 0x1234_5678
        cpu.run(3)
        #expect(cpu[t1] == 0x1234_5678)
    }

    @Test func dcicKeepsOnlyItsWritableBits() {
        // psx-spx, "cop0r7 - DCIC": bits 6–11 and 16–22 are "Not used / Always zero / R"; the rest are
        // R/W, so 0x12345678 reads back as 0x12345678 & 0xFF80F03F.
        let cpu = makeCPU([MIPS.mtc0(t0, 7), MIPS.mfc0(t1, 7), MIPS.nop])
        cpu[t0] = 0x1234_5678
        cpu.run(3)
        #expect(cpu[t1] == 0x1200_5038)
    }

    @Test func theReadOnlyCOP0RegistersIgnoreWrites() {
        // psx-spx, "COP0 - Register Summary": TAR, BadA, EPC and PRID are R.
        let cpu = makeCPU([MIPS.mtc0(t0, 6), MIPS.mtc0(t0, 8), MIPS.mtc0(t0, 14), MIPS.mtc0(t0, 15)])
        cpu[t0] = 0xDEAD_BEEF
        cpu.run(4)
        #expect(cpu.exceptionCode == 0)
        #expect(cpu.pc == origin + 16)
        #expect(cpu.cop0Register(COP0Register.jumpDestination) == 0)
        #expect(cpu.cop0Register(COP0Register.badVaddr) == 0)
        #expect(cpu.epc == 0)
        #expect(cpu.cop0Register(COP0Register.prid) == 2)
    }

    @Test func theGarbageRegistersTakeNoWriteAndReadTheLastRealRead() {
        // psx-spx, "cop0r16-r31 - Garbage": no exception, and a read soon after a real register's
        // usually returns that register's value. A write past r15 must not reach past COP0's storage.
        let cpu = makeCPU([
            MIPS.mtc0(t0, 16), MIPS.mtc0(t0, 31), MIPS.mfc0(t1, UInt32(COP0Register.prid)),
            MIPS.mfc0(t2, 16), MIPS.mfc0(t3, 31), MIPS.nop,
        ])
        cpu[t0] = 0xDEAD_BEEF
        cpu.run(6)
        #expect(cpu.exceptionCode == 0)
        #expect(cpu.pc == origin + 24)
        #expect(cpu[t1] == 2)
        #expect(cpu[t2] == 2)
        #expect(cpu[t3] == 2)
    }

    // MARK: - User mode

    @Test(arguments: [MIPS.mtc0(t0, 3), MIPS.mfc0(t1, UInt32(COP0Register.sr)), MIPS.mtc0(t0, UInt32(COP0Register.sr)), MIPS.rfe])
    func inUserModeWithoutCU0COP0IsUnusable(word: UInt32) {
        // psx-spx, "cop0r16-r31 - Garbage": with SR's KUc set and CU0 clear, the other COP0 registers
        // and RFE raise Coprocessor Unusable (excode 0Bh).
        let cpu = makeCPU([word, MIPS.nop])
        cpu.setCOP0Register(COP0Register.sr, 0x2) // KUc
        cpu.jump(to: userOrigin)
        cpu[t0] = 0x1234
        cpu[t1] = 0xAAAA_AAAA
        cpu.run(2)
        #expect(cpu.exceptionCode == ExceptionCode.coprocessorUnusable.rawValue)
        #expect(cpu.exceptionCoprocessor == 0)
        #expect(cpu.epc == userOrigin)
        #expect(cpu.sr == 0x8) // the push, not the write or RFE's pop
        #expect(cpu.cop0Register(3) == 0)
        #expect(cpu[t1] == 0xAAAA_AAAA)
    }

    @Test func inUserModeCU0OrTheGarbageRegistersAllowCOP0() {
        let withCU0 = makeCPU([MIPS.mtc0(t0, 3), MIPS.mfc0(t1, 3), MIPS.nop])
        withCU0.setCOP0Register(COP0Register.sr, 0x1000_0002) // CU0, KUc
        withCU0.jump(to: userOrigin)
        withCU0[t0] = 0x1234
        withCU0.run(3)
        #expect(withCU0.exceptionCode == 0)
        #expect(withCU0[t1] == 0x1234)

        // psx-spx: the garbage registers can be accessed even in user mode with COP0 disabled.
        let garbage = makeCPU([MIPS.mtc0(t0, 20), MIPS.mfc0(t1, 20), MIPS.nop])
        garbage.setCOP0Register(COP0Register.sr, 0x2)
        garbage.jump(to: userOrigin)
        garbage.run(3)
        #expect(garbage.exceptionCode == 0)
        #expect(garbage.pc == userOrigin + 12)
    }

    @Test func inUserModeAFetchOutsideKUSEGIsAnAddressError() {
        // psx-spx: address errors "occur when attempting to read outside of KUseg in user mode", and
        // BadVaddr is set "on references outside of kuseg (in User mode)".
        let cpu = makeCPU([MIPS.nop])
        cpu.setCOP0Register(COP0Register.sr, 0x2)
        cpu.step()
        #expect(cpu.exceptionCode == ExceptionCode.addressErrorLoad.rawValue)
        #expect(cpu.epc == origin)
        #expect(cpu.cop0Register(COP0Register.badVaddr) == origin)
        #expect(cpu.pc == ramVector)
    }

    @Test func mtc0IntoUserModeTakesEffectAtTheNextFetch() {
        let cpu = makeCPU([MIPS.mtc0(t0, UInt32(COP0Register.sr)), MIPS.nop])
        cpu[t0] = 0x2 // KUc
        cpu.run(2)
        #expect(cpu.exceptionCode == ExceptionCode.addressErrorLoad.rawValue)
        #expect(cpu.epc == origin + 4)
        #expect(cpu.cop0Register(COP0Register.badVaddr) == origin + 4)
    }

    @Test func rfeIntoUserModeTakesEffectAtTheNextFetch() {
        // psx-spx's return from an exception: jump to the user's address with RFE in the delay slot.
        let cpu = makeCPU([MIPS.jr(k0), MIPS.rfe])
        cpu.bus.write([MIPS.lw(t0, 0, s0)], at: userOrigin + 0x100)
        cpu.setCOP0Register(COP0Register.sr, 0x8) // KUp, popped into KUc
        cpu[k0] = userOrigin + 0x100
        cpu[s0] = data
        cpu.run(3)
        // The fetch from KUSEG runs; the load from KSEG0 is the address error.
        #expect(cpu.exceptionCode == ExceptionCode.addressErrorLoad.rawValue)
        #expect(cpu.epc == userOrigin + 0x100)
        #expect(cpu.cop0Register(COP0Register.badVaddr) == data)
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
        #expect(cpu.branchTaken)
        // psx-spx, "cop0r6 - TAR": the branch's destination, not its delay slot.
        #expect(cpu.cop0Register(COP0Register.jumpDestination) == origin + 4 + 16)
    }

    @Test func theHandlersFirstInstructionAfterAnInterruptIsNotInADelaySlot() {
        // psx-spx, "cop0r14 - EPC": the faulting instruction's address unless BD is set, and nothing at
        // the vector sits in a delay slot.
        let cpu = makeCPU([MIPS.beq(zero, zero, 4), MIPS.nop])
        cpu.bus.write([MIPS.syscall], at: ramVector)
        cpu.setCOP0Register(COP0Register.sr, 0x401)
        cpu.step()
        cpu.bus.interruptPending = true
        cpu.handleInterrupts()
        cpu.step()
        #expect(cpu.exceptionCode == ExceptionCode.syscall.rawValue)
        #expect(cpu.epc == ramVector)
        #expect(!cpu.inBranchDelay)
        #expect(!cpu.branchTaken)
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
