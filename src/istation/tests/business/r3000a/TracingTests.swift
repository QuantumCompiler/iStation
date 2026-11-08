// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessR3000A
import SupportR3000ATrace
import SupportSandbox
import Testing

/// The tracer hook, through TraceKit's records (reference/trace-formats.md).
@Suite struct TracingTests {
    @Test func everyRetiredInstructionIsARecordWithItsRegisterChecksum() throws {
        let sandbox = try Sandbox()
        let url = sandbox.url("cpu.trace")
        let writer = try TraceWriter(url: url, header: TraceHeader(granularity: .instruction, fullStateInterval: 2))
        let program = [MIPS.addiu(t0, zero, 5), MIPS.addiu(t1, t0, 1), MIPS.syscall]
        let cpu = makeCPU(program, cop2: NoCoprocessor2(), tracer: TraceKitTracer(writer: writer))
        cpu.run(3)
        #expect(cpu.tracer.error == nil)
        try writer.finish()

        let records = try TraceReader(url: url).readAll()
        try #require(records.count == 4)
        guard case let .instruction(first) = records[0], case let .instruction(second) = records[1],
              case let .fullState(state) = records[2], case let .instruction(third) = records[3] else {
            Issue.record("expected instruction, instruction, full state, instruction: \(records)")
            return
        }
        #expect([first.pc, second.pc, third.pc] == [origin, origin + 4, origin + 8])
        #expect([first.word, second.word, third.word] == program)
        #expect([first.cycles, second.cycles, third.cycles] == [1, 2, 3])
        #expect(state.pc == origin + 4)
        #expect(state.gpr[Int(t0)] == 5)
        #expect(state.gpr[Int(t1)] == 6)
        #expect(state.registerChecksum == second.registerChecksum)
        // The record of an instruction that raised carries the state after the exception.
        let after = RegisterChecksum.of(
            gpr: (0..<32).map { cpu.register($0) }, hi: cpu.hi, lo: cpu.lo,
            sr: cpu.sr, cause: cpu.cop0Register(COP0Register.cause), epc: cpu.epc
        )
        #expect(third.registerChecksum == after)
        #expect(cpu.epc == origin + 8)
    }
}
