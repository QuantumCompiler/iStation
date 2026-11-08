// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessPS1
import BusinessR3000A
import SupportMIPS
import Testing

/// The memory map's regions, mirrors and segments (psx-spx, "Memory Map").
@Suite struct MemoryMapTests {
    let bus = makeMachine().bus

    @Test func ramMirrorsThroughEverySegmentAndItsWindow() throws {
        try bus.store32(0x0000_0100, 0xCAFE_F00D)
        for address: UInt32 in [0x8000_0100, 0xA000_0100, 0x0020_0100, 0x0060_0100, 0x8060_0100] {
            #expect(try bus.load32(address) == 0xCAFE_F00D)
        }
        try bus.store8(0xA000_0101, 0x12)
        #expect(try bus.load16(0x8000_0100) == 0x120D)
    }

    @Test func pastTheRAMWindowIsABusError() {
        #expect(throws: BusError.self) { try bus.load32(0x0080_0000) }
        #expect(throws: BusError.self) { try bus.store32(0x8100_0000, 0) }
    }

    @Test func theScratchpadIsInKUSEGAndKSEG0ButNotKSEG1() throws {
        try bus.store32(0x1F80_0010, 0x1234_5678)
        #expect(try bus.load32(0x9F80_0010) == 0x1234_5678)
        #expect(try bus.load8(0x1F80_0013) == 0x12)
        #expect(throws: BusError.self) { try bus.load32(0xBF80_0010) }
    }

    @Test func theBIOSIsReadOnlyEverywhere() throws {
        let machine = makeMachine(bios: makeBIOS([0x3C08_0013]))
        for address: UInt32 in [0x1FC0_0000, 0x9FC0_0000, 0xBFC0_0000] {
            try machine.bus.store32(address, 0)
            #expect(try machine.bus.load32(address) == 0x3C08_0013)
        }
        #expect(try machine.bus.load16(0xBFC0_0000) == 0x0013)
    }

    @Test(arguments: [UInt32(0x1F00_0000), 0x1F80_2000, 0x1FA0_0000])
    func emptyExpansionRegionsReadAllOnes(address: UInt32) throws {
        #expect(try bus.load8(address) == 0xFF)
        #expect(try bus.load16(address) == 0xFFFF)
        #expect(try bus.load32(address) == 0xFFFF_FFFF)
    }

    @Test func theCacheControlRegisterKeepsWhatIsWritten() throws {
        try bus.store32(0xFFFE_0130, 0x0001_E988)
        #expect(try bus.load32(0xFFFE_0130) == 0x0001_E988)
    }

    @Test(arguments: [UInt32(0x2000_0000), 0x1F80_0400, 0x1F80_4000, 0x1FC8_0000, 0xFFFE_1000, 0xC000_0000])
    func addressesNothingAnswersAreBusErrors(address: UInt32) {
        #expect(throws: BusError.self) { try bus.load32(address) }
        #expect(throws: BusError.self) { try bus.store32(address, 0) }
    }

    @Test func theScratchpadHoldsNoCode() {
        let machine = makeMachine()
        machine.cpu.jump(to: 0x1F80_0000)
        machine.cpu.step()
        #expect((machine.cpu.cop0Register(COP0Register.cause) >> 2) & 0x1F == ExceptionCode.busErrorInstruction.rawValue)
    }

    @Test func codeRunsFromRAMAndTheBIOS() {
        let machine = makeMachine(bios: makeBIOS([MIPS.addiu(t0, zero, 7)] + halt))
        machine.cpu.step()
        #expect(machine.cpu.register(Int(t0)) == 7)
        machine.load(makeEXE([MIPS.addiu(t1, zero, 9)] + halt))
        machine.cpu.step()
        #expect(machine.cpu.register(Int(t1)) == 9)
    }
}
