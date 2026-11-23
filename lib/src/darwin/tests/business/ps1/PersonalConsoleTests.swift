// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

#if PERSONAL_BUILD
@testable import BusinessPS1
import BusinessR3000A
import SupportMIPS
import SupportR3000ATrace
import SupportSandbox
import Testing

/// `knownStateBIOS()`'s program: it loads a word from the BIOS — wait states the system clock counts
/// and the CPU's cycles don't — sets known registers, multiplies, sets SR's BEV and raises a syscall.
let knownStateProgram = [
    MIPS.lui(t3, 0xBFC0), MIPS.lw(t2, 0, t3), MIPS.nop,
    MIPS.ori(t0, zero, 0x1234), MIPS.lui(t1, 0x5678), MIPS.ori(t1, t1, 0x9ABC), MIPS.mult(t0, t1),
    MIPS.lui(t2, 0x0040), MIPS.mtc0(t2, 12), MIPS.nop, MIPS.ori(s0, zero, 0x55), MIPS.syscall, MIPS.nop,
]

/// A BIOS built in code that runs `knownStateProgram`, whose syscall's handler at 0xBFC00180 is an
/// endless loop: every value a snapshot carries ends up known.
func knownStateBIOS() -> [UInt8] {
    let vector = 0x180 / 4
    return makeBIOS(knownStateProgram + [UInt32](repeating: MIPS.nop, count: vector - knownStateProgram.count) + halt)
}

/// Where `knownStateBIOS()`'s syscall sits.
let knownSyscallAddress = 0xBFC0_0000 + 4 * UInt32(knownStateProgram.firstIndex(of: MIPS.syscall)!)

/// One retired instruction's address and word, as a recorder sees them.
struct Retired: Equatable {
    let pc: UInt32
    let word: UInt32
}

/// Keeps every retired instruction's address and word.
struct RecordingTracer: R3000ATracer {
    static var isEnabled: Bool { true }
    var records: [Retired] = []
    mutating func retired(_ instruction: RetiredInstruction) { records.append(Retired(pc: instruction.pc, word: instruction.word)) }
}

/// FNV-1a over guest RAM, as a frame record's checksum is taken.
func checksum(_ ram: UnsafeRawBufferPointer) -> UInt64 {
    ram.reduce(0xCBF2_9CE4_8422_2325) { ($0 ^ UInt64($1)) &* 0x100_0000_01B3 }
}

/// A frame record's RAM checksum as `istation-run run` takes it: TraceKit's FNV-1a over guest RAM.
func traceKitRAMChecksum(_ ram: UnsafeRawBufferPointer) -> UInt64 {
    var hash = FNV1a64()
    hash.add(bytes: ram)
    return hash.value
}

/// An EXE that prints "OK", then counts at 0x80020000 forever, three BIOS loads a turn to keep a
/// frame's instructions few: RAM is different at every frame's end.
let countingEXE = makeEXE(printing("OK") + [
    MIPS.lui(s0, 0xBFC0), MIPS.lui(s2, 0x8002),
    MIPS.lw(t2, 0, s0), MIPS.lw(t2, 4, s0), MIPS.lw(t2, 8, s0),
    MIPS.addiu(s1, s1, 1), MIPS.sw(s1, 0, s2), MIPS.beq(zero, zero, -6), MIPS.nop,
])

/// The debug values a personal build reads between frames: one `Sendable` value (6a).
@Suite struct DebugSnapshotTests {
    @Test func theSnapshotMatchesTheCPUAfterAKnownProgram() {
        let machine = makeMachine(bios: knownStateBIOS())
        machine.runFrame()
        let snapshot = machine.debugSnapshot
        let cpu = machine.cpu
        #expect(snapshot.registers == (0..<32).map(cpu.register))
        #expect(snapshot.pc == cpu.pc)
        #expect(snapshot.hi == cpu.hi)
        #expect(snapshot.lo == cpu.lo)
        #expect(snapshot.sr == cpu.cop0Register(COP0Register.sr))
        #expect(snapshot.cause == cpu.cop0Register(COP0Register.cause))
        #expect(snapshot.epc == cpu.cop0Register(COP0Register.epc))
        #expect(snapshot.cycles == cpu.cycles)
        #expect(snapshot.cycles < machine.cycles) // the CPU's, not the system clock's: the BIOS load's wait states
        #expect(snapshot.frame == 1)
        // And the values are the program's, not zeros.
        let product = UInt64(0x1234) * 0x5678_9ABC
        #expect(snapshot.registers.count == 32 && snapshot.registers[0] == 0)
        #expect(snapshot.registers[Int(t0)] == 0x1234 && snapshot.registers[Int(t1)] == 0x5678_9ABC && snapshot.registers[Int(s0)] == 0x55)
        #expect(snapshot.hi == UInt32(product >> 32) && snapshot.lo == UInt32(truncatingIfNeeded: product))
        #expect(snapshot.sr & 0x0040_0000 != 0) // BEV
        #expect(snapshot.cause >> 2 & 0x1F == ExceptionCode.syscall.rawValue)
        #expect(snapshot.epc == knownSyscallAddress)
        #expect(snapshot.pc >= 0xBFC0_0180 && snapshot.pc < 0xBFC0_0188) // in the handler's loop
        #expect(snapshot.cycles > 0)
    }

