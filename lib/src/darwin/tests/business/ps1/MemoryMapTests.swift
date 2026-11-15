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

    @Test func ramCanBeReadWithoutALoadsCost() throws {
        bus.copyToRAM([1, 2, 3], at: 0x8000_0200)
        #expect(bus.withRAM { Array($0[0x200..<0x203]) } == [1, 2, 3])
        #expect(bus.withRAM { $0.count } == PS1Bus.ramSize)
    }

    @Test func pastTheRAMWindowIsABusError() {
        #expect(throws: BusError.self) { try bus.load32(0x0080_0000) }
        #expect(throws: BusError.self) { try bus.store32(0x8100_0000, 0) }
    }

    @Test func ramSizeSetsTheWindow() throws {
        // psx-spx's DRAM_CTRL table: /RAS0 is 1 MB << (bit 9 << 1 | bit 11), /RAS1 follows while bit 10
        // enables it, and the rest is unmapped.
        try bus.store32(0x0000_0100, 0xCAFE_F00D)
        try bus.store32(0x1F80_1060, 0x0888) // one 2 MB bank, as SetMem(2) leaves it
        #expect(try bus.load32(0x8000_0100) == 0xCAFE_F00D)
        #expect(throws: BusError.self) { try bus.load32(0x0020_0100) }
        #expect(throws: BusError.self) { try bus.store32(0x8060_0100, 0) }
        try bus.store32(0x1F80_1060, 0x0B88) // the BIOS's 8 MB bank: the four mirrors again
        #expect(try bus.load32(0xA060_0100) == 0xCAFE_F00D)
        try bus.store32(0x1F80_1060, 0x0C80) // two 2 MB banks; a retail console's /RAS1 is empty
        #expect(try bus.load32(0x0020_0100) == 0xFFFF_FFFF)
        try bus.store32(0x0020_0100, 0)
        #expect(try bus.load32(0x0000_0100) == 0xCAFE_F00D)
        #expect(throws: BusError.self) { try bus.load32(0x0040_0000) }
    }

    @Test func codePastTheRAMWindowIsABusError() throws {
        let machine = makeMachine()
        try machine.bus.store32(0x1F80_1060, 0x0888)
        machine.cpu.jump(to: 0x8020_0000)
        machine.cpu.step()
        #expect((machine.cpu.cop0Register(COP0Register.cause) >> 2) & 0x1F == ExceptionCode.busErrorInstruction.rawValue)
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

    @Test func theExpansionsEndAtTheirDelaySizeRegistersSize() throws {
        // psx-spx: past 1 << N bytes is a bus error; the BIOS's values give DEV0 512 KB, DEV8 128 bytes
        // and DEV1 1 byte, and its locked list names 1F080000h on and 1F802080h–1FBFFFFFh.
        #expect(try bus.load8(0x1F07_FFFF) == 0xFF)
        #expect(throws: BusError.self) { try bus.load8(0x1F08_0000) }
        #expect(throws: BusError.self) { try bus.store8(0x1F08_0000, 0) }
        #expect(try bus.load8(0x1F80_207F) == 0xFF)
        #expect(throws: BusError.self) { try bus.load8(0x1F80_2084) }
        #expect(throws: BusError.self) { try bus.store8(0x1F80_2100, 0) }
        // ps1-tests' io-access-bitwidth reads and writes a whole word at 0x1FA00000 under DEV1's 0x3022.
        #expect(try bus.load32(0x1FA0_0000) == 0xFFFF_FFFF)
        try bus.store32(0x1FA0_0000, 0)
        #expect(throws: BusError.self) { try bus.load8(0x1FA0_0001) }
        #expect(throws: BusError.self) { try bus.store8(0x1FA0_0001, 0) }
        #expect(throws: BusError.self) { try bus.load32(0xBFBF_FFFC) }
        try bus.store32(0x1F80_1008, 0x0017_243F) // DEV0 at its largest, 8 MB
        #expect(try bus.load32(0x1F7F_FFFC) == 0xFFFF_FFFF)
        try bus.store32(0x1F80_101C, 0x000D_0777) // DEV8 at its largest, 8 KB
        #expect(try bus.load8(0x1F80_3FFF) == 0xFF)
        try bus.store32(0x1F80_100C, 0x0015_3022) // DEV1 at its largest, 2 MB
        #expect(try bus.load8(0x1FBF_FFFF) == 0xFF)
        try bus.store8(0x9FBF_FFFF, 0)
    }

    @Test func codePastExpansion3sSizeIsABusError() {
        let machine = makeMachine()
        machine.cpu.jump(to: 0xBFA0_0004)
        machine.cpu.step()
        #expect((machine.cpu.cop0Register(COP0Register.cause) >> 2) & 0x1F == ExceptionCode.busErrorInstruction.rawValue)
    }

    @Test func projectPSXsTTYPortAnswersPastExpansion2sSize() throws {
        let machine = makeMachine()
        try machine.bus.store8(0x1F80_2080, 0x41)
        #expect(try machine.bus.load8(0x1F80_2080) == 0xFF)
        #expect(machine.tty == "A")
    }

    @Test func theCacheControlRegisterKeepsWhatIsWritten() throws {
        try bus.store32(0xFFFE_0130, 0x0001_E988)
        #expect(try bus.load32(0xFFFE_0130) == 0x0001_E988)
    }

    @Test(arguments: [UInt32(0x1F80_1024), 0x1F80_103C, 0x1F80_1064, 0x1F80_1078, 0x1F80_107C, 0x1F80_1140, 0x1F80_17FC,
                      0x1F80_1804, 0x1F80_1818, 0x1F80_1828, 0x1F80_1BFC, 0xFFFE_0020, 0xFFFE_00FC, 0xFFFE_0140, 0xFFFE_01FC])
    func psxSPXsLockedGapsAreBusErrors(address: UInt32) {
        // psx-spx's "Locked Locations in Memory and I/O Area": the gaps in the I/O region and in KSEG2.
        #expect(throws: BusError.self) { try bus.load32(address) }
        #expect(throws: BusError.self) { try bus.load8(address + 1) }
        #expect(throws: BusError.self) { try bus.store32(address, 0) }
        #expect(throws: BusError.self) { try bus.store16(address + 2, 0) }
    }

    @Test(arguments: [UInt32(0xFFFE_0000), 0xFFFE_0100, 0xFFFE_0134])
    func psxSPXsGarbageAroundCacheControlReadsZero(address: UInt32) throws {
        // psx-spx's "Garbage Locations": unlocked, usually reading 0, and writes have no effect.
        try bus.store32(address, 0xFFFF_FFFF)
        #expect(try bus.load32(address) == 0)
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
