// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

/// Numbers as the design writes them (html/main.html's `fmtInt`, en-US): digits grouped by thousands
/// with commas, whatever the system's locale, so a frame count, a file's size and an error's byte
/// count read the same in the player, the BIOS check and the design. Pure, so a view-model's words
/// and its tests use it alike.
public enum Figures {
    /// `value` with its digits grouped by thousands with commas: "524,288", "-12,345".
    public static func grouped(_ value: Int) -> String {
        let digits = Array(String(value.magnitude))
        var text = ""
        for (index, digit) in digits.enumerated() {
            if index > 0 && (digits.count - index) % 3 == 0 { text.append(",") }
            text.append(digit)
        }
        return value < 0 ? "-" + text : text
    }
}
