// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import Observation

/// The acknowledgements screen: every notice the app carries (ADR 0014).
///
/// Its entries come from the acknowledgements list, `src/istation/apps/Acknowledgements.json`; the
/// screen's full design is v1.0.0's.
@MainActor
@Observable
public final class AcknowledgementsViewModel {
    /// Each visibly different state of the screen.
    public enum State: Equatable, Sendable {
        /// The app carries no third-party code.
        case empty
        /// The app carries these notices.
        case listed
    }

    public private(set) var entries: [Acknowledgement]

    public init(entries: [Acknowledgement] = []) {
        self.entries = entries
    }

    public var state: State { entries.isEmpty ? .empty : .listed }

    /// What the screen says when there is nothing to list.
    public var emptyMessage: String { "iStation includes no third-party code yet." }
}
