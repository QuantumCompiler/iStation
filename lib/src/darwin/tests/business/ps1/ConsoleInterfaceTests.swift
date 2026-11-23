// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

@testable import BusinessPS1
import BusinessR3000A
import SupportMIPS
import Testing

/// The shell's address, where a BIOS hands over to its shell (psx-spx).
let shellAddress: UInt32 = 0x8003_0000

/// BIOS code that stores `words` into RAM at `address`, as a BIOS copies its shell there; uses t0 and t1.
func storing(_ words: [UInt32], at address: UInt32) -> [UInt32] {
    [MIPS.lui(t0, Int(address >> 16)), MIPS.ori(t0, t0, Int(address & 0xFFFF))] + words.enumerated().flatMap { index, word in
        [MIPS.lui(t1, Int(word >> 16)), MIPS.ori(t1, t1, Int(word & 0xFFFF)), MIPS.sw(t1, 4 * index, t0)]
    }
}

/// A 512 KB BIOS built in code — never Sony's — that prints `banner`, runs `padding` nops, copies a
/// stand-in shell to 0x80030000 and jumps there. The stand-in jumps straight back to the BIOS's own
/// endless loop, so once the shell's address is reached the PC leaves it for good; the padding moves
/// where in a run-loop slice it is reached.
func shellBIOS(printing banner: String = "", padding: Int = 0) -> [UInt8] {
    let printed = printing(banner) + [UInt32](repeating: MIPS.nop, count: padding)
    // The stand-in shell is 4 words, so copying it takes 2 + 3 × 4 instructions; then the jump's 3.
    let haltAddress = 0xBFC0_0000 + UInt32(4 * (printed.count + 2 + 3 * 4 + 3))
    let shell = [MIPS.lui(t2, Int(haltAddress >> 16)), MIPS.ori(t2, t2, Int(haltAddress & 0xFFFF)), MIPS.jr(t2), MIPS.nop]
    let program = printed + storing(shell, at: shellAddress) + [MIPS.lui(t0, 0x8003), MIPS.jr(t0), MIPS.nop] + halt
    precondition(UInt32(4 * (program.count - halt.count)) == haltAddress - 0xBFC0_0000)
    return makeBIOS(program)
}

/// A BIOS built in code that prints `banner` and never reaches its shell: istation-run's exit-3 state.
func stuckBIOS(printing banner: String = "") -> [UInt8] {
    makeBIOS(printing(banner) + halt)
}

/// A vertical-blank handler for 0x80000080: it acknowledges I_STAT, counts in s1 and returns to EPC
/// with rfe; it uses k0 and k1.
let vblankHandler = [
    MIPS.lui(k0, 0x1F80), MIPS.sw(zero, 0x1070, k0), MIPS.addiu(s1, s1, 1),
    MIPS.mfc0(k1, UInt32(COP0Register.epc)), MIPS.nop, MIPS.jr(k1), MIPS.rfe,
]

/// BIOS code that unmasks the vertical blank, enables interrupts (SR 0x401) and jumps to 0x80030000.
let enteringTheShellWithInterrupts = [
    MIPS.lui(k0, 0x1F80), MIPS.ori(t0, zero, 1), MIPS.sw(t0, 0x1074, k0), // I_MASK: the vertical blank
    MIPS.ori(t0, zero, 0x401), MIPS.mtc0(t0, UInt32(COP0Register.sr)), // IM2, IEc
    MIPS.lui(t0, 0x8003), MIPS.jr(t0), MIPS.nop,
]

/// A BIOS built in code that takes the vertical blank, as a real one does by its shell: it copies
/// `vblankHandler` to 0x80000080 and a stand-in shell that loops at 0x80030000, then enters it with the
/// vertical blank unmasked and interrupts on. A frame then usually ends with the CPU just entered at
/// the handler, its SR pushed.
func interruptingShellBIOS() -> [UInt8] {
    makeBIOS(storing(vblankHandler, at: 0x8000_0080) + storing(halt, at: shellAddress) + enteringTheShellWithInterrupts + halt)
}

