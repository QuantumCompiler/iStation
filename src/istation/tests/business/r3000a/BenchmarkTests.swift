// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessR3000A
import Foundation
import Testing

/// A tracer that would do work on every instruction, but is switched off by its type.
struct SwitchedOffTracer: R3000ATracer {
    static var isEnabled: Bool { false }
    var checksum: UInt32 = 0
    mutating func retired(_ instruction: RetiredInstruction) { checksum &+= instruction.word }
}

/// A tracer that does that work.
struct SummingTracer: R3000ATracer {
    static var isEnabled: Bool { true }
    var checksum: UInt32 = 0
    mutating func retired(_ instruction: RetiredInstruction) { checksum &+= instruction.word }
}

/// The spike's loop (Milestone D) on the real interpreter, 300 million instructions, and the same with
/// a switched-off and a working tracer. Off by default; run with
/// `ISTATION_BENCHMARK=1 swift test -c release --filter BenchmarkTests`.
@Suite struct BenchmarkTests {
    /// lw t0,0x100(zero); addiu t0,t0,1; sw t0,0x100(zero); addiu t1,t1,-1; bne t1,zero,loop; nop
    static let loop: [UInt32] = [0x8C08_0100, 0x2508_0001, 0xAC08_0100, 0x2529_FFFF, 0x1520_FFFB, 0]
    static let steps = 300_000_000

    func measure<Tracer: R3000ATracer>(_ name: String, _ tracer: Tracer) -> Double {
        let bus = TestBus()
        bus.write(Self.loop, at: 0)
        let cpu = R3000A(bus: bus, cop2: NoCoprocessor2(), tracer: tracer)
        cpu.jump(to: 0)
        cpu[t1] = 0xFFFF_FFFF
        let elapsed = ContinuousClock().measure {
            for _ in 0..<Self.steps { cpu.step() }
        }
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        let rate = Double(Self.steps) / seconds / 1e6
        print(String(format: "R3000A %@: %.0f M instructions/s (%.2f s)", name, rate, seconds))
        #expect(cpu.pc < 0x18)
        return rate
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["ISTATION_BENCHMARK"] != nil))
    func theSpikesLoop() {
        for _ in 0..<2 {
            _ = measure("NoTracer", NoTracer())
            _ = measure("switched-off tracer", SwitchedOffTracer())
            _ = measure("summing tracer", SummingTracer())
        }
    }
}
