// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessPS1
import BusinessR3000A
import SupportMIPS
import Testing

/// PS-EXE files and running them (psx-spx, "CDROM File Formats").
@Suite struct PSEXETests {
    @Test func anEXERoundTripsThroughItsBytes() throws {
        let exe = PSEXE(pc: 0x8001_0000, gp: 0x8001_8000, destination: 0x8001_0000, text: [UInt8](repeating: 0xA5, count: 0x800),
                        fillStart: 0x8002_0000, fillSize: 0x100, stackBase: 0x801F_FF00, stackOffset: 0x10)
        let bytes = exe.bytes
        #expect(bytes.count == 0x1000)
        #expect(Array(bytes[0..<8]) == Array("PS-X EXE".utf8))
        #expect(try PSEXE(bytes: bytes) == exe)
    }

    @Test func aShortOrForeignFileIsRejected() {
        #expect(throws: PSEXEError.tooShort) { try PSEXE(bytes: [UInt8](repeating: 0, count: 100)) }
        #expect(throws: PSEXEError.notAnEXE) { try PSEXE(bytes: [UInt8](repeating: 0x41, count: 0x1000)) }
    }

    @Test func aHeaderSizePastTheFileIsTrustedOnlyAsFarAsTheFileGoes() throws {
        var bytes = PSEXE(pc: 0x8001_0000, destination: 0x8001_0000, text: [1, 2, 3, 4]).bytes
        bytes[0x1D] = 0xFF // claims 0xFF00 more bytes
        #expect(try PSEXE(bytes: bytes).text.count == 0x800)
    }

    @Test func loadingSetsTheRegistersFillsAndStarts() throws {
        let machine = makeMachine()
        try machine.bus.store32(0x8002_0000, 0xFFFF_FFFF)
        machine.load(PSEXE(pc: 0x8001_0004, gp: 0x1234, destination: 0x8001_0000, text: bytes([0xAAAA_AAAA]),
                           fillStart: 0x8002_0000, fillSize: 4, stackBase: 0x801F_0000, stackOffset: 0x100))
        #expect(machine.cpu.pc == 0x8001_0004)
        #expect(try machine.bus.load32(0x8001_0000) == 0xAAAA_AAAA)
        #expect(try machine.bus.load32(0x8002_0000) == 0)
        #expect(machine.cpu.register(Int(gp)) == 0x1234)
        #expect(machine.cpu.register(Int(sp)) == 0x801F_0100)
        #expect(machine.cpu.register(Int(fp)) == 0x801F_0100)
    }

    @Test func anEXEWithNoStackGetsTheUsualOne() {
        let machine = makeMachine()
        machine.load(makeEXE(halt))
        #expect(machine.cpu.register(Int(sp)) == 0x801F_FFF0)
    }
}

/// The TTY: expansion 2's, and the BIOS's putchar.
@Suite struct TTYTests {
    @Test func aProgramPrintsThroughExpansion2() {
        let machine = makeMachine()
        machine.load(makeEXE(printing("Hi!\n") + halt))
        machine.runFrame()
        #expect(machine.tty == "Hi!\n")
    }

    @Test(arguments: [true, false])
    func theBIOSsPutcharIsHeardWhenCaptured(capturing: Bool) {
        let machine = makeMachine(capturesBIOSPutchar: capturing)
        machine.bus.copyToRAM(bytes([MIPS.jr(ra), MIPS.nop]), at: 0xB0) // a stand-in for the B-function table
        machine.load(makeEXE([
            // B(3Dh), putchar, called as the BIOS's libraries call it: a jump to 0xB0 with t1 the function.
            MIPS.ori(a0, zero, Int(UInt8(ascii: "A"))), MIPS.ori(t2, zero, 0xB0), MIPS.jalr(ra, t2), MIPS.ori(t1, zero, 0x3D),
        ] + halt))
        machine.runFrame()
        #expect(machine.tty == (capturing ? "A" : ""))
    }

    @Test func anEXEBootsOnceTheBIOSReachesItsShell() {
        // A BIOS built in code whose reset jumps straight to the shell's address.
        let machine = makeMachine(bios: makeBIOS([MIPS.lui(t0, 0x8003), MIPS.jr(t0), MIPS.nop]))
        machine.boot(makeEXE(printing("OK") + halt))
        machine.runFrame()
        #expect(machine.tty == "OK")
    }
}

/// What loads cost (psx-spx, "Memory Control"; ps1-tests' access-time log, on hardware).
@Suite struct AccessTimingTests {
    @Test func psxSpxsFormulaGivesTheHardwaresBIOSAndExpansionTimes() {
        let com: UInt32 = 0x0003_1125
        #expect(MemoryControl.times(delaySize: 0x0013_243F, comDelay: com) == .init(byte: 7, halfword: 13, word: 25))
        #expect(MemoryControl.times(delaySize: 0x0000_3022, comDelay: com) == .init(byte: 6, halfword: 6, word: 10))
    }

    /// Instructions retired in about `budget` cycles by a loop of `load`, a branch and its delay slot.
    func retired(_ load: UInt32, base: UInt32, budget: UInt64 = 70_000) -> (instructions: Int, cycles: UInt64) {
        let machine = try! PS1Machine(bios: makeBIOS(), tracer: CountingTracer())
        machine.load(makeEXE([MIPS.lui(s0, Int(base >> 16)), load, MIPS.beq(zero, zero, -2), MIPS.nop]))
        machine.run(cycles: budget)
        return (machine.cpu.tracer.count, machine.cycles)
    }

    @Test(arguments: [
        (MIPS.nop, UInt32(0x8000_0000), 3), // three 1-cycle fetches
        (MIPS.lw(t0, 0, s0), UInt32(0x8000_0000), 7), // RAM: 5
        (MIPS.lbu(t0, 0, s0), UInt32(0xBFC0_0000), 9), // BIOS, a byte: 7
        (MIPS.lw(t0, 0, s0), UInt32(0xBFC0_0000), 27), // BIOS, a word: 25
        (MIPS.lw(t0, 0, s0), UInt32(0x1F80_0000), 3), // scratchpad: 1
        (MIPS.lw(t0, 0x1070, s0), UInt32(0x1F80_0000), 5), // an I/O port: 3
    ])
    func eachLoadCostsItsRegionsAccessTime(load: UInt32, base: UInt32, cyclesPerLoop: Int) {
        let (instructions, cycles) = retired(load, base: base)
        let loops = Double(instructions - 1) / 3
        #expect(abs(Double(cycles) / loops - Double(cyclesPerLoop)) < 0.05)
    }
}

/// The console the apps hold.
@Suite struct PS1ConsoleTests {
    @Test func aNewConsoleIsPoweredOff() {
        let console = PS1Console()
        #expect(!console.isPoweredOn)
        #expect(PS1Console.name == "PlayStation")
        console.runFrame()
        #expect(console.frame == 0)
    }

    @Test func itPowersOnOnlyWithA512KBBIOS() throws {
        let console = PS1Console()
        #expect(throws: PS1Error.biosSize(1024)) { try console.powerOn(bios: [UInt8](repeating: 0, count: 1024)) }
        #expect(!console.isPoweredOn)
        try console.powerOn(bios: makeBIOS())
        #expect(console.isPoweredOn)
        console.runFrame()
        #expect(console.frame == 1)
    }
}
