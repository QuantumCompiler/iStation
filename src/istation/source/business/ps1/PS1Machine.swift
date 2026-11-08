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

    @exclusivity(unchecked) @usableFromInline var watchesPC = false
    @usableFromInline var exeToBoot: PSEXE?

    @inlinable static var sliceCycles: Int { 100 }

    /// A console powered on with `bios`, its CPU at the reset vector.
    public init(bios: [UInt8], tracer: Tracer, capturesBIOSPutchar: Bool = false) throws(PS1Error) {
        guard bios.count == PS1Bus.biosSize else { throw .biosSize(bios.count) }
        bus = PS1Bus(bios: bios)
        cpu = CPU(bus: bus, cop2: NoCoprocessor2(), tracer: tracer)
        self.capturesBIOSPutchar = capturesBIOSPutchar
        watchesPC = capturesBIOSPutchar
    }

    /// Everything the console printed: expansion 2's TTY, and the BIOS's putchar when captured.
    public var tty: String { String(decoding: bus.expansion2.output, as: UTF8.self) }

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
        while elapsed < Self.sliceCycles {
            if watchesPC { watch() }
            elapsed &+= cpu.step()
        }
        elapsed &+= bus.takeStallCycles()
        elapsedCycles &+= UInt64(elapsed)
        let frameEnded = bus.tick(elapsed)
        if frameEnded { frames += 1 }
        cpu.handleInterrupts()
        return frameEnded
    }

    @usableFromInline
    func watch() {
        let pc = cpu.pc
        if capturesBIOSPutchar && (pc == 0xA0 && cpu.register(9) == 0x3C || pc == 0xB0 && cpu.register(9) == 0x3D) {
            bus.expansion2.append(UInt8(truncatingIfNeeded: cpu.register(4)))
        }
        if pc == 0x8003_0000, let exe = exeToBoot {
            exeToBoot = nil
            watchesPC = capturesBIOSPutchar
            load(exe)
        }
    }

    // MARK: - Programs

    /// Loads `exe` into RAM and starts it now, as the BIOS's exec would: its fill zeroed, r28 its gp,
    /// r29 and r30 its stack — or, when its header names none, the stack the CPU has, else 0x801FFFF0.
    public func load(_ exe: PSEXE) {
        bus.copyToRAM(exe.text, at: exe.destination)
        if exe.fillSize > 0 { bus.zeroRAM(at: exe.fillStart, count: exe.fillSize) } // ProjectPSX skips the fill
        cpu.setRegister(28, exe.gp)
        if exe.stackBase != 0 {
            cpu.setRegister(29, exe.stackBase &+ exe.stackOffset)
            cpu.setRegister(30, exe.stackBase &+ exe.stackOffset)
        } else if cpu.register(29) == 0 {
            cpu.setRegister(29, 0x801F_FFF0)
            cpu.setRegister(30, 0x801F_FFF0)
        }
        cpu.jump(to: exe.pc)
    }

    /// Starts `exe` once the BIOS reaches its shell at 0x80030000 (psx-spx). ProjectPSX patches the
    /// BIOS image at 0xBFC06FF0, which holds only for SCPH-1001; watching the PC holds for any BIOS.
    public func boot(_ exe: PSEXE) {
        exeToBoot = exe
        watchesPC = true
    }
}
