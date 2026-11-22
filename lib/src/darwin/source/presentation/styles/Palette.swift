// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// A color as the design writes it: red, green, blue and alpha, each 0 to 255, in sRGB.
public struct RGBA: Sendable, Hashable, CustomStringConvertible {
    /// The red channel, 0 to 255.
    public let red: UInt8
    /// The green channel, 0 to 255.
    public let green: UInt8
    /// The blue channel, 0 to 255.
    public let blue: UInt8
    /// The alpha channel, 0 (clear) to 255 (opaque).
    public let alpha: UInt8

    /// A color from its four channels.
    public init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8 = 255) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// An opaque color written as tokens.json writes it without alpha: `#1E1E21` is `.rgb(0x1E1E21)`.
    public static func rgb(_ hex: UInt32) -> RGBA {
        RGBA(red: UInt8((hex >> 16) & 0xFF), green: UInt8((hex >> 8) & 0xFF), blue: UInt8(hex & 0xFF))
    }

    /// A color written as tokens.json writes it with alpha: `#00000099` is `.rgba(0x00000099)`.
    public static func rgba(_ hex: UInt32) -> RGBA {
        RGBA(red: UInt8((hex >> 24) & 0xFF), green: UInt8((hex >> 16) & 0xFF), blue: UInt8((hex >> 8) & 0xFF), alpha: UInt8(hex & 0xFF))
    }

    /// The color as tokens.json writes it: `#RRGGBB`, or `#RRGGBBAA` when it is not opaque.
    public var description: String {
        let opaque = String(format: "#%02X%02X%02X", red, green, blue)
        return alpha == 255 ? opaque : opaque + String(format: "%02X", alpha)
    }
}

/// One color role of the design: its name in tokens.json, the `Palette` member that draws it, and its
/// value in each of the three themes.
public struct ColorRole: Sendable, Hashable {
    /// The role's name in tokens.json, e.g. `bg-window`.
    public let token: String
    /// The `Palette` member that draws it, e.g. `window`.
    public let member: String
    /// The role's value in the dark theme.
    public let dark: RGBA
    /// The role's value in the light theme.
    public let light: RGBA
    /// The role's value in the high-contrast theme.
    public let contrast: RGBA

    /// A role as tokens.json gives it.
    public init(_ token: String, _ member: String, dark: RGBA, light: RGBA, contrast: RGBA) {
        self.token = token
        self.member = member
        self.dark = dark
        self.light = light
        self.contrast = contrast
    }

    /// The role's value in one theme.
    public func value(in theme: ResolvedTheme) -> RGBA {
        switch theme {
        case .dark: dark
        case .light: light
        case .contrast: contrast
        }
    }

    /// The role as a color that picks its dark, light or high-contrast value each time it is drawn,
    /// from the theme setting (`Theme.applied`) and the appearance (macOS) or the traits (iOS) it is
    /// drawn in.
    public var color: Color {
        #if os(macOS)
        let role = self
        return Color(nsColor: NSColor(name: NSColor.Name(token)) { appearance in
            role.value(in: ResolvedTheme(appearance: appearance)).nsColor
        })
        #else
        let role = self
        return Color(uiColor: UIColor { traits in
            role.value(in: ResolvedTheme(traits: traits)).uiColor
        })
        #endif
    }
}

#if os(macOS)
extension RGBA {
    var nsColor: NSColor {
        NSColor(srgbRed: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: CGFloat(alpha) / 255)
    }
}
#else
extension RGBA {
    var uiColor: UIColor {
        UIColor(red: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: CGFloat(alpha) / 255)
    }
}
#endif

