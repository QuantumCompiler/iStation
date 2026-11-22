// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import PresentationStyles
import SwiftUI
import Testing
#if os(macOS)
import AppKit
#endif

/// The tones chips, banners, job summaries and alerts are drawn in: each names two roles of the
/// palette that tokens.json holds to 4.5:1, and leads with the design's symbol.
@Suite("Every tone is a legible pair of the design's roles")
struct ToneTests {
    @Test("Each tone names roles the palette has")
    func eachToneNamesItsRoles() {
        let tokens = Set(Palette.roles.map(\.token))
        for tone in Tone.allCases {
            #expect(tokens.contains(tone.foregroundToken), "\(tone): no role \(tone.foregroundToken)")
            #expect(tokens.contains(tone.fillToken), "\(tone): no role \(tone.fillToken)")
        }
    }

    @Test("Each tone's pair is a contrast pair of tokens.json, and its Swift values pass it in every theme")
    func eachToneIsAContrastPair() throws {
        let pairs = try #require(try Design.tokens()["contrastPairs"] as? [[String: Any]], "tokens.json has no contrastPairs")
        let rows = Dictionary(uniqueKeysWithValues: Palette.roles.map { ($0.token, $0) })
        for tone in Tone.allCases {
            let pair = pairs.first { $0["fg"] as? String == tone.foregroundToken && $0["bg"] as? String == tone.fillToken }
            let minimum = try #require(pair?["min"] as? Double, "\(tone): \(tone.foregroundToken) on \(tone.fillToken) is not a contrastPairs entry")
            #expect(minimum >= 4.5, "\(tone) is text, held to 4.5:1")
            let foreground = try #require(rows[tone.foregroundToken])
            let fill = try #require(rows[tone.fillToken])
            for theme in ResolvedTheme.allCases {
                let ratio = Design.contrast(foreground.value(in: theme), fill.value(in: theme))
                #expect(ratio >= minimum, "\(tone) in \(theme): \(ratio)")
            }
        }
    }

    @Test("Banners and alerts lead with the design's symbol for their tone", arguments: [
        (Tone.ok, "checkCircle"), (.warning, "warn"), (.danger, "error"), (.info, "info"), (.neutral, "info"),
    ])
    func eachToneHasTheDesignsSymbol(tone: Tone, icon: String) {
        #expect(tone.symbol == Symbols.icons.first { $0.icon == icon }?.name)
    }

    #if os(macOS)
    @MainActor
    @Test("Each tone's colors resolve to its roles' values", .enabled(if: PaletteProviderTests.systemContrastIsStandard))
    func eachToneDrawsItsRoles() throws {
        let rows = Dictionary(uniqueKeysWithValues: Palette.roles.map { ($0.token, $0) })
        for (name, theme) in [(NSAppearance.Name.darkAqua, ResolvedTheme.dark), (.aqua, .light)] {
            let appearance = try #require(NSAppearance(named: name))
            for tone in Tone.allCases {
                let foreground = try #require(rows[tone.foregroundToken])
                let fill = try #require(rows[tone.fillToken])
                #expect(PaletteProviderTests.resolved(tone.foreground, in: appearance) == foreground.value(in: theme), "\(tone).foreground under \(name.rawValue)")
                #expect(PaletteProviderTests.resolved(tone.fill, in: appearance) == fill.value(in: theme), "\(tone).fill under \(name.rawValue)")
            }
        }
    }
    #endif
}
