// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2019 Pedro Cortés
// SPDX-FileCopyrightText: 2026 iStation contributors
// Ported from BluestormDNA/ProjectPSX/ProjectPSX/Core/ProjectPSX.cs — Copyright (c) 2019 Pedro Cortés

import BusinessR3000A

/// The PS1 console the apps play: powered off until it is given a BIOS. Its narrow interface to the
/// frontend — frames, audio, input, save states — is designed with the first picture (v0.1.0, ADR
/// 0015 §5); it imports nothing but the standard library and its CPU, as every core does.
public final class PS1Console {
    /// The console's name, as the player shows it.
    public static let name = "PlayStation"

    var machine: PS1Machine<NoTracer>?

    public init() {}

    /// False until the console has a BIOS to run.
    public var isPoweredOn: Bool { machine != nil }

    /// Powers on with the user's BIOS image, 512 KB, its CPU at the reset vector.
    public func powerOn(bios: [UInt8]) throws(PS1Error) {
        machine = try PS1Machine(bios: bios, tracer: NoTracer())
    }

    /// Runs one frame, to the next vertical blank; nothing while powered off.
    public func runFrame() {
        machine?.runFrame()
    }

    /// Vertical blanks since power-on.
    public var frame: Int { machine?.frame ?? 0 }
}
