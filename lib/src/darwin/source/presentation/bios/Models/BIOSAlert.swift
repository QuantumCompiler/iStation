// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

/// What the BIOS pane says when the kept BIOS can't be run or found: what happened, what to do, and the
/// exact call that failed under Details. The view draws it as a `DetailsAlert` with OK.
public struct BIOSAlert: Sendable, Equatable, Identifiable {
    /// What happened: "The BIOS couldn’t be read".
    public var title: String
    /// What it means and what to do, in plain words.
    public var message: String
    /// The exact call that failed and what it threw, shown under Details.
    public var details: String

    /// The alert's words: one is open at a time, so a sheet presenting it keeps them while it closes.
    public var id: String { title + message }

    /// An alert saying `title`, explained by `message`, with `details` under Details.
    public init(title: String, message: String, details: String) {
        self.title = title
        self.message = message
        self.details = details
    }
}
