// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import os
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// The theme setting: which of the design's three themes the apps draw in. Settings holds it and
/// applies it — `applied`, then the scheme or appearance below; `styles` says what each choice means.
public enum Theme: String, Codable, Sendable, CaseIterable {
    /// Dark or light as the system is, and High contrast while Increase Contrast is on. The default.
    case system
    /// The dark theme, whatever the system does.
    case dark
    /// The light theme, whatever the system does.
    case light
    /// The high-contrast theme, which is dark-based, whatever the system does.
    case highContrast

    /// The setting a person starts with, and the one an unreadable stored value falls back to.
    public static let `default`: Theme = .system

    /// The choice the apps draw in now: every `Palette` provider resolves through it each time it is
    /// drawn, so an explicit choice wins over the system's appearance and Increase Contrast on both
    /// platforms.
    ///
    /// It is process-wide, as `NSApplication.appearance` is, because AppKit and UIKit hand a dynamic
    /// color only the appearance or traits it is drawn in, so the choice can reach it no other way.
    /// Settings sets it at launch and on each change, then applies the choice's scheme or appearance
    /// below and redraws its windows: Dark and High contrast ask for the same appearance, so a move
    /// between them gives AppKit and UIKit nothing to redraw for on their own. It is locked, since a
    /// color may be drawn off the main thread.
    public static var applied: Theme {
        get { appliedChoice.withLock { $0 } }
        set { appliedChoice.withLock { $0 = newValue } }
    }

    private static let appliedChoice = OSAllocatedUnfairLock(initialState: Theme.default)

    /// The choice's name in Settings.
    public var name: String {
        switch self {
        case .system: "Match the system"
        case .dark: "Dark"
        case .light: "Light"
        case .highContrast: "High contrast"
        }
    }

    /// The theme to draw in, given the system's appearance and its Increase Contrast setting. An
    /// explicit choice wins over both; the providers resolve through this under `applied`.
    public func resolved(systemIsDark: Bool, increaseContrast: Bool) -> ResolvedTheme {
        switch self {
        case .system: increaseContrast ? .contrast : systemIsDark ? .dark : .light
        case .dark: .dark
        case .light: .light
        case .highContrast: .contrast
        }
    }

    /// Whether the choice asks the system to draw dark (true) or light (false), nil to follow it.
    /// The high-contrast theme is dark-based, so whenever the choice resolves to it — High contrast,
    /// or Match the system while Increase Contrast is on — it asks for dark, and the system's own
    /// controls, menus, fields and text draw for the dark surfaces the palette gives them.
    private func asksForDark(increaseContrast: Bool) -> Bool? {
        switch self {
        case .system: increaseContrast ? true : nil
        case .dark, .highContrast: true
        case .light: false
        }
    }

    /// The color scheme to prefer for the choice (`View.preferredColorScheme`), nil to follow the
    /// system. `increaseContrast` is the system's setting
    /// (`NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast`,
    /// `UIAccessibility.isDarkerSystemColorsEnabled`): High contrast, and Match the system while it is
    /// on, ask for dark. It can change while the app runs, so the app asks again on
    /// `NSWorkspace.accessibilityDisplayOptionsDidChangeNotification` (macOS) and
    /// `UIAccessibility.darkerSystemColorsStatusDidChangeNotification` (iOS).
    public func colorScheme(increaseContrast: Bool) -> ColorScheme? {
        asksForDark(increaseContrast: increaseContrast).map { $0 ? ColorScheme.dark : ColorScheme.light }
    }

    /// Reads a stored choice, falling back to the default on a value this version doesn't know.
    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Theme(rawValue: raw) ?? .default
    }

    #if os(macOS)
    /// The appearance an app sets (`NSApplication.appearance`) for the choice, nil to follow the
    /// system; `increaseContrast`, and when to ask again, are as for `colorScheme(increaseContrast:)`.
    ///
    /// The palette takes its theme from `applied`, not from this appearance: the appearance is set so
    /// that AppKit redraws on a change and the system's own controls draw dark or light to match.
    /// AppKit can't be put into high contrast by an app — `NSAppearance(named:)` with
    /// `.accessibilityHighContrastDarkAqua` gives back the plain Dark Aqua appearance — so High
    /// contrast sets Dark Aqua: the palette still draws its high-contrast values, through `applied`,
    /// and the system's own controls draw high contrast only while Increase Contrast is on. The theme
    /// test pins this.
    public func appearanceName(increaseContrast: Bool) -> NSAppearance.Name? {
        asksForDark(increaseContrast: increaseContrast).map { $0 ? NSAppearance.Name.darkAqua : NSAppearance.Name.aqua }
    }
    #else
    /// The interface style to override on the app's windows (`traitOverrides.userInterfaceStyle`),
    /// nil to follow the system; `increaseContrast`, and when to ask again, are as for
    /// `colorScheme(increaseContrast:)`.
    public func userInterfaceStyle(increaseContrast: Bool) -> UIUserInterfaceStyle? {
        asksForDark(increaseContrast: increaseContrast).map { $0 ? UIUserInterfaceStyle.dark : UIUserInterfaceStyle.light }
    }

    /// The contrast to override on the app's windows (`traitOverrides.accessibilityContrast`), nil to
    /// follow the system's Increase Contrast. Dark and Light set normal and High contrast high, so the
    /// system's own controls match what the palette draws through `applied`.
    public var accessibilityContrast: UIAccessibilityContrast? {
        switch self {
        case .system: nil
        case .dark, .light: .normal
        case .highContrast: .high
        }
    }
    #endif
}

/// One of the design's three themes, as tokens.json names them: the values a color role draws.
public enum ResolvedTheme: String, Sendable, CaseIterable {
    /// tokens.json's `dark` values.
    case dark
    /// tokens.json's `light` values.
    case light
    /// tokens.json's `contrast` values: the high-contrast theme.
    case contrast

    #if os(macOS)
    /// The theme to draw in an appearance under a theme setting, `Theme.applied` unless one is given:
    /// an explicit choice wins, and Match the system gives `contrast` under either high-contrast
    /// appearance, `dark` under Dark Aqua and `light` under anything else. This is what each palette
    /// color reads when it is drawn.
    public init(appearance: NSAppearance, theme: Theme = .applied) {
        let match = appearance.bestMatch(from: [.aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua])
        let highContrast = match == .accessibilityHighContrastAqua || match == .accessibilityHighContrastDarkAqua
        let dark = match == .darkAqua || match == .accessibilityHighContrastDarkAqua
        self = theme.resolved(systemIsDark: dark, increaseContrast: highContrast)
    }
    #else
    /// The theme to draw in a trait collection under a theme setting, `Theme.applied` unless one is
    /// given: an explicit choice wins, and Match the system gives `contrast` under high contrast,
    /// `dark` under the dark style and `light` under anything else. This is what each palette color
    /// reads when it is drawn.
    public init(traits: UITraitCollection, theme: Theme = .applied) {
        self = theme.resolved(systemIsDark: traits.userInterfaceStyle == .dark, increaseContrast: traits.accessibilityContrast == .high)
    }
    #endif
}
