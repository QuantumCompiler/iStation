// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessPS1
import BusinessR3000A
import Foundation
import Testing

/// The spike's loop (Milestone D) on the whole console — CPU, bus, devices, wait states — for 600
/// emulated frames, against the real console's clock. Off by default; run with
/// `ISTATION_BENCHMARK=1 swift test -c release --filter BusinessPS1Tests.BenchmarkTests`.
@Suite struct BenchmarkTests {
    /// lw t0,0x100(zero); addiu t0,t0,1; sw t0,0x100(zero); addiu t1,t1,-1; bne t1,zero,loop; nop
    static let loop: [UInt32] = [0x8C08_0100, 0x2508_0001, 0xAC08_0100, 0x2529_FFFF, 0x1520_FFFB, 0]

    @Test(.enabled(if: ProcessInfo.processInfo.environment["ISTATION_BENCHMARK"] != nil))
    func theSpikesLoopOnTheConsole() {
        for _ in 0..<2 {
            let machine = makeMachine()
            machine.load(PSEXE(pc: 0x8001_0000, destination: 0x8001_0000, text: bytes(Self.loop)))
            machine.cpu.setRegister(9, 0xFFFF_FFFF)
            let elapsed = ContinuousClock().measure {
                for _ in 0..<600 { machine.runFrame() }
            }
            let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
            // Each pass is 6 instructions in 10 cycles: six fetches and the load's four wait cycles.
            let instructions = Double(machine.cycles) * 6 / 10
            print(String(format: "PS1 console: %.0f M instructions/s, %.1f× the PS1's 33.8688 MHz (%.2f s for 600 frames)",
                         instructions / seconds / 1e6, Double(machine.cycles) / seconds / 33_868_800, seconds))
        }
    }
}
