// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

/// The words of the alert Reset or Stop asks first with, as `Mac-ResetConfirm` and `Mac-StopConfirm`
/// draw it: the question, what it means, the exact call under Details, and the button that goes ahead.
/// The view draws it as a `DetailsAlert`, with Cancel beside the button.
public struct PlayerAlert: Sendable, Equatable, Identifiable {
    /// The question: "Reset the console?".
    public var title: String
    /// What going ahead means, in plain words.
    public var message: String
    /// The exact call behind it, shown under Details.
    public var details: String
    /// The destructive button's title: "Reset" or "Stop".
    public var confirmTitle: String

    /// The question it asks: one alert is open at a time, so a sheet presenting it keeps its words
    /// while it closes.
    public var id: String { title }

    /// An alert asking `title`, explained by `message`, with `details` under Details and a
    /// `confirmTitle` button.
    public init(title: String, message: String, details: String, confirmTitle: String) {
        self.title = title
        self.message = message
        self.details = details
        self.confirmTitle = confirmTitle
    }
}
