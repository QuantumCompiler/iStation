// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessPS1

/// What a console session is doing at one moment, between frames: one value, copied out, so whoever
/// reads it — the player's view-model, on the main actor — holds nothing of the console itself.
public struct ConsoleSessionSnapshot: Sendable, Equatable {
    /// Where a session is in its life.
    public enum State: Sendable, Equatable {
        /// Not powered on yet: no BIOS has been given, and nothing runs.
        case poweredOff
        /// Frames run, 60 a second.
        case running
        /// Frames wait: the console holds its frame until it resumes.
        case paused
        /// The run loop has ended and the console is released; powering on again starts afresh.
        case stopped
    }

    /// Where the session is in its life.
    public var state: State
    /// Vertical blanks since power-on: 0 at power-on and after a reset, and the frame it stopped at once stopped.
    public var frame: Int
    /// Frames run over the last whole second of running: 0 until a second has run since power-on,
    /// reset or resume, and 0 while paused, stopped or powered off.
    public var framesPerSecond: Double
    /// True once the BIOS has reached its shell since power-on, and from then on (`PS1Console.reachedShell`).
    public var reachedShell: Bool
    /// True while the PS-EXE given at power-on waits for the BIOS to reach its shell — for good when
    /// `reachedShell` stays false (`PS1Console.bootIsPending`).
    public var bootIsPending: Bool

    #if PERSONAL_BUILD
    /// Instructions the CPU has retired since power-on, for a personal build's instructions per second.
    public var instructions: UInt64 = 0
    /// The console's registers, cycles, frame and TTY, for a personal build's Tools pane and debug
    /// drawer; nil before power-on. Kept, with the last values, once stopped.
    public var debugSnapshot: PS1DebugSnapshot? = nil
    #endif

    /// A snapshot of these values: the session takes its own, and fakes, previews and tests build theirs.
    public init(state: State = .poweredOff, frame: Int = 0, framesPerSecond: Double = 0, reachedShell: Bool = false,
                bootIsPending: Bool = false) {
        self.state = state
        self.frame = frame
        self.framesPerSecond = framesPerSecond
        self.reachedShell = reachedShell
        self.bootIsPending = bootIsPending
    }
}

#if PERSONAL_BUILD
extension ConsoleSessionSnapshot {
    /// A personal build's snapshot of these values, its instructions run and debug values included.
    public init(state: State = .poweredOff, frame: Int = 0, framesPerSecond: Double = 0, reachedShell: Bool = false,
                bootIsPending: Bool = false, instructions: UInt64, debugSnapshot: PS1DebugSnapshot?) {
        self.init(state: state, frame: frame, framesPerSecond: framesPerSecond, reachedShell: reachedShell, bootIsPending: bootIsPending)
        self.instructions = instructions
        self.debugSnapshot = debugSnapshot
    }
}
#endif
