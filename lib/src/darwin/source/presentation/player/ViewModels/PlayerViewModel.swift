// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessPS1
import Observation

/// The player: what the console is doing, as the screen shows it.
@MainActor
@Observable
public final class PlayerViewModel {
    /// Each visibly different state of the player.
    public enum State: Equatable, Sendable {
        /// No BIOS or game has been chosen, and the console has nothing to run.
        case nothingLoaded
    }

    public private(set) var state: State = .nothingLoaded

    private let console: PS1Console

    public init(console: PS1Console) {
        self.console = console
    }

    /// The console's name.
    public var consoleName: String { PS1Console.name }

    /// What the screen says in the current state.
    public var message: String {
        switch state {
        case .nothingLoaded: "Nothing to play yet."
        }
    }
}