/// Every color the apps draw with, named for its role: the design's "graphite and amber" palette,
/// each role's dark, light and high-contrast values as `json/tokens.json` in the design gives them.
/// No asset catalog and no system color: each member is built from its row of `roles`.
public enum Palette {
    /// Every color role, in tokens.json's order. Each member below is built from its row, and the
    /// tokens test compares the rows with tokens.json.
    public static let roles: [ColorRole] = [
        ColorRole("bg-window", "window", dark: .rgb(0x1E1E21), light: .rgb(0xF3F3F5), contrast: .rgb(0x000000)),
        ColorRole("bg-sidebar", "sidebar", dark: .rgb(0x26262A), light: .rgb(0xE8E8EC), contrast: .rgb(0x0B0B0B)),
        ColorRole("bg-content", "content", dark: .rgb(0x19191B), light: .rgb(0xFFFFFF), contrast: .rgb(0x000000)),
        ColorRole("bg-raised", "raised", dark: .rgb(0x2B2B30), light: .rgb(0xFFFFFF), contrast: .rgb(0x121212)),
        ColorRole("bg-toolbar", "toolbar", dark: .rgb(0x232327), light: .rgb(0xEFEFF2), contrast: .rgb(0x0B0B0B)),
        ColorRole("bg-control", "control", dark: .rgb(0x3A3A40), light: .rgb(0xE6E6EA), contrast: .rgb(0x1F1F1F)),
        ColorRole("bg-control-hover", "controlHover", dark: .rgb(0x45454C), light: .rgb(0xDCDCE1), contrast: .rgb(0x2C2C2C)),
        ColorRole("bg-control-pressed", "controlPressed", dark: .rgb(0x505058), light: .rgb(0xD0D0D6), contrast: .rgb(0x3A3A3A)),
        ColorRole("bg-hover-row", "hoverRow", dark: .rgb(0x2A2A2F), light: .rgb(0xF0F0F4), contrast: .rgb(0x1A1A1A)),
        ColorRole("bg-selected", "selected", dark: .rgb(0x4A3B1F), light: .rgb(0xF7E2BC), contrast: .rgb(0x3D2D00)),
        ColorRole("bg-screen", "screen", dark: .rgb(0x000000), light: .rgb(0x000000), contrast: .rgb(0x000000)),
        ColorRole("bg-picture", "picture", dark: .rgb(0x1C1C1F), light: .rgb(0x1C1C1F), contrast: .rgb(0x141414)),
        ColorRole("bg-overlay", "overlay", dark: .rgba(0x00000099), light: .rgba(0x00000059), contrast: .rgba(0x000000CC)),
        ColorRole("line", "separator", dark: .rgb(0x38383E), light: .rgb(0xDADADF), contrast: .rgb(0x8F8F8F)),
        ColorRole("line-strong", "controlBorder", dark: .rgb(0x7A7A82), light: .rgb(0x8B8B93), contrast: .rgb(0xFFFFFF)),
        ColorRole("focus", "focus", dark: .rgb(0x8AB4FF), light: .rgb(0x2F6FDB), contrast: .rgb(0xFFD60A)),
        ColorRole("fg", "text", dark: .rgb(0xEDEDEF), light: .rgb(0x1C1C1E), contrast: .rgb(0xFFFFFF)),
        ColorRole("fg-muted", "secondaryText", dark: .rgb(0xAEAEB5), light: .rgb(0x5C5C64), contrast: .rgb(0xD9D9D9)),
        ColorRole("fg-faint", "disabledText", dark: .rgb(0x6E6E76), light: .rgb(0xA3A3AA), contrast: .rgb(0x8F8F8F)),
        ColorRole("fg-on-screen", "onScreen", dark: .rgb(0xF2F2F2), light: .rgb(0xF2F2F2), contrast: .rgb(0xFFFFFF)),
        ColorRole("fg-on-screen-muted", "onScreenSecondary", dark: .rgb(0xA6A6A6), light: .rgb(0xA6A6A6), contrast: .rgb(0xD0D0D0)),
        ColorRole("fg-on-accent", "onAccent", dark: .rgb(0x1B1305), light: .rgb(0xFFFFFF), contrast: .rgb(0x000000)),
        ColorRole("fg-on-danger", "onDestructive", dark: .rgb(0xFFFFFF), light: .rgb(0xFFFFFF), contrast: .rgb(0x000000)),
        ColorRole("accent", "accent", dark: .rgb(0xF2A93B), light: .rgb(0xA35F00), contrast: .rgb(0xFFC24D)),
        ColorRole("accent-hover", "accentHover", dark: .rgb(0xF6B85A), light: .rgb(0x935500), contrast: .rgb(0xFFD27A)),
        ColorRole("accent-pressed", "accentPressed", dark: .rgb(0xDC9426), light: .rgb(0x8C5100), contrast: .rgb(0xE6AA30)),
        ColorRole("accent-text", "accentText", dark: .rgb(0xF5B65A), light: .rgb(0x8A5000), contrast: .rgb(0xFFC24D)),
        ColorRole("ok", "ok", dark: .rgb(0x62D6AA), light: .rgb(0x0B7350), contrast: .rgb(0x7CF0C0)),
        ColorRole("ok-bg", "okBackground", dark: .rgb(0x16382D), light: .rgb(0xDCF2E9), contrast: .rgb(0x002B1D)),
        ColorRole("warn", "warning", dark: .rgb(0xF2C14E), light: .rgb(0x7D5800), contrast: .rgb(0xFFE066)),
        ColorRole("warn-bg", "warningBackground", dark: .rgb(0x3A2F12), light: .rgb(0xFAEFD0), contrast: .rgb(0x2E2500)),
        ColorRole("danger", "danger", dark: .rgb(0xFF8177), light: .rgb(0xB0261E), contrast: .rgb(0xFF9A92)),
        ColorRole("danger-bg", "dangerBackground", dark: .rgb(0x421F1C), light: .rgb(0xFBE4E2), contrast: .rgb(0x3A0A07)),
        ColorRole("danger-solid", "dangerSolid", dark: .rgb(0xC2362D), light: .rgb(0xB0261E), contrast: .rgb(0xFF9A92)),
        ColorRole("info", "info", dark: .rgb(0x8AB4FF), light: .rgb(0x1E5CB8), contrast: .rgb(0xA3CCFF)),
        ColorRole("info-bg", "infoBackground", dark: .rgb(0x1B2C45), light: .rgb(0xE1EBFA), contrast: .rgb(0x00213F)),
        ColorRole("verify", "verify", dark: .rgb(0xCDA8FF), light: .rgb(0x6A3DAE), contrast: .rgb(0xDEC6FF)),
        ColorRole("verify-bg", "verifyBackground", dark: .rgb(0x32244A), light: .rgb(0xEFE7FA), contrast: .rgb(0x2A0F4A)),
        ColorRole("shadow", "shadow", dark: .rgba(0x00000080), light: .rgba(0x00000033), contrast: .rgb(0x000000)),
        ColorRole("traffic-close", "trafficClose", dark: .rgb(0xFF5F57), light: .rgb(0xFF5F57), contrast: .rgb(0xFF5F57)),
        ColorRole("traffic-minimize", "trafficMinimize", dark: .rgb(0xFEBC2E), light: .rgb(0xFEBC2E), contrast: .rgb(0xFEBC2E)),
        ColorRole("traffic-zoom", "trafficZoom", dark: .rgb(0x28C840), light: .rgb(0x28C840), contrast: .rgb(0x28C840)),
    ]

