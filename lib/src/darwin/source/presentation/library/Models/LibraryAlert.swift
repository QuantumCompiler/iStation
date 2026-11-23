// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import PresentationStyles

/// What the library asks or tells in an alert, as `Mac-RemoveConfirm` and the missing file's dialog draw
/// it: the question or what happened, what it means, the exact call under Details, the tone its symbol
/// is drawn in, and its buttons, each answering with a `Choice` the view hands back to
/// `LibraryViewModel.answer(_:)`. The view draws it as a `DetailsAlert`.
public struct LibraryAlert: Sendable, Equatable, Identifiable {
    /// What a button answers.
    public enum Choice: Sendable, Equatable {
        /// Leaves things as they were: Cancel, and Escape.
        case cancel
        /// Takes the game out of the library: Remove, Remove from Library.
        case remove
        /// Opens the chooser to find the game's file: Locate….
        case locate
        /// Closes an alert that only tells: OK.
        case ok
    }

    /// How a button is drawn and which key presses it, as `DetailsAlert`'s roles are.
    public enum Role: Sendable, Equatable {
        /// Bordered, bound to Escape.
        case cancel
        /// The accent's default button, bound to Return.
        case primary
        /// Bordered: another way out.
        case secondary
    }

    /// One of the alert's buttons.
    public struct Button: Sendable, Equatable {
        /// Its title, in title case: "Remove".
        public var title: String
        /// How it's drawn.
        public var role: Role
        /// What it answers.
        public var choice: Choice

        /// A button titled `title`, drawn as `role`, answering `choice`.
        public init(_ title: String, role: Role, choice: Choice) {
            self.title = title
            self.role = role
            self.choice = choice
        }
    }

    /// The question, or what happened: "Remove “Glass Orchard (Europe)” from your library?".
    public var title: String
    /// What it means, in plain words.
    public var message: String
    /// The exact call behind it, shown under Details; nil for none.
    public var details: String?
    /// The tone its symbol is drawn in: info for a question that loses nothing, warning for a missing
    /// file, danger for a failure.
    public var tone: Tone
    /// Its buttons, in the order they're drawn: the default one last, as macOS lays them out.
    public var buttons: [Button]

    /// The alert's words: one is open at a time, so a sheet presenting it keeps them while it closes.
    public var id: String { title + message }

    /// An alert saying `title`, explained by `message`, with `details` under Details.
    public init(title: String, message: String, details: String?, tone: Tone, buttons: [Button]) {
        self.title = title
        self.message = message
        self.details = details
        self.tone = tone
        self.buttons = buttons
    }

    /// The button Return presses: the primary one. Escape answers `.cancel` whatever the buttons are, as
    /// the design's Escape closes any dialog.
    public var defaultButton: Button? {
        buttons.first { $0.role == .primary }
    }
}
