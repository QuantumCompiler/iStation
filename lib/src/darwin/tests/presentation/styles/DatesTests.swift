// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import Foundation
import PresentationStyles
import Testing

/// Days are written as the design writes them, in English whatever the system's language: "Today" on
/// the day, "Nov 20" in the year, the year added for another.
@Suite struct DatesTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }

    @Test func aDayIsWrittenAsTheDesignWritesIt() {
        let today = date(2026, 11, 22)
        #expect(Dates.day(date(2026, 11, 22, 0), in: calendar, today: today) == "Today")
        #expect(Dates.day(date(2026, 11, 20), in: calendar, today: today) == "Nov 20")
        #expect(Dates.day(date(2026, 1, 2), in: calendar, today: today) == "Jan 2")
        #expect(Dates.day(date(2025, 11, 20), in: calendar, today: today) == "Nov 20, 2025")
    }

    @Test func aDayIsTheCalendarsDay() {
        var tokyo = calendar
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        // 22:00 UTC on Nov 21 is Nov 22 in Tokyo.
        #expect(Dates.day(date(2026, 11, 21, 22), in: tokyo, today: date(2026, 11, 22)) == "Today")
        #expect(Dates.day(date(2026, 11, 21, 22), in: calendar, today: date(2026, 11, 22)) == "Nov 21")
    }
}