    @Test func theSnapshotCarriesTheTTY() {
        let machine = makeMachine(bios: shellBIOS(printing: "BIOS "))
        machine.boot(okEXE)
        machine.runFrame()
        #expect(machine.debugSnapshot.tty == "BIOS OK")
        #expect(machine.debugSnapshot.ttySinceEXE == "OK")
    }

    @Test func theConsolesSnapshotIsItsMachinesTakenBetweenFrames() throws {
        let console = PS1Console()
        #expect(console.debugSnapshot == nil)
        try console.powerOn(bios: knownStateBIOS())
        console.runFrame()
        let snapshot = try #require(console.debugSnapshot)
        #expect(snapshot == console.machine?.debugSnapshot)
        #expect(snapshot.registers == (0..<32).map { console.machine!.cpu.register($0) })
        #expect(snapshot.frame == console.frame)
        #expect(snapshot.epc == knownSyscallAddress)
    }
}

/// The personal-only console generic over its tracer, for 5f's recordings.
@Suite struct TracingConsoleTests {
    @Test func itsTracerSeesWhatAMachinesDoesOverTheSameImageAndFrames() throws {
        let console = PS1TracingConsole<RecordingTracer>()
        try console.powerOn(bios: shellBIOS(printing: "BIOS "), tracer: RecordingTracer())
        console.boot(exe: okEXE)
        let machine = try PS1Machine(bios: shellBIOS(printing: "BIOS "), tracer: RecordingTracer())
        machine.boot(okEXE)
        for _ in 0..<3 {
            console.runFrame()
            machine.runFrame()
        }
        let traced = try #require(console.tracer).records
        #expect(traced.count > 1_000)
        #expect(traced.count == machine.cpu.tracer.records.count)
        let same = traced == machine.cpu.tracer.records // one Bool: a failure shouldn't print both streams
        #expect(same)
        #expect(traced.contains { $0.pc == programOrigin }) // the EXE ran
        #expect(console.reachedShell && !console.bootIsPending)
        #expect(console.frame == 3)
        #expect(console.debugSnapshot == machine.debugSnapshot)
    }

    @Test func itRecordsTraceKitsInstructionAndFrameRecordsAsIstationRunDoes() throws {
        let sandbox = try Sandbox()
        let bios = shellBIOS(printing: "BIOS ")
        let frames = 3
        let instructions = TraceHeader(granularity: .instruction, fullStateInterval: 1_000)

        // The tracing console, as a personal build records: its tracer's instruction records, and a
        // frame record after each frame with the RAM checksum read through `withRAM`.
        let consoleWriter = try TraceWriter(url: sandbox.url("console.instructions.trace"), header: instructions)
        let consoleFrames = try TraceWriter(url: sandbox.url("console.frames.trace"), header: TraceHeader(granularity: .frame))
        let console = PS1TracingConsole<TraceKitTracer>()
        try console.powerOn(bios: bios, tracer: TraceKitTracer(writer: consoleWriter))
        console.boot(exe: countingEXE)
        for frame in 0..<frames {
            console.runFrame()
            let ramChecksum = try #require(console.withRAM(traceKitRAMChecksum))
            try consoleFrames.append(FrameRecord(frame: UInt64(frame), ramChecksum: ramChecksum, imageChecksum: 0, audioChecksum: 0))
        }
        try consoleFrames.finish()
        let consoleTracer = try #require(console.tracer)
        #expect(consoleTracer.error == nil)
        try consoleWriter.finish()
        #expect(console.reachedShell && !console.bootIsPending)

        // istation-run's run over the same image: PS1Machine with the tracer, a frame record per frame.
        let machineWriter = try TraceWriter(url: sandbox.url("run.instructions.trace"), header: instructions)
        let machineFrames = try TraceWriter(url: sandbox.url("run.frames.trace"), header: TraceHeader(granularity: .frame))
        let machine = try PS1Machine(bios: bios, tracer: TraceKitTracer(writer: machineWriter), capturesBIOSPutchar: false)
        machine.boot(countingEXE)
        for frame in 0..<frames {
            machine.runFrame()
            try machineFrames.append(FrameRecord(
                frame: UInt64(frame),
                ramChecksum: machine.bus.withRAM { ram in var hash = FNV1a64(); hash.add(bytes: ram); return hash.value },
                imageChecksum: 0, audioChecksum: 0
            ))
        }
        try machineFrames.finish()
        #expect(machine.cpu.tracer.error == nil)
        try machineWriter.finish()

        // Read back: the console's traces are istation-run's, record for record, and not empty.
        var instructionRecords = 0, fullStateRecords = 0, exeRan = false
        let reader = try TraceReader(url: sandbox.url("console.instructions.trace"))
        #expect(reader.header == instructions)
        while let record = try reader.next() {
            switch record {
            case .instruction(let instruction):
                instructionRecords += 1
                if instruction.pc == programOrigin { exeRan = true }
            case .fullState: fullStateRecords += 1
            case .frame: Issue.record("a frame record in an instruction trace")
            }
        }
        #expect(instructionRecords > 10_000)
        #expect(fullStateRecords == instructionRecords / 1_000)
        #expect(exeRan)
        let frameRecords = try TraceReader(url: sandbox.url("console.frames.trace")).readAll()
        let checksums = frameRecords.compactMap { record -> UInt64? in
            guard case .frame(let frame) = record else { return nil }
            return frame.ramChecksum
        }
        #expect(checksums.count == frames)
        #expect(Set(checksums).count == frames) // the EXE changed RAM every frame
        #expect(checksums.last == machine.bus.withRAM(checksum))
        #expect(try TraceDiff.firstDivergence(sandbox.url("console.instructions.trace"), sandbox.url("run.instructions.trace")) == nil)
        #expect(try TraceDiff.firstDivergence(sandbox.url("console.frames.trace"), sandbox.url("run.frames.trace")) == nil)
    }