    /// The row of `roles` a member draws; a member whose row is missing draws nothing, and the
    /// provider test fails on it.
    static func role(_ member: String) -> Color {
        roles.first { $0.member == member }?.color ?? .clear
    }

    // MARK: Backgrounds

    /// The window behind everything (`bg-window`).
    public static let window = role("window")
    /// The sidebar (`bg-sidebar`).
    public static let sidebar = role("sidebar")
    /// The content area: the library's list and grid, a pane's body (`bg-content`).
    public static let content = role("content")
    /// Sheets, popovers, cards and the inspector, raised above the content (`bg-raised`).
    public static let raised = role("raised")
    /// The window's toolbar (`bg-toolbar`).
    public static let toolbar = role("toolbar")
    /// A bordered button's or field's fill (`bg-control`).
    public static let control = role("control")
    /// A control under the pointer (`bg-control-hover`).
    public static let controlHover = role("controlHover")
    /// A control while it is pressed (`bg-control-pressed`).
    public static let controlPressed = role("controlPressed")
    /// A list row under the pointer (`bg-hover-row`).
    public static let hoverRow = role("hoverRow")
    /// A selected row or tile, tinted by the accent (`bg-selected`).
    public static let selected = role("selected")
    /// The player's screen when nothing is running (`bg-screen`).
    public static let screen = role("screen")
    /// The frame the console draws, as a placeholder in previews (`bg-picture`).
    public static let picture = role("picture")
    /// The scrim over a paused picture and behind the iPhone's on-screen buttons (`bg-overlay`); the
    /// dimming behind a sheet or an alert is the system's own.
    public static let overlay = role("overlay")

