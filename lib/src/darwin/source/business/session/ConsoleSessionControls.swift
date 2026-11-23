// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

/// What the player drives once a console session is running: pause, resume, reset, stop, and the
/// snapshots to show. Powering on is the starter's (the BIOS check, the library's opening job), not the
/// player's. `ConsoleSession` is the real one; the player's previews and tests use a fake.
public protocol ConsoleSessionControls: Sendable {
    /// Holds the frame: frames wait until `resume()`. Nothing unless running.
    func pause() async

    /// Runs frames again from the held frame, 60 a second. Nothing unless paused.
    func resume() async

    /// Powers on again with the same BIOS, gives the same PS-EXE to `boot(exe:)` again, and runs from
    /// frame 0 — a paused session too. Nothing unless running or paused.
    func reset() async

    /// Ends the run loop and releases the console; every snapshot stream finishes with the stopped
    /// snapshot. The BIOS and disc files are left as they are, and nothing is saved.
    func stop() async

    /// A stream of the session's snapshots, the current one first, then one each frame and each change
    /// of state; a slow reader gets the latest. It finishes at the next `stop()`, after the stopped
    /// snapshot, so a reader that goes on following the session takes a new stream after a stop.
    func snapshots() async -> AsyncStream<ConsoleSessionSnapshot>
}
