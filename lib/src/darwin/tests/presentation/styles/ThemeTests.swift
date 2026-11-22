// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import Foundation
import PresentationStyles
import SwiftUI
import Testing

/// The theme setting: Match the system follows the system's appearance and turns high contrast with
/// Increase Contrast; an explicit choice wins over both. What the providers then draw under each
/// choice is PaletteProviderTests'.
@Suite("The theme setting resolves to one of the design's themes")
struct ThemeTests {
    @Test("Match the system is the default")
    func matchTheSystemIsTheDefault() {
        #expect(Theme.default == .system)
        #expect(Theme.system.name == "Match the system")
        #expect(Theme.allCases.map(\.name) == ["Match the system", "Dark", "Light", "High contrast"])
    }

    @Test("Match the system follows dark and light, and turns high contrast with Increase Contrast")
    func matchTheSystemFollowsTheSystem() {
        #expect(Theme.system.resolved(systemIsDark: true, increaseContrast: false) == .dark)
        #expect(Theme.system.resolved(systemIsDark: false, increaseContrast: false) == .light)
        #expect(Theme.system.resolved(systemIsDark: true, increaseContrast: true) == .contrast)
        #expect(Theme.system.resolved(systemIsDark: false, increaseContrast: true) == .contrast)
    }

    @Test("An explicit choice wins over the system's appearance and Increase Contrast", arguments: [
        (Theme.dark, ResolvedTheme.dark), (.light, .light), (.highContrast, .contrast),
    ])
    func anExplicitChoiceWins(theme: Theme, expected: ResolvedTheme) {
        for systemIsDark in [false, true] {
            for increaseContrast in [false, true] {
                #expect(theme.resolved(systemIsDark: systemIsDark, increaseContrast: increaseContrast) == expected)
            }
        }
    }

    @Test("Each choice asks for its color scheme; Match the system asks for none unless Increase Contrast is on")
    func eachChoiceAsksForItsColorScheme() {
        #expect(Theme.system.colorScheme(increaseContrast: false) == nil)
        for increaseContrast in [false, true] {
            #expect(Theme.dark.colorScheme(increaseContrast: increaseContrast) == .dark)
            #expect(Theme.light.colorScheme(increaseContrast: increaseContrast) == .light)
            #expect(Theme.highContrast.colorScheme(increaseContrast: increaseContrast) == .dark)
        }
    }

    @Test("Whenever a choice resolves to the dark-based high-contrast theme, it asks for dark", arguments: Theme.allCases)
    func highContrastAsksForDark(theme: Theme) {
        for systemIsDark in [false, true] {
            for increaseContrast in [false, true] where theme.resolved(systemIsDark: systemIsDark, increaseContrast: increaseContrast) == .contrast {
                #expect(theme.colorScheme(increaseContrast: increaseContrast) == .dark, "\(theme), system dark \(systemIsDark), Increase Contrast \(increaseContrast)")
                #if os(macOS)
                #expect(theme.appearanceName(increaseContrast: increaseContrast) == .darkAqua)
                #else
                #expect(theme.userInterfaceStyle(increaseContrast: increaseContrast) == .dark)
                #endif
            }
        }
        #expect(Theme.system.colorScheme(increaseContrast: true) == .dark, "Match the system under Increase Contrast must ask for dark")
    }

    @Test("Match the system overrides nothing while Increase Contrast is off; the explicit choices set their contrast")
    func matchTheSystemOverridesNothing() {
        #if os(macOS)
        #expect(Theme.system.appearanceName(increaseContrast: false) == nil)
        #else
        #expect(Theme.system.userInterfaceStyle(increaseContrast: false) == nil)
        #expect(Theme.system.accessibilityContrast == nil)
        #expect(Theme.dark.accessibilityContrast == .normal)
        #expect(Theme.light.accessibilityContrast == .normal)
        #expect(Theme.highContrast.accessibilityContrast == .high)
        #endif
    }

    @Test("The settings round-trip, and a value this version doesn't know reads as the default")
    func theSettingsRoundTrip() throws {
        for theme in Theme.allCases {
            #expect(try JSONDecoder().decode(Theme.self, from: JSONEncoder().encode(theme)) == theme)
        }
        for size in TextSize.allCases {
            #expect(try JSONDecoder().decode(TextSize.self, from: JSONEncoder().encode(size)) == size)
        }
        #expect(try JSONDecoder().decode(Theme.self, from: Data(#""sepia""#.utf8)) == .default)
        #expect(try JSONDecoder().decode(TextSize.self, from: Data(#""huge""#.utf8)) == .default)
        #expect(TextSize.default == .medium)
        #expect(TextSize.allCases.map(\.name) == ["Small", "Medium", "Large", "Extra large"])
    }
}