    // MARK: Lines

    /// A hairline between areas and rows (`line`).
    public static let separator = role("separator")
    /// A field's or bordered button's edge (`line-strong`).
    public static let controlBorder = role("controlBorder")
    /// The ring the design's pages draw around a focused control (`focus`). In the app the system
    /// draws the focus ring, in the user's own accent and keyboard settings, so no view draws this.
    public static let focus = role("focus")

    // MARK: Text

    /// Text that names (`fg`).
    public static let text = role("text")
    /// Text that explains rather than names (`fg-muted`).
    public static let secondaryText = role("secondaryText")
    /// Text of a disabled control (`fg-faint`).
    public static let disabledText = role("disabledText")
    /// Text drawn on the screen (`fg-on-screen`).
    public static let onScreen = role("onScreen")
    /// Secondary text drawn on the screen (`fg-on-screen-muted`).
    public static let onScreenSecondary = role("onScreenSecondary")
    /// Text on an accent fill, such as the default button (`fg-on-accent`).
    public static let onAccent = role("onAccent")
    /// Text on a destructive button's fill (`fg-on-danger`).
    public static let onDestructive = role("onDestructive")

    // MARK: Accent

    /// The app's accent, amber: the default button, the selection and tints (`accent`).
    public static let accent = role("accent")
    /// The accent under the pointer (`accent-hover`).
    public static let accentHover = role("accentHover")
    /// The accent while pressed (`accent-pressed`).
    public static let accentPressed = role("accentPressed")
    /// Links and accent-colored labels, readable on the backgrounds (`accent-text`).
    public static let accentText = role("accentText")

    // MARK: Status

    /// Something worked (`ok`).
    public static let ok = role("ok")
    /// The fill behind an `ok` chip or banner (`ok-bg`).
    public static let okBackground = role("okBackground")
    /// Something needs attention (`warn`).
    public static let warning = role("warning")
    /// The fill behind a warning chip or banner (`warn-bg`).
    public static let warningBackground = role("warningBackground")
    /// Something failed (`danger`).
    public static let danger = role("danger")
    /// The fill behind a danger chip or banner (`danger-bg`).
    public static let dangerBackground = role("dangerBackground")
    /// A destructive button's fill (`danger-solid`).
    public static let dangerSolid = role("dangerSolid")
    /// Something to know (`info`).
    public static let info = role("info")
    /// The fill behind an info chip or banner (`info-bg`).
    public static let infoBackground = role("infoBackground")
    /// Something not yet checked against the real console or backend: `verify`.
    public static let verify = role("verify")
    /// The fill behind a verify chip (`verify-bg`).
    public static let verifyBackground = role("verifyBackground")

    // MARK: Chrome

    /// A raised surface's shadow (`shadow`).
    public static let shadow = role("shadow")
    /// The close button the design draws on a window in previews (`traffic-close`).
    public static let trafficClose = role("trafficClose")
    /// The minimize button the design draws on a window in previews (`traffic-minimize`).
    public static let trafficMinimize = role("trafficMinimize")
    /// The zoom button the design draws on a window in previews (`traffic-zoom`).
    public static let trafficZoom = role("trafficZoom")
}