    @Test func withRAMReadsTheGuestsRAM() throws {
        let console = PS1TracingConsole<NoTracer>()
        #expect(console.withRAM { $0.count } == nil)
        try console.powerOn(bios: shellBIOS(), tracer: NoTracer())
        console.boot(exe: okEXE)
        console.runFrame()
        #expect(console.withRAM { $0.count } == PS1Bus.ramSize)
        #expect(console.withRAM { $0.load(fromByteOffset: 0x1_0000, as: UInt32.self) } == okEXE.text.withUnsafeBytes { $0.load(as: UInt32.self) })
        let machine = try PS1Machine(bios: shellBIOS(), tracer: NoTracer())
        machine.boot(okEXE)
        machine.runFrame()
        #expect(console.withRAM(checksum) == machine.bus.withRAM(checksum))
    }

    @Test func itIsOffUntilPoweredOnAndFreshEachTime() throws {
        let console = PS1TracingConsole<CountingTracer>()
        #expect(PS1TracingConsole<CountingTracer>.name == "PS1")
        #expect(!console.isPoweredOn && console.tracer == nil && console.debugSnapshot == nil)
        console.boot(exe: okEXE)
        console.runFrame()
        #expect(console.frame == 0 && !console.bootIsPending && !console.reachedShell)
        try console.powerOn(bios: shellBIOS(), tracer: CountingTracer())
        console.runFrame()
        #expect(console.isPoweredOn && console.reachedShell && console.frame == 1)
        #expect((console.tracer?.count ?? 0) > 0)
        try console.powerOn(bios: shellBIOS(), tracer: CountingTracer(), capturesBIOSPutchar: true)
        #expect(console.tracer?.count == 0 && !console.reachedShell && console.frame == 0)
        #expect(console.machine?.capturesBIOSPutchar == true)
        console.runFrame()
        let counted = try #require(console.tracer).count
        #expect(throws: PS1Error.biosSize(1000)) { try console.powerOn(bios: [UInt8](repeating: 0, count: 1000), tracer: CountingTracer()) }
        // A failed power-on changes nothing: the machine, its tracer and its putchar capture stay.
        #expect(console.isPoweredOn && console.reachedShell && console.frame == 1)
        #expect(console.tracer?.count == counted && counted > 0 && console.machine?.capturesBIOSPutchar == true)
    }

    @Test func anEXEWaitsForAShellTheBIOSNeverReaches() throws {
        let console = PS1TracingConsole<CountingTracer>()
        try console.powerOn(bios: stuckBIOS(printing: "BIOS"), tracer: CountingTracer())
        console.boot(exe: okEXE)
        for _ in 0..<30 { console.runFrame() } // istation-run's 30 frames, then its exit 3
        #expect(console.bootIsPending)
        #expect(!console.reachedShell)
        #expect(console.debugSnapshot?.tty == "BIOS")
        #expect(console.debugSnapshot?.ttySinceEXE == "BIOS") // no EXE has started
    }
}
#endif
