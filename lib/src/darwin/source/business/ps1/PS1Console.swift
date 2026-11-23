// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2019 Pedro Cortés
// SPDX-FileCopyrightText: 2026 iStation contributors
// Ported from BluestormDNA/ProjectPSX/ProjectPSX/Core/ProjectPSX.cs — Copyright (c) 2019 Pedro Cortés

import BusinessR3000A

/// The PS1 console the apps play: powered off until it is given a BIOS. Its narrow interface to the
/// frontend — frames, audio, input, save states — is designed with the first picture (v0.1.0, ADR
/// 0015 §5); it imports nothing but the standard library and its CPU, as every core does. What it
/// says are plain values read between frames, never the machine itself.
public final class PS1Console {
    /// The console's name, as the player shows it.
    public static let name = "PS1"

    var machine: PS1Machine<NoTracer>?

    /// A console powered off, with no machine until `powerOn(bios:)` gives it a BIOS.
    public init() {}

    /// False until the console has a BIOS to run.
    public var isPoweredOn: Bool { machine != nil }

    /// Powers on with the user's BIOS image, 512 KB, its CPU at the reset vector: a fresh machine each
    /// time, so the shell is still to be reached and no EXE waits. An image of another size throws and
    /// changes nothing: the console stays as it was, powered off or running the machine it had.
    public func powerOn(bios: [UInt8]) throws(PS1Error) {
        machine = try PS1Machine(bios: bios, tracer: NoTracer())
    }

    /// Runs one frame, to the next vertical blank; nothing while powered off.
    public func runFrame() {
        machine?.runFrame()
    }

    /// Vertical blanks since power-on.
    public var frame: Int { machine?.frame ?? 0 }

    /// Starts a PS-EXE as the BIOS's shell would, in its place, once the BIOS reaches it. Given between
    /// frames, as a setting is, right after `powerOn(bios:)`: the shell is entered once per power-on, so
    /// an EXE given once `reachedShell` is true waits for good — to play it, power on again and give it
    /// to `boot(exe:)` again. Nothing while powered off: there is no BIOS to boot it, and powering on
    /// starts a fresh machine with nothing waiting.
    public func boot(exe: PSEXE) {
        machine?.boot(exe)
    }

    /// True while an EXE given to `boot(exe:)` waits for the BIOS to reach its shell — for good, when
    /// the BIOS never gets there (`reachedShell` false) or already had (true); false while powered off.
    public var bootIsPending: Bool { machine?.bootIsPending ?? false }

    /// True once the BIOS has reached its shell since power-on, and from then on; false while powered off.
    public var reachedShell: Bool { machine?.reachedShell ?? false }
}

#if PERSONAL_BUILD
extension PS1Console {
    /// The console's state between frames — the CPU's registers, its cycles, the frame and the TTY —
    /// for a personal build's Tools pane and debug drawer; nil while powered off.
    public var debugSnapshot: PS1DebugSnapshot? { machine?.debugSnapshot }
}
#endif
