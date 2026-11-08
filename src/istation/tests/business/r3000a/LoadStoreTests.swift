// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessR3000A
import Testing

/// Loads, stores and the load-delay slot (psx-spx, "CPU Load/Store Opcodes", "CPU Pipeline").
@Suite struct LoadStoreTests {
    /// A CPU with `program` at `origin`, `s0` pointing at `data`, and these words there.
    func cpu(_ program: [UInt32], memory: [UInt32] = [0x3322_1100, 0x7766_5544]) -> TestCPU {
        let cpu = makeCPU(program)
        cpu.bus.write(memory, at: data)
        cpu[s0] = data
        return cpu
    }

    @Test func theInstructionAfterALoadSeesTheOldValue() {
        let cpu = cpu([MIPS.lw(t0, 0, s0), MIPS.addu(t1, t0, zero), MIPS.addu(t2, t0, zero)])
        cpu[t0] = 0xAAAA_AAAA
        cpu.step()
        #expect(cpu[t0] == 0xAAAA_AAAA)
        cpu.run(2)
        #expect(cpu[t1] == 0xAAAA_AAAA)
        #expect(cpu[t2] == 0x3322_1100)
    }

    @Test func aSecondLoadToTheSameRegisterInTheDelaySlotWins() {
        let cpu = cpu([MIPS.lw(t0, 0, s0), MIPS.lw(t0, 4, s0), MIPS.addu(t1, t0, zero), MIPS.nop])
        cpu[t0] = 0xAAAA_AAAA
        cpu.run(3)
        // The first load never lands: the delay slot's own load to t0 replaces it.
        #expect(cpu[t1] == 0xAAAA_AAAA)
        #expect(cpu[t0] == 0x7766_5544)
    }

    @Test func anALUWriteInTheDelaySlotWinsOverTheLoad() {
        let cpu = cpu([MIPS.lw(t0, 0, s0), MIPS.addiu(t0, zero, 5), MIPS.nop])
        cpu.run(3)
        #expect(cpu[t0] == 5)
    }

    @Test func bytesAndHalvesSignOrZeroExtend() {
        let cpu = cpu(
            [MIPS.lb(t0, 3, s0), MIPS.lbu(t1, 3, s0), MIPS.lh(t2, 2, s0), MIPS.lhu(t3, 2, s0), MIPS.lb(a0, 0, s0), MIPS.nop],
            memory: [0x8081_0201]
        )
        cpu.run(6)
        #expect(cpu[t0] == 0xFFFF_FF80)
        #expect(cpu[t1] == 0x0000_0080)
        #expect(cpu[t2] == 0xFFFF_8081)
        #expect(cpu[t3] == 0x0000_8081)
        #expect(cpu[a0] == 0x0000_0001)
    }

    @Test func storesBytesHalvesAndWords() {
        let cpu = cpu([MIPS.sw(t0, 0, s0), MIPS.sh(t1, 4, s0), MIPS.sb(t1, 6, s0), MIPS.sb(t0, 7, s0)], memory: [0, 0])
        cpu[t0] = 0x1234_5678
        cpu[t1] = 0xAABB_CCDD
        cpu.run(4)
        #expect(cpu.bus.word(at: data) == 0x1234_5678)
        #expect(cpu.bus.word(at: data + 4) == 0x78DD_CCDD)
    }

    // MARK: - Unaligned words

    /// psx-spx's LWL and LWR, for each byte offset into the word at `data` (0x33221100), into 0xAABBCCDD.
    @Test(arguments: [
        (0, UInt32(0x00BB_CCDD), UInt32(0x3322_1100)),
        (1, UInt32(0x1100_CCDD), UInt32(0xAA33_2211)),
        (2, UInt32(0x2211_00DD), UInt32(0xAABB_3322)),
        (3, UInt32(0x3322_1100), UInt32(0xAABB_CC33)),
    ])
    func loadWordLeftAndRight(offset: Int, lwl: UInt32, lwr: UInt32) {
        let left = cpu([MIPS.lwl(t0, offset, s0), MIPS.nop])
        left[t0] = 0xAABB_CCDD
        left.run(2)
        #expect(left[t0] == lwl)

        let right = cpu([MIPS.lwr(t0, offset, s0), MIPS.nop])
        right[t0] = 0xAABB_CCDD
        right.run(2)
        #expect(right[t0] == lwr)
    }

