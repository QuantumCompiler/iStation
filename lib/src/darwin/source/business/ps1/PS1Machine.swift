// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2019 Pedro Cortés
// SPDX-FileCopyrightText: 2026 iStation contributors
// Ported from BluestormDNA/ProjectPSX/ProjectPSX/Core/ProjectPSX.cs — Copyright (c) 2019 Pedro Cortés

import BusinessR3000A

/// Why a console can't power on.
public enum PS1Error: Error, Equatable, Sendable {
    /// A BIOS image is 512 KB; this one is `count` bytes.
    case biosSize(Int)
}

/// The PS1's hardware: the R3000A over the PS1's bus, and ProjectPSX's run loop — the CPU for a slice
/// of about 100 cycles, then the devices for the cycles it took, then the interrupt check. Generic
/// over the tracer, which a release build makes `NoTracer` (ADR 0016).
///
/// Its devices run at the CPU's real rate, loads' wait states included; ProjectPSX instead runs them
/// three times faster than its loads-cost-nothing CPU.
public final class PS1Machine<Tracer: R3000ATracer> {
    /// No GTE until v0.2.0: COP2, LWC2 and SWC2 raise Coprocessor Unusable even with SR's CU2 set.
    public typealias CPU = R3000A<PS1Bus, NoCoprocessor2, Tracer>

    public let bus: PS1Bus
    public let cpu: CPU
    /// Whether the BIOS's putchar calls (A(3Ch), B(3Dh)) are copied to `tty`: how a program printing
    /// through the BIOS is heard, as ProjectPSX's `TTY()` hears it.
    public let capturesBIOSPutchar: Bool

    /// Vertical blanks so far.
    public var frame: Int { frames }
    /// System-clock cycles so far: every fetch's and every load's.
    public var cycles: UInt64 { elapsedCycles }

    @exclusivity(unchecked) @usableFromInline var frames = 0
    @exclusivity(unchecked) @usableFromInline var elapsedCycles: UInt64 = 0

    /// Whether `runSlice()` looks at each instruction's address: from power-on until the BIOS first
    /// reaches its shell, and for as long as putchar is captured. Once it is false, play pays one Bool
    /// test per instruction and nothing more (ADR 0015 §4).
    @exclusivity(unchecked) @usableFromInline var watchesPC = true
    @usableFromInline var exeToBoot: PSEXE?
    @exclusivity(unchecked) var shellReached = false

    @inlinable static var sliceCycles: Int { 100 }

    /// Every bit outside 0x80030000 (the shell), 0xA0 and 0xB0 (the BIOS's A and B function tables): an
    /// address with any of them set is none of the three. The 64 with none set pass, among them
    /// 0x80010000, where PS-EXEs start, and 0x80000080, the exception vector.
    @inlinable static var watchedAddressesMask: UInt32 { ~(0x8003_0000 | 0xA0 | 0xB0) }

    /// Whether `pc` is one of the three addresses `watch()` takes: one AND turns away all but 64
    /// addresses, and three compares, inline, the 61 left, so only the three pay `watch()`'s call.
    @inlinable @inline(__always)
    static func isWatched(_ pc: UInt32) -> Bool {
        pc & watchedAddressesMask == 0 && (pc == 0x8003_0000 || pc == 0xB0 || pc == 0xA0)
    }

    /// A console powered on with `bios`, its CPU at the reset vector.
    public init(bios: [UInt8], tracer: Tracer, capturesBIOSPutchar: Bool = false) throws(PS1Error) {
        guard bios.count == PS1Bus.biosSize else { throw .biosSize(bios.count) }
        bus = PS1Bus(bios: bios)
        cpu = CPU(bus: bus, cop2: NoCoprocessor2(), tracer: tracer)
        self.capturesBIOSPutchar = capturesBIOSPutchar
    }

    /// Everything the console printed: expansion 2's TTY, and the BIOS's putchar when captured.
    public var tty: String { String(decoding: bus.expansion2.output, as: UTF8.self) }

    /// What the console printed since the last PS-EXE started — without the BIOS's own messages, which a
    /// test's expected output leaves out — or everything, when no EXE has started.
    public var ttySinceEXE: String {
        let output = bus.expansion2.output
        return String(decoding: output.suffix(min(bus.expansion2.ttyCount - ttyBeforeEXE, output.count)), as: UTF8.self)
    }

    /// `expansion2.ttyCount` when the last PS-EXE started.
    private var ttyBeforeEXE = 0

    /// True while an EXE given to `boot(_:)` waits for the BIOS to reach its shell — for good when the
    /// BIOS never gets there, or got there before the EXE was given: until then `ttySinceEXE` is the
    /// BIOS's own output, not the EXE's.
    public var bootIsPending: Bool { exeToBoot != nil }

    /// True from the first time the PC reaches 0x80030000, the BIOS's shell (psx-spx), on — even after
    /// the PC leaves it, or an EXE started there takes over. Booted through a BIOS, as `PS1Console`
    /// always is, that is the BIOS getting through its boot; on a machine whose EXE `load(_:)` started
    /// at once, code of the EXE's own at that address turns it true too.
    public var reachedShell: Bool { shellReached }

