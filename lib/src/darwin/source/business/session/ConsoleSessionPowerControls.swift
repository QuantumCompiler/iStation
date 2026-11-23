// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessPS1

/// What a starter drives — the BIOS check, Run the BIOS, from 5d the library's opening job: the
/// player's controls, and powering on and reading the snapshot as it stands. `ConsoleSession` is the
/// real one; the starters' previews and tests use a fake. The player itself needs only
/// `ConsoleSessionControls`: powering on is the starter's, not the player's.
public protocol ConsoleSessionPowerControls: ConsoleSessionControls {
    /// Powers on a fresh console with `bios`, the user's 512 KB image, gives it `exe` to boot before its
    /// first frame (nil for none), and runs it from frame 0. In any state: a running or paused session
    /// starts afresh, a stopped one runs again. An image of another size throws `PS1Error.biosSize` with
    /// its byte count and changes nothing: the session goes on as it was.
    func powerOn(bios: [UInt8], exe: PSEXE?) async throws(PS1Error)

    /// What the session is doing now: its state, frame, frames per second, and whether the BIOS has
    /// reached its shell.
    var snapshot: ConsoleSessionSnapshot { get async }
}
