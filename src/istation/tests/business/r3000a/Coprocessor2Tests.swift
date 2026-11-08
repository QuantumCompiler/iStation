// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessR3000A
import SupportMIPS
import Testing

/// A stand-in GTE that records what the CPU asks of it.
struct RecordingCoprocessor2: Coprocessor2 {
    static var isInstalled: Bool { true }
    var data = [UInt32](repeating: 0, count: 32)
    var control = [UInt32](repeating: 0, count: 32)
    var commands: [UInt32] = []

    mutating func execute(_ command: UInt32) { commands.append(command) }
    mutating func readData(_ register: UInt32) -> UInt32 { data[Int(register)] }
    mutating func readControl(_ register: UInt32) -> UInt32 { control[Int(register)] }
    mutating func writeData(_ register: UInt32, _ value: UInt32) { data[Int(register)] = value }
    mutating func writeControl(_ register: UInt32, _ value: UInt32) { control[Int(register)] = value }
}

/// How the CPU drives coprocessor 2 (psx-spx, "GTE Overview": the transfer opcodes).
@Suite struct Coprocessor2Tests {
    func cpu(_ program: [UInt32], sr: UInt32 = 0x4000_0000) -> R3000A<TestBus, RecordingCoprocessor2, NoTracer> {
        let cpu = makeCPU(program, cop2: RecordingCoprocessor2(), tracer: NoTracer())
        cpu.setCOP0Register(COP0Register.sr, sr)
        cpu.bus.write([0xCAFE_F00D, 0], at: data)
        cpu[s0] = data
        return cpu
    }

    @Test func movesAndCommandsReachTheCoprocessor() {
        let cpu = cpu([
            MIPS.mtc2(t0, 5), MIPS.ctc2(t1, 7), MIPS.cop2(0x12_3456),
            MIPS.mfc2(t2, 5), MIPS.cfc2(t3, 7), MIPS.addu(a0, t2, zero), MIPS.nop,
        ])
        cpu[t0] = 0x1111_1111
        cpu[t1] = 0x2222_2222
        cpu.run(7)
        #expect(cpu.cop2.data[5] == 0x1111_1111)
        #expect(cpu.cop2.control[7] == 0x2222_2222)
        #expect(cpu.cop2.commands == [MIPS.cop2(0x12_3456)])
        #expect(cpu[t2] == 0x1111_1111)
        #expect(cpu[t3] == 0x2222_2222)
        // MFC2's value lands after the next instruction, so the ADDU two after it reads it.
        #expect(cpu[a0] == 0x1111_1111)
    }

    @Test func mfc2HasALoadDelay() {
        let cpu = cpu([MIPS.mfc2(t0, 3), MIPS.addu(t1, t0, zero), MIPS.addu(t2, t0, zero)])
        cpu.cop2.data[3] = 0x5555_5555
        cpu.run(3)
        #expect(cpu[t1] == 0)
        #expect(cpu[t2] == 0x5555_5555)
    }

    @Test func lwc2AndSWC2MoveWordsBetweenMemoryAndTheCoprocessor() {
        let cpu = cpu([MIPS.lwc2(9, 0, s0), MIPS.swc2(9, 4, s0)])
        cpu.run(2)
        #expect(cpu.cop2.data[9] == 0xCAFE_F00D)
        #expect(cpu.bus.word(at: data + 4) == 0xCAFE_F00D)
    }

    @Test func misalignedLWC2AndSWC2AreAddressErrors() {
        let load = cpu([MIPS.lwc2(9, 2, s0)])
        load.step()
        #expect(load.exceptionCode == ExceptionCode.addressErrorLoad.rawValue)
        let store = cpu([MIPS.swc2(9, 2, s0)])
        store.step()
        #expect(store.exceptionCode == ExceptionCode.addressErrorStore.rawValue)
    }

    @Test func withoutCU2EvenAnInstalledCoprocessorIsUnusable() {
        let cpu = cpu([MIPS.mtc2(t0, 5)], sr: 0)
        cpu[t0] = 1
        cpu.step()
        #expect(cpu.exceptionCode == ExceptionCode.coprocessorUnusable.rawValue)
        #expect(cpu.exceptionCoprocessor == 2)
        #expect(cpu.cop2.data[5] == 0)
    }

    @Test func anUndefinedTransferIsAReservedInstruction() {
        let cpu = cpu([0x12 << 26 | 0x08 << 21])
        cpu.step()
        #expect(cpu.exceptionCode == ExceptionCode.reservedInstruction.rawValue)
        #expect(cpu.exceptionCoprocessor == 2)
    }
}