/// A BIOS built in code that enters its shell with the vertical blank already pending: as
/// `interruptingShellBIOS()`, but first it waits with interrupts off until I_STAT shows the vertical
/// blank, then runs `padding` nops. The interrupt is taken at the end of the slice that enables it,
/// wherever the padding has put the PC by then — for some paddings the shell's address, its
/// instruction not yet run.
func pendingVBlankShellBIOS(padding: Int) -> [UInt8] {
    let waiting = [
        MIPS.lui(k0, 0x1F80), MIPS.lw(t0, 0x1070, k0), MIPS.nop, MIPS.andi(t0, t0, 1), MIPS.beq(t0, zero, -4), MIPS.nop,
    ]
    return makeBIOS(storing(vblankHandler, at: 0x8000_0080) + storing(halt, at: shellAddress) + waiting
        + [UInt32](repeating: MIPS.nop, count: padding) + enteringTheShellWithInterrupts + halt)
}

/// Counts the instructions retired at the shell's address: a stand-in shell's, should it ever run.
struct ShellRetirements: R3000ATracer {
    static var isEnabled: Bool { true }
    var count = 0
    mutating func retired(_ instruction: RetiredInstruction) { if instruction.pc == shellAddress { count += 1 } }
}

/// The EXE the boot tests give: it prints "OK" and stops.
let okEXE = makeEXE(printing("OK") + halt)

/// The BIOS's shell as `PS1Machine` sees it: watched from power-on until first reached, then left to
/// putchar capture alone; an EXE boots in its place, and one given after waits for good.
@Suite struct ShellTests {
    @Test func theShellIsWatchedFromPowerOnUntilItIsFirstReached() {
        let machine = makeMachine(bios: shellBIOS())
        #expect(machine.watchesPC)
        #expect(!machine.reachedShell)
        machine.runFrame()
        #expect(machine.reachedShell)
        #expect(!machine.watchesPC) // play pays nothing more once the shell is reached
        #expect(machine.cpu.pc >= 0xBFC0_0000) // the stand-in shell went back to the BIOS's loop
    }

    @Test func reachedShellStaysTrueAfterThePCLeaves() {
        let machine = makeMachine(bios: shellBIOS())
        machine.runFrame()
        machine.runFrame()
        machine.runFrame()
        #expect(machine.cpu.pc != shellAddress)
        #expect(machine.reachedShell)
    }

    @Test func withPutcharCapturedTheWatchStaysOnAfterTheShell() {
        let machine = makeMachine(bios: shellBIOS(), capturesBIOSPutchar: true)
        machine.runFrame()
        #expect(machine.reachedShell)
        #expect(machine.watchesPC)
        machine.bus.copyToRAM(bytes([MIPS.jr(ra), MIPS.nop]), at: 0xB0) // a stand-in for the B-function table
        machine.load(makeEXE([
            MIPS.ori(a0, zero, Int(UInt8(ascii: "A"))), MIPS.ori(t2, zero, 0xB0), MIPS.jalr(ra, t2), MIPS.ori(t1, zero, 0x3D),
        ] + halt))
        machine.runFrame()
        #expect(machine.ttySinceEXE == "A")
    }

    @Test func aBIOSThatNeverReachesItsShellIsWatchedThroughout() {
        let machine = makeMachine(bios: stuckBIOS())
        for _ in 0..<30 { machine.runFrame() }
        #expect(!machine.reachedShell)
        #expect(machine.watchesPC)
    }

    @Test func anEXEGivenBeforeTheShellStartsThereInsteadOfIt() {
        let machine = makeMachine(bios: shellBIOS(printing: "BIOS "))
        machine.boot(okEXE)
        #expect(machine.bootIsPending)
        machine.runFrame()
        #expect(!machine.bootIsPending)
        #expect(machine.reachedShell)
        #expect(machine.tty == "BIOS OK")
        #expect(machine.ttySinceEXE == "OK")
        #expect(!machine.watchesPC)
    }

    @Test func aSecondEXEGivenWhileOneWaitsReplacesIt() {
        let machine = makeMachine(bios: shellBIOS(printing: "BIOS "))
        machine.boot(makeEXE(printing("A") + halt))
        machine.boot(okEXE)
        #expect(machine.bootIsPending)
        machine.runFrame()
        #expect(!machine.bootIsPending)
        #expect(machine.tty == "BIOS OK")
        #expect(machine.ttySinceEXE == "OK")
    }

    @Test func anEXEBootedAtTheShellStartsOutsideAnExceptionAndKeepsTheBIOSsInterrupts() {
        let machine = makeMachine(bios: interruptingShellBIOS())
        machine.boot(okEXE)
        for _ in 0..<5 { machine.runFrame() }
        #expect(!machine.bootIsPending)
        #expect(machine.ttySinceEXE == "OK")
        let handled = machine.cpu.register(Int(s1))
        for _ in 0..<60 { machine.runFrame() }
        #expect(machine.cpu.register(Int(s1)) &- handled == 60) // the BIOS's handler, every frame
    }