    @Test(arguments: 0..<4)
    func anLWRAndLWLPairLoadsAnUnalignedWordThroughTheDelaySlot(offset: Int) {
        // The usual pair: LWL in LWR's delay slot merges into the value LWR is still bringing.
        let cpu = cpu([MIPS.lwr(t0, offset, s0), MIPS.lwl(t0, offset + 3, s0), MIPS.nop])
        cpu[t0] = 0xDEAD_BEEF
        cpu.run(3)
        let bytes: [UInt32] = [0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77]
        let expected = (0..<4).reduce(UInt32(0)) { $0 | bytes[offset + $1] << UInt32($1 * 8) }
        #expect(cpu[t0] == expected)
    }

    /// psx-spx's SWL and SWR, for each byte offset into the word at `data` (0x33221100).
    @Test(arguments: [
        (0, UInt32(0x3322_11AA), UInt32(0xAABB_CCDD)),
        (1, UInt32(0x3322_AABB), UInt32(0xBBCC_DD00)),
        (2, UInt32(0x33AA_BBCC), UInt32(0xCCDD_1100)),
        (3, UInt32(0xAABB_CCDD), UInt32(0xDD22_1100)),
    ])
    func storeWordLeftAndRight(offset: Int, swl: UInt32, swr: UInt32) {
        let left = cpu([MIPS.swl(t0, offset, s0)])
        left[t0] = 0xAABB_CCDD
        left.step()
        #expect(left.bus.word(at: data) == swl)

        let right = cpu([MIPS.swr(t0, offset, s0)])
        right[t0] = 0xAABB_CCDD
        right.step()
        #expect(right.bus.word(at: data) == swr)
    }

    @Test func anSWRAndSWLPairStoresAnUnalignedWord() {
        let cpu = cpu([MIPS.swr(t0, 1, s0), MIPS.swl(t0, 4, s0)])
        cpu[t0] = 0xAABB_CCDD
        cpu.run(2)
        #expect(cpu.bus.word(at: data) == 0xBBCC_DD00)
        #expect(cpu.bus.word(at: data + 4) == 0x7766_55AA)
    }

    // MARK: - Faults

    @Test(arguments: [
        (MIPS.lh(t0, 1, s0), ExceptionCode.addressErrorLoad),
        (MIPS.lhu(t0, 3, s0), ExceptionCode.addressErrorLoad),
        (MIPS.lw(t0, 2, s0), ExceptionCode.addressErrorLoad),
        (MIPS.sh(t0, 1, s0), ExceptionCode.addressErrorStore),
        (MIPS.sw(t0, 3, s0), ExceptionCode.addressErrorStore),
    ])
    func misalignedAccessesAreAddressErrors(word: UInt32, code: ExceptionCode) {
        let cpu = cpu([word, MIPS.nop])
        cpu[t0] = 0xAAAA_AAAA
        cpu.run(2)
        #expect(cpu.exceptionCode == code.rawValue)
        #expect(cpu.epc == origin)
        #expect(cpu.cop0Register(COP0Register.badVaddr) == data + UInt32(word & 0xFFFF))
        #expect(cpu[t0] == 0xAAAA_AAAA)
        #expect(cpu.bus.word(at: data) == 0x3322_1100)
    }

    @Test(arguments: [MIPS.lw(t0, 0, s1), MIPS.lbu(t0, 0, s1), MIPS.sw(t0, 0, s1), MIPS.lwl(t0, 0, s1), MIPS.swr(t0, 0, s1)])
    func accessesToNothingAreBusErrors(word: UInt32) {
        let cpu = cpu([word])
        cpu[s1] = 0x8100_0000 // past the test bus's 2 MB
        cpu.step()
        #expect(cpu.exceptionCode == ExceptionCode.busErrorData.rawValue)
        #expect(cpu.epc == origin)
        #expect(cpu.pc == ramVector)
    }

    @Test func isolatingTheCacheKeepsStoresAndLoadsFromMemory() {
        let cpu = cpu([
            MIPS.mtc0(t1, UInt32(COP0Register.sr)), MIPS.sw(t0, 0, s0), MIPS.sb(t0, 4, s0), MIPS.swl(t0, 4, s0), MIPS.lw(t2, 0, s0),
            MIPS.mtc0(zero, UInt32(COP0Register.sr)), MIPS.sw(t0, 4, s0), MIPS.nop,
        ])
        cpu[t0] = 0x1234_5678
        cpu[t1] = 0x1_0000 // SR.IsC
        cpu[t2] = 0xAAAA_AAAA
        cpu.run(5)
        #expect(cpu.bus.word(at: data) == 0x3322_1100)
        #expect(cpu.bus.word(at: data + 4) == 0x7766_5544)
        cpu.run(3)
        #expect(cpu[t2] == 0xAAAA_AAAA)
        #expect(cpu.bus.word(at: data + 4) == 0x1234_5678)
    }
}
