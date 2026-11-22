// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import Foundation
import PresentationStyles
import Testing
#if os(macOS)
import AppKit
#endif

/// Every icon the design draws has an SF Symbol in `Symbols`, and every symbol exists.
@Suite("Symbols carries an SF Symbol for every icon the design draws")
struct SymbolsTests {
    static let allNames = Symbols.icons.map(\.name) + [Symbols.nothingToPlay, Symbols.acknowledgements]

    @Test("Every key of the design's ICON set has its entry, in its order")
    func everyDesignIconHasAnEntry() throws {
        #expect(Symbols.icons.map(\.icon) == (try Design.iconKeys()))
        #expect(Set(Symbols.icons.map(\.member)).count == Symbols.icons.count, "two entries name the same member")
    }

    #if os(macOS)
    @Test("Every symbol exists")
    func everySymbolExists() {
        for name in Self.allNames {
            #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil, "no SF Symbol \(name)")
        }
    }
    #endif

    /// The system's record of the year each symbol arrived, read-only: a private file, so any surprise
    /// in it — missing, or a format other than this one — skips the test rather than failing it.
    static let availabilityYears: [String: String]? = {
        let url = URL(fileURLWithPath: "/System/Library/CoreServices/CoreGlyphs.bundle/Contents/Resources/name_availability.plist")
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let years = (plist as? [String: Any])?["symbols"] as? [String: String],
              !years.isEmpty else { return nil }
        return years
    }()

    @Test("Every symbol is there on macOS 14 and iOS 17 (SF Symbols' 2023 release)",
          .enabled(if: availabilityYears != nil))
    func everySymbolIsThereOnTheOldestSystem() throws {
        let years = try #require(Self.availabilityYears)
        for name in Self.allNames {
            let year = try #require(years[name].flatMap(Double.init), "no availability for \(name)")
            #expect(year <= 2023, "\(name) arrived in \(year), after macOS 14 and iOS 17")
        }
    }
}