    @Test func anEXEGivenAfterTheShellWasReachedWaitsAndTheBIOSKeepsItsInterrupts() {
        // Loading it at once would start it wherever the frame ended — here inside the vertical blank's
        // exception, SR's IEc still pushed and I_STAT never acknowledged, so no interrupt came again.
        let machine = makeMachine(bios: interruptingShellBIOS())
        for _ in 0..<5 { machine.runFrame() }
        #expect(machine.reachedShell)
        let handled = machine.cpu.register(Int(s1))
        #expect(handled > 0)
        machine.boot(okEXE)
        #expect(machine.bootIsPending) // the shell is entered once per power-on
        for _ in 0..<60 { machine.runFrame() }
        #expect(machine.bootIsPending)
        #expect(machine.tty == "")
        #expect(machine.cpu.register(Int(s1)) &- handled == 60)
    }

    @Test func anEXEGivenAfterTheShellWasReachedWaitsEvenWithThePCStillWatched() {
        // With putchar captured the watch stays on, and this stand-in shell loops at 0x80030000 itself.
        let machine = makeMachine(bios: interruptingShellBIOS(), capturesBIOSPutchar: true)
        machine.runFrame()
        #expect(machine.reachedShell && machine.watchesPC)
        machine.boot(okEXE)
        for _ in 0..<3 { machine.runFrame() }
        #expect(machine.bootIsPending)
        #expect(machine.tty == "")
    }

    /// The paddings the slice-boundary tests sweep: more instructions than a 100-cycle slice holds, so
    /// some put the watched address at a slice's first instruction, wherever the slices fall.
    static let paddings = 0..<128

    @Test func aShellReachedAsASlicesFirstInstructionIsTaken() {
        // The run loop leaves the PC its last step reached to the next slice's watch, above that
        // slice's loop: without it, a shell entered there is missed for good.
        var atASlicesStart: [Int] = [], missed: [Int] = [], neverStarted: [Int] = []
        for padding in Self.paddings {
            let bios = shellBIOS(printing: "BIOS ", padding: padding)
            let machine = makeMachine(bios: bios)
            for _ in 0..<1_000 where !machine.reachedShell {
                machine.runSlice()
                // Where a slice leaves the PC is where the next one starts: the watch doesn't move it.
                if machine.cpu.pc == shellAddress { atASlicesStart.append(padding) }
            }
            if !machine.reachedShell { missed.append(padding) }
            let booting = makeMachine(bios: bios)
            booting.boot(okEXE)
            for _ in 0..<1_000 where booting.bootIsPending { booting.runSlice() }
            booting.run(cycles: 1_000)
            if booting.bootIsPending || booting.ttySinceEXE != "OK" { neverStarted.append(padding) }
        }
        #expect(!atASlicesStart.isEmpty, "no padding put the shell at a slice's first instruction")
        #expect(missed.isEmpty, "the shell went unseen with these paddings: \(missed)")
        #expect(neverStarted.isEmpty, "the EXE never started with these paddings: \(neverStarted)")
    }

    @Test func putcharCalledAsASlicesFirstInstructionIsHeardOnce() {
        // The PC the last step reached is watched by the next slice alone, so a putchar call there is
        // heard once: not after the step, and again above the next slice's loop.
        var atASlicesStart: [Int] = [], heard: [Int: String] = [:]
        for padding in Self.paddings {
            let machine = makeMachine(capturesBIOSPutchar: true)
            machine.bus.copyToRAM(bytes([MIPS.jr(ra), MIPS.nop]), at: 0xB0) // a stand-in for the B-function table
            machine.load(makeEXE([UInt32](repeating: MIPS.nop, count: padding) + [
                MIPS.ori(a0, zero, Int(UInt8(ascii: "A"))), MIPS.ori(t2, zero, 0xB0), MIPS.jalr(ra, t2), MIPS.ori(t1, zero, 0x3D),
            ] + halt))
            for _ in 0..<20 {
                machine.runSlice()
                if machine.cpu.pc == 0xB0 { atASlicesStart.append(padding) }
            }
            if machine.tty != "A" { heard[padding] = machine.tty }
        }
        #expect(!atASlicesStart.isEmpty, "no padding put the putchar call at a slice's first instruction")
        #expect(heard.isEmpty, "putchar heard other than once, by padding: \(heard)")
    }

