// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessPS1
import BusinessR3000A
import Testing

/// Guest-reachable corners of the bus that once trapped or stalled the host: guest code must never be
/// able to do either.
@Suite struct BusRegressionTests {
    let bus = makeMachine().bus

    @Test func aWordFetchAtTheSPUsLastHalfwordStaysInItsRegisters() throws {
        // It once read a 513th register and trapped.
        _ = try bus.fetch(0x1F80_1FFE)
        let machine = makeMachine()
        machine.cpu.jump(to: 0x1F80_1FFE)
        machine.cpu.handleInterrupts()
    }

    @Test func everyIOAddressAnswersOrBusErrorsAtEveryWidth() {
        // Zero stores start no DMA transfer, so a sweep of every register is safe to make.
        for address in UInt32(0x1F80_1000)..<0x1F80_2000 {
            _ = try? bus.fetch(address)
            _ = try? bus.load8(address)
            _ = try? bus.load16(address)
            _ = try? bus.load32(address)
            _ = bus.peek32(address)
            try? bus.store8(address, 0)
            try? bus.store16(address, 0)
            try? bus.store32(address, 0)
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func aHugeFillZeroesRAMOnce() {
        // A PS-EXE header's fill size is the guest's: 4 GB once took minutes to zero the same 2 MB.
        bus.copyToRAM([1, 2, 3], at: 0x8000_0000)
        bus.zeroRAM(at: 0x8002_0000, count: 0xFFFF_FFFF)
        #expect(bus.withRAM { $0.allSatisfy { $0 == 0 } })
    }
}
