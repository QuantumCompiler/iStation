// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import Foundation

/// Days as the design writes them (html/main.html's "Nov 20", "Today"), in English whatever the system's
/// language, so the BIOS pane's check and the library's dates read the same in the apps and the design.
/// Pure: the calendar and today are given, so a view-model's words and its tests use it alike.
public enum Dates {
    /// `date`'s day in `calendar`: "Today" on `today`'s day, "Nov 20" in `today`'s year, and "Nov 20, 2025"
    /// in another year.
    public static func day(_ date: Date, in calendar: Calendar, today: Date) -> String {
        if calendar.isDate(date, inSameDayAs: today) { return "Today" }
        var style = Date.FormatStyle().month(.abbreviated).day()
        if calendar.component(.year, from: date) != calendar.component(.year, from: today) { style = style.year() }
        style.locale = Locale(identifier: "en_US")
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        return date.formatted(style)
    }
}