    @Test func aShellInterruptedAtASlicesEndStartsTheEXEOnceTheHandlerReturns() throws {
        // A slice's last step can leave the PC at the shell, for the next slice to watch, and the
        // interrupt check between them moves it to 0x80000080, EPC the shell's address. The EXE starts
        // when the handler returns there — never inside the exception — and the shell never runs.
        var interrupted: [Int] = [], neverStarted: [Int] = [], shellRan: [Int] = [], reachedUnrun: [Int] = []
        for padding in Self.paddings {
            let bios = pendingVBlankShellBIOS(padding: padding)
            let booting = try PS1Machine(bios: bios, tracer: ShellRetirements())
            booting.boot(okEXE)
            var slices = 0
            while booting.bootIsPending, slices < 20_000 {
                booting.runSlice()
                slices += 1
                let cpu = booting.cpu
                if cpu.pc == 0x8000_0080, cpu.cop0Register(COP0Register.epc) == shellAddress, !booting.reachedShell {
                    interrupted.append(padding)
                }
            }
            booting.run(cycles: 1_000)
            // The handler ran once, wherever the interrupt was taken, and the EXE started.
            if booting.bootIsPending || booting.ttySinceEXE != "OK" || booting.cpu.register(Int(s1)) != 1 { neverStarted.append(padding) }
            if booting.cpu.tracer.count > 0 { shellRan.append(padding) }
            // With no EXE, after any slice the shell counts as reached exactly when its instruction has run.
            let plain = try PS1Machine(bios: bios, tracer: ShellRetirements())
            slices = 0
            while plain.cpu.tracer.count == 0, slices < 20_000 {
                plain.runSlice()
                slices += 1
                if plain.reachedShell != (plain.cpu.tracer.count > 0) { reachedUnrun.append(padding) }
            }
        }
        #expect(!interrupted.isEmpty, "no padding had the interrupt taken with the PC at the shell")
        #expect(neverStarted.isEmpty, "the EXE didn't start, once the handler had run, with these paddings: \(neverStarted)")
        #expect(shellRan.isEmpty, "the shell's own instruction ran with these paddings: \(shellRan)")
        #expect(reachedUnrun.isEmpty, "reachedShell and the shell's instruction disagreed with these paddings: \(reachedUnrun)")
    }

    @Test func putcharInterruptedAtASlicesEndIsHeardOnce() {
        // A slice's last step can leave the PC at 0xB0, for the next slice to watch, and the interrupt
        // check between them moves it to 0x80000080, EPC 0xB0 with BD clear: the call is heard once,
        // when the handler returns there, not at the slice's end and again after it.
        var interrupted: [Int] = [], heard: [Int: String] = [:]
        for padding in Self.paddings {
            let machine = makeMachine(capturesBIOSPutchar: true)
            machine.bus.copyToRAM(bytes(vblankHandler), at: 0x8000_0080)
            // A stand-in for the B-function table that isn't itself a branch: a branch at 0xB0 taken in
            // its delay slot returns to it, and the call is heard twice, as it would run twice.
            machine.bus.copyToRAM(bytes([MIPS.nop, MIPS.jr(ra), MIPS.nop]), at: 0xB0)
            machine.runFrame() // the vertical blank is pending now, interrupts still off
            machine.load(makeEXE([
                MIPS.lui(t0, 0x1F80), MIPS.ori(t1, zero, 1), MIPS.sw(t1, 0x1074, t0), // I_MASK: the vertical blank
            ] + [UInt32](repeating: MIPS.nop, count: padding) + [
                MIPS.ori(t0, zero, 0x401), MIPS.mtc0(t0, UInt32(COP0Register.sr)), // IM2, IEc: taken at this slice's end
                MIPS.ori(a0, zero, Int(UInt8(ascii: "A"))), MIPS.ori(t2, zero, 0xB0), MIPS.jalr(ra, t2), MIPS.ori(t1, zero, 0x3D),
            ] + halt))
            for _ in 0..<10 {
                machine.runSlice()
                let cpu = machine.cpu
                if cpu.pc == 0x8000_0080, cpu.cop0Register(COP0Register.epc) == 0xB0, cpu.cop0Register(COP0Register.cause) >> 31 == 0 {
                    interrupted.append(padding)
                }
            }
            if machine.tty != "A" || machine.cpu.register(Int(s1)) != 1 { heard[padding] = machine.tty }
        }
        #expect(!interrupted.isEmpty, "no padding had the interrupt taken with the PC at the putchar call")
        #expect(heard.isEmpty, "putchar heard other than once, or no interrupt taken, by padding: \(heard)")
    }
}

