// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

#if os(macOS)
import AppKit
import PresentationStyles
import SwiftUI
import Testing

/// Every Palette member, resolved the way AppKit draws it, under each appearance the providers know.
@MainActor
@Suite("Every Palette member resolves to its row under each appearance")
struct PaletteProviderTests {
    /// Every member, listed by hand: the list must name every row of `Palette.roles`, so a member can't
    /// be added, dropped or built from the wrong row without a failure here.
    static let members: [(String, Color)] = [
        ("window", Palette.window), ("sidebar", Palette.sidebar), ("content", Palette.content),
        ("raised", Palette.raised), ("toolbar", Palette.toolbar), ("control", Palette.control),
        ("controlHover", Palette.controlHover), ("controlPressed", Palette.controlPressed),
        ("hoverRow", Palette.hoverRow), ("selected", Palette.selected), ("screen", Palette.screen),
        ("picture", Palette.picture), ("overlay", Palette.overlay), ("separator", Palette.separator),
        ("controlBorder", Palette.controlBorder), ("focus", Palette.focus), ("text", Palette.text),
        ("secondaryText", Palette.secondaryText), ("disabledText", Palette.disabledText),
        ("onScreen", Palette.onScreen), ("onScreenSecondary", Palette.onScreenSecondary),
        ("onAccent", Palette.onAccent), ("onDestructive", Palette.onDestructive), ("accent", Palette.accent),
        ("accentHover", Palette.accentHover), ("accentPressed", Palette.accentPressed),
        ("accentText", Palette.accentText), ("ok", Palette.ok), ("okBackground", Palette.okBackground),
        ("warning", Palette.warning), ("warningBackground", Palette.warningBackground),
        ("danger", Palette.danger), ("dangerBackground", Palette.dangerBackground),
        ("dangerSolid", Palette.dangerSolid), ("info", Palette.info), ("infoBackground", Palette.infoBackground),
        ("verify", Palette.verify), ("verifyBackground", Palette.verifyBackground), ("shadow", Palette.shadow),
        ("trafficClose", Palette.trafficClose), ("trafficMinimize", Palette.trafficMinimize),
        ("trafficZoom", Palette.trafficZoom),
    ]

    /// The appearances AppKit draws in, and the theme each must give. AppKit hands out no
    /// high-contrast appearance by name (see below), so those two are stand-ins that report the name
    /// AppKit reports while Increase Contrast is on.
    nonisolated static let appearances: [(NSAppearance.Name, ResolvedTheme)] = [
        (.aqua, .light), (.darkAqua, .dark),
        (.accessibilityHighContrastAqua, .contrast), (.accessibilityHighContrastDarkAqua, .contrast),
    ]

    /// Increase Contrast turns every appearance high contrast, so the plain ones can only be checked
    /// while it is off.
    nonisolated static let systemContrastIsStandard = !NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast

    static func appearance(_ name: NSAppearance.Name) -> NSAppearance? {
        switch name {
        case .accessibilityHighContrastAqua: IncreasedContrastAppearance(base: .aqua, reporting: name)
        case .accessibilityHighContrastDarkAqua: IncreasedContrastAppearance(base: .darkAqua, reporting: name)
        default: NSAppearance(named: name)
        }
    }

    /// The color as AppKit draws it in an appearance, in sRGB.
    static func resolved(_ color: Color, in appearance: NSAppearance) -> RGBA? {
        var result: RGBA?
        appearance.performAsCurrentDrawingAppearance {
            guard let srgb = NSColor(color).usingColorSpace(.sRGB) else { return }
            func byte(_ component: CGFloat) -> UInt8 { UInt8((min(max(component, 0), 1) * 255).rounded()) }
            result = RGBA(red: byte(srgb.redComponent), green: byte(srgb.greenComponent), blue: byte(srgb.blueComponent), alpha: byte(srgb.alphaComponent))
        }
        return result
    }

    @Test("The member list names every row of Palette.roles once")
    func theListNamesEveryRow() {
        #expect(Self.members.map(\.0).sorted() == Palette.roles.map(\.member).sorted())
    }

    @Test("Every member resolves to its row's value", .enabled(if: systemContrastIsStandard), arguments: 0..<appearances.count)
    func everyMemberResolvesToItsRow(index: Int) throws {
        let (name, theme) = Self.appearances[index]
        let appearance = try #require(Self.appearance(name), "no \(name.rawValue) appearance")
        #expect(ResolvedTheme(appearance: appearance) == theme)
        let rows = Dictionary(uniqueKeysWithValues: Palette.roles.map { ($0.member, $0) })
        for (member, color) in Self.members {
            let row = try #require(rows[member], "Palette.\(member) has no row")
            #expect(Self.resolved(color, in: appearance) == row.value(in: theme), "Palette.\(member) under \(name.rawValue)")
        }
    }