    // MARK: - Running

    /// Runs until the next vertical blank.
    @inlinable
    public func runFrame() {
        while !runSlice() {}
    }

    /// Runs whole slices until at least `cycles` system-clock cycles have passed.
    @inlinable
    public func run(cycles budget: UInt64) {
        let end = elapsedCycles &+ budget
        while elapsedCycles < end { runSlice() }
    }

    /// One slice; true when it ended a frame.
    @inlinable
    @discardableResult
    public func runSlice() -> Bool {
        var elapsed = 0
        // A slice counts every cycle — fetches and loads' wait states — so device ticks, DMA blocks and
        // interrupt checks keep their cadence through load-heavy code.
        //
        // Each instruction's address is watched once, just before it runs: the slice's first above the
        // loop, as the interrupt check may have moved the PC, and each next one straight after the step
        // before it, while the PC is at hand; the slice's last step leaves its PC to the next slice. The
        // Bool goes first: once the shell is reached and putchar isn't captured, it is all play pays.
        // While watching, `isWatched` costs an AND, and three compares for the 64 addresses that pass
        // it, so a loop through 0x80010000 or the exception vector pays no call. On the CPU-check
        // image, which never reaches a shell and so is watched throughout, watching cost at most 0.4%,
        // within the runs' noise (20 interleaved runs of 6,000 frames against the loop before 6a,
        // 2026-11-22): a boot's cost, by design, and nothing once the shell is reached.
        if watchesPC, Self.isWatched(cpu.pc) { watch() }
        while elapsed < Self.sliceCycles {
            elapsed &+= cpu.step() &+ bus.takeStallCycles()
            if watchesPC, Self.isWatched(cpu.pc), elapsed < Self.sliceCycles { watch() }
        }
        elapsedCycles &+= UInt64(elapsed)
        let frameEnded = bus.tick(elapsed)
        if frameEnded { frames += 1 }
        cpu.handleInterrupts()
        return frameEnded
    }

    /// The PC is one of the three watched addresses: hears putchar when captured, and takes the shell's
    /// first visit.
    @usableFromInline
    func watch() {
        let pc = cpu.pc
        if capturesBIOSPutchar && (pc == 0xA0 && cpu.register(9) == 0x3C || pc == 0xB0 && cpu.register(9) == 0x3D) {
            bus.expansion2.append(UInt8(truncatingIfNeeded: cpu.register(4)))
        }
        if pc == 0x8003_0000, !shellReached {
            shellReached = true
            watchesPC = capturesBIOSPutchar // the shell is reached once: only putchar still needs the PC
            if let exe = exeToBoot {
                exeToBoot = nil
                load(exe)
            }
        }
    }

    // MARK: - Programs

    /// Loads `exe` into RAM and starts it now, as the BIOS's exec would: its fill zeroed, r28 its gp,
    /// r29 and r30 its stack — or, when its header names none, the stack the CPU has, else 0x801FFFF0.
    public func load(_ exe: PSEXE) {
        cpu.settlePendingLoad() // a BIOS load still in flight lands before the loader's registers
        ttyBeforeEXE = bus.expansion2.ttyCount
        bus.copyToRAM(exe.text, at: exe.destination)
        if exe.fillSize > 0 { bus.zeroRAM(at: exe.fillStart, count: exe.fillSize) } // ProjectPSX skips the fill
        cpu.setRegister(28, exe.gp)
        // psx-spx: r29 and r30 both start at base + offset; ProjectPSX gives r29 the base alone. With no
        // stack in the header, the CPU's stays — and when there is none, as when an EXE runs without a
        // BIOS, 0x801FFFF0 (iStation's stand-in for a caller's stack, not either reference's).
        if exe.stackBase != 0 {
            cpu.setRegister(29, exe.stackBase &+ exe.stackOffset)
            cpu.setRegister(30, exe.stackBase &+ exe.stackOffset)
        } else if cpu.register(29) == 0 {
            cpu.setRegister(29, 0x801F_FFF0)
            cpu.setRegister(30, 0x801F_FFF0)
        }
        cpu.jump(to: exe.pc)
    }

    /// Starts `exe` once the BIOS reaches its shell at 0x80030000 (psx-spx), in place of the shell. The
    /// shell is entered once per power-on, so an EXE given after the BIOS reached it waits for good
    /// (`bootIsPending` beside `reachedShell`), and playing it takes a fresh machine and the EXE given
    /// to that one: loaded at once, it would start wherever the BIOS was — at a frame's end often inside
    /// an interrupt's exception, SR pushed and the interrupt unacknowledged, so none would come again. A
    /// second EXE given while one waits replaces it. ProjectPSX patches the BIOS image at 0xBFC06FF0,
    /// which holds only for SCPH-1001; watching the PC holds for any BIOS.
    public func boot(_ exe: PSEXE) {
        exeToBoot = exe
    }
}