/// `PS1Console`'s boot interface: `boot(exe:)`, `bootIsPending` and `reachedShell`, plain values read
/// between frames.
@Suite struct ConsoleBootTests {
    @Test func anEXEGivenToTheConsoleStartsOnceTheBIOSReachesItsShell() throws {
        let console = PS1Console()
        try console.powerOn(bios: shellBIOS(printing: "BIOS "))
        console.boot(exe: okEXE)
        #expect(console.bootIsPending)
        #expect(!console.reachedShell)
        console.runFrame()
        #expect(!console.bootIsPending)
        #expect(console.reachedShell)
        #expect(console.machine?.ttySinceEXE == "OK")
        #expect(console.machine?.tty == "BIOS OK")
    }

    @Test func anEXEWaitsForAShellTheBIOSNeverReaches() throws {
        let console = PS1Console()
        try console.powerOn(bios: stuckBIOS(printing: "BIOS"))
        console.boot(exe: okEXE)
        for _ in 0..<30 { console.runFrame() } // istation-run's 30 frames, then its exit 3
        #expect(console.bootIsPending)
        #expect(!console.reachedShell)
        #expect(console.machine?.tty == "BIOS")
    }

    @Test func reachedShellTurnsTrueOnceAndStays() throws {
        let console = PS1Console()
        try console.powerOn(bios: shellBIOS())
        #expect(!console.reachedShell)
        console.runFrame()
        #expect(console.reachedShell)
        console.runFrame()
        console.runFrame()
        #expect(console.machine?.cpu.pc != shellAddress)
        #expect(console.reachedShell)
    }

    @Test func anEXEGivenAfterTheShellWasReachedWaitsAndPlaysOnceBootedAfterPoweringOnAgain() throws {
        let console = PS1Console()
        let bios = shellBIOS(printing: "BIOS ")
        try console.powerOn(bios: bios)
        console.runFrame()
        console.boot(exe: okEXE)
        #expect(console.bootIsPending && console.reachedShell) // given too late, not a BIOS that never got there
        console.runFrame()
        #expect(console.machine?.tty == "BIOS ")
        try console.powerOn(bios: bios) // as the library's opening job does: power on, then boot(exe:)
        console.boot(exe: okEXE)
        console.runFrame()
        #expect(!console.bootIsPending)
        #expect(console.machine?.ttySinceEXE == "OK")
    }

    @Test func poweringOnAgainStartsAFreshMachine() throws {
        let console = PS1Console()
        try console.powerOn(bios: shellBIOS())
        console.runFrame()
        #expect(console.reachedShell)
        try console.powerOn(bios: stuckBIOS())
        #expect(!console.reachedShell)
        #expect(console.frame == 0)
        console.boot(exe: okEXE)
        #expect(console.bootIsPending)
        try console.powerOn(bios: shellBIOS())
        #expect(!console.bootIsPending) // the waiting EXE went with the old machine
        #expect(!console.reachedShell)
    }

    @Test func aFailedPowerOnLeavesTheConsoleAsItWas() throws {
        let console = PS1Console()
        let wrongSize = [UInt8](repeating: 0, count: 1000)
        #expect(throws: PS1Error.biosSize(1000)) { try console.powerOn(bios: wrongSize) }
        #expect(!console.isPoweredOn)
        try console.powerOn(bios: shellBIOS(printing: "BIOS "))
        console.runFrame()
        console.boot(exe: okEXE) // given after the shell, so it waits
        #expect(throws: PS1Error.biosSize(1000)) { try console.powerOn(bios: wrongSize) }
        #expect(console.isPoweredOn && console.reachedShell && console.bootIsPending)
        #expect(console.frame == 1)
        #expect(console.machine?.tty == "BIOS ")
    }

    @Test func whilePoweredOffItBootsNothingAndReachesNoShell() throws {
        let console = PS1Console()
        console.boot(exe: okEXE)
        #expect(!console.bootIsPending)
        #expect(!console.reachedShell)
        try console.powerOn(bios: shellBIOS(printing: "BIOS"))
        #expect(!console.bootIsPending)
        console.runFrame()
        #expect(console.reachedShell)
        #expect(console.machine?.tty == "BIOS") // the EXE given while off never ran
    }
}
