// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

/// What an alert's or a job's Details say when a call fails: the exact call, and what it threw, as the
/// design writes it ("PS1Console.powerOn(bios:) threw PS1Error.biosSize(271384)"). Pure, so a view-model's
/// words and its tests use it alike.
public enum Details {
    /// `call` and what it threw: an error that is a case of an enum is named with its type, as Swift
    /// writes it; any other is written as it describes itself.
    public static func threw(_ call: String, _ error: any Error) -> String {
        let described = String(describing: error)
        guard Mirror(reflecting: error).displayStyle == .enum else { return "\(call) threw \(described)" }
        return "\(call) threw \(String(describing: type(of: error))).\(described)"
    }
}