    @Test("Dark and Light apply through the app's appearance; Match the system sets none", .enabled(if: systemContrastIsStandard))
    func explicitChoicesApplyThroughTheAppearance() throws {
        #expect(Theme.system.appearanceName(increaseContrast: false) == nil)
        for theme in [Theme.dark, .light] {
            let name = try #require(theme.appearanceName(increaseContrast: false))
            let appearance = try #require(NSAppearance(named: name))
            #expect(ResolvedTheme(appearance: appearance, theme: .system) == theme.resolved(systemIsDark: false, increaseContrast: false))
            #expect(Self.resolved(Palette.window, in: appearance) == Palette.roles[0].value(in: ResolvedTheme(appearance: appearance)))
        }
    }

    /// What is drawn, not the pure resolution: with each explicit choice applied, every appearance —
    /// the system's light and dark, and both high-contrast stand-ins for Increase Contrast — draws the
    /// choice's values. Increase Contrast has no say here, so this runs whatever the system's setting.
    /// The suite is main-actor and the test synchronous, so no other provider test draws while the
    /// choice is changed, and it is put back before the test returns.
    @Test("An explicit choice is what every appearance draws, Increase Contrast or not", arguments: [
        (Theme.dark, ResolvedTheme.dark), (.light, .light), (.highContrast, .contrast),
    ])
    func anExplicitChoiceIsWhatIsDrawn(theme: Theme, expected: ResolvedTheme) throws {
        let previous = Theme.applied
        Theme.applied = theme
        defer { Theme.applied = previous }
        let rows = Dictionary(uniqueKeysWithValues: Palette.roles.map { ($0.member, $0) })
        for (name, _) in Self.appearances {
            let appearance = try #require(Self.appearance(name), "no \(name.rawValue) appearance")
            #expect(ResolvedTheme(appearance: appearance) == expected, "\(theme) under \(name.rawValue)")
            for (member, color) in Self.members {
                let row = try #require(rows[member], "Palette.\(member) has no row")
                #expect(Self.resolved(color, in: appearance) == row.value(in: expected), "Palette.\(member), \(theme) under \(name.rawValue)")
            }
        }
    }

    @Test("Match the system draws high contrast under Increase Contrast, light or dark, and asks for Dark Aqua")
    func matchTheSystemDrawsHighContrastUnderIncreaseContrast() throws {
        #expect(Theme.system.appearanceName(increaseContrast: true) == .darkAqua, "the contrast theme is dark-based, so the system's own parts must draw dark")
        for name in [NSAppearance.Name.accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua] {
            let appearance = try #require(Self.appearance(name))
            #expect(ResolvedTheme(appearance: appearance, theme: .system) == .contrast, "Match the system under \(name.rawValue)")
        }
    }

    @Test("AppKit can't be put into high contrast by name, so High contrast sets Dark Aqua and draws through Theme.applied", .enabled(if: systemContrastIsStandard))
    func highContrastCannotBeNamed() throws {
        #expect(Theme.highContrast.appearanceName(increaseContrast: false) == .darkAqua)
        for name in [NSAppearance.Name.accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua] {
            // The header says nil; macOS hands back the plain appearance. Either way, no contrast values
            // under Match the system: only Theme.applied can make the palette draw them.
            guard let named = NSAppearance(named: name) else { continue }
            #expect(ResolvedTheme(appearance: named, theme: .system) != .contrast, "\(name.rawValue) now names a high-contrast appearance: Theme.highContrast can use it")
            #expect(ResolvedTheme(appearance: named, theme: .highContrast) == .contrast)
        }
    }
}

/// A stand-in for the appearance AppKit draws in while Increase Contrast is on: the base appearance,
/// reporting a high-contrast name to `bestMatch(from:)` as AppKit then does.
private final class IncreasedContrastAppearance: NSAppearance {
    private let reported: NSAppearance.Name

    init?(base: NSAppearance.Name, reporting reported: NSAppearance.Name) {
        self.reported = reported
        super.init(appearanceNamed: base, bundle: nil)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func bestMatch(from appearances: [NSAppearance.Name]) -> NSAppearance.Name? {
        appearances.contains(reported) ? reported : super.bestMatch(from: appearances)
    }
}
#endif
