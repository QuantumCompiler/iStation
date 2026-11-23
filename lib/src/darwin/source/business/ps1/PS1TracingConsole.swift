// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2019 Pedro Cortés
// SPDX-FileCopyrightText: 2026 iStation contributors
// Ported from BluestormDNA/ProjectPSX/ProjectPSX/Core/ProjectPSX.cs — Copyright (c) 2019 Pedro Cortés

#if PERSONAL_BUILD
import BusinessR3000A

/// `PS1Console` with a tracer: the same members, over a machine that hands every retired instruction
/// to `Tracer`, for a personal build's trace recordings — TraceKit's instruction and frame records,
/// as `istation-run run` writes them. `PS1Console` stays fixed to `NoTracer`, so the App Store build's
/// specialization is untouched; this type exists only in personal builds (ADR 0016). The tracer that
/// turns retired instructions into TraceKit's records lives outside the core, which never imports TraceKit.
public final class PS1TracingConsole<Tracer: R3000ATracer> {
    /// The console's name, as the player shows it: `PS1Console`'s.
    public static var name: String { PS1Console.name }

    var machine: PS1Machine<Tracer>?

    /// A console powered off, with no machine until `powerOn(bios:tracer:capturesBIOSPutchar:)`.
    public init() {}

    /// False until the console has a BIOS to run.
    public var isPoweredOn: Bool { machine != nil }

    /// Powers on with the user's BIOS image, 512 KB, its CPU at the reset vector and `tracer` watching
    /// it: a fresh machine each time, the previous tracer let go. With `capturesBIOSPutchar`, the BIOS's
    /// putchar calls reach the TTY too, as `istation-run run --tty` hears them. An image of another size
    /// throws and changes nothing: the console stays as it was, its machine and tracer kept.
    public func powerOn(bios: [UInt8], tracer: Tracer, capturesBIOSPutchar: Bool = false) throws(PS1Error) {
        machine = try PS1Machine(bios: bios, tracer: tracer, capturesBIOSPutchar: capturesBIOSPutchar)
    }

    /// Runs one frame, to the next vertical blank; nothing while powered off.
    public func runFrame() {
        machine?.runFrame()
    }

    /// Vertical blanks since power-on.
    public var frame: Int { machine?.frame ?? 0 }

    /// Starts a PS-EXE as the BIOS's shell would, in its place, once the BIOS reaches it; one given once
    /// `reachedShell` is true waits for good — to play it, power on again and give it to `boot(exe:)`
    /// again. Nothing while powered off.
    public func boot(exe: PSEXE) {
        machine?.boot(exe)
    }

    /// True while an EXE given to `boot(exe:)` waits for the BIOS to reach its shell — for good, when
    /// the BIOS never gets there or already had; false while powered off.
    public var bootIsPending: Bool { machine?.bootIsPending ?? false }

    /// True once the BIOS has reached its shell since power-on, and from then on; false while powered off.
    public var reachedShell: Bool { machine?.reachedShell ?? false }

    /// The console's state between frames; nil while powered off.
    public var debugSnapshot: PS1DebugSnapshot? { machine?.debugSnapshot }

    /// The tracer as it stands after the instructions so far — a copy, whose references (a trace
    /// writer) are the console's own, so a recorder reads its count or failure and finishes its writer
    /// through it; nil while powered off.
    public var tracer: Tracer? { machine?.cpu.tracer }

    /// Guest RAM's 2 MB, read-only and without a load's cost, for a frame record's RAM checksum; nil
    /// while powered off.
    public func withRAM<Result>(_ body: (UnsafeRawBufferPointer) throws -> Result) rethrows -> Result? {
        guard let machine else { return nil }
        return try machine.bus.withRAM(body)
    }
}
#endif
