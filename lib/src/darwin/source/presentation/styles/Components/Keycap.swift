// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import SwiftUI

/// A key or a shortcut as the design draws its `.kbd` in the shortcuts sheet and the controller
/// settings: its glyphs in a small key with a strong edge, "⌘O", "⇧⌘O", "↩".
public struct Keycap: View {
    private let glyphs: String

    /// A keycap showing `glyphs` as given.
    public init(_ glyphs: String) {
        self.glyphs = glyphs
    }

    /// The keycap for a shortcut the app binds, so the shortcuts sheet can't disagree with the menus.
    public init(_ shortcut: KeyboardShortcut) {
        self.init(Self.glyphs(for: shortcut))
    }

    public var body: some View {
        // The design's `.kbd` rounds 4 pt, off the radius scale; the control radius (6) is the nearest step.
        let shape = RoundedRectangle(cornerRadius: Metrics.radiusControl)
        Text(glyphs)
            .textStyle(.caption)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, Metrics.space2)
            // The design's keycap takes its height from its line height; half a space step matches it.
            .padding(.vertical, Metrics.space1 / 2)
            .foregroundStyle(Palette.secondaryText)
            .background(Palette.control, in: shape)
            .overlay(shape.strokeBorder(Palette.controlBorder))
    }

    /// A shortcut's glyphs as Apple's menus write them: the modifiers in the order ⌃ ⌥ ⇧ ⌘, then the
    /// key — a letter in capitals, a named key as the design writes it ("↩", "Esc", "Space", "←").
    nonisolated public static func glyphs(for shortcut: KeyboardShortcut) -> String {
        let modifiers: [(EventModifiers, String)] = [(.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
        let held = modifiers.filter { shortcut.modifiers.contains($0.0) }.map(\.1).joined()
        return held + glyph(for: shortcut.key)
    }

    /// One key's glyph: a named key as the design writes it, any other key its character in capitals.
    nonisolated static func glyph(for key: KeyEquivalent) -> String {
        let named: [(KeyEquivalent, String)] = [
            (.return, "↩"), (.escape, "Esc"), (.delete, "⌫"), (.deleteForward, "⌦"), (.tab, "⇥"),
            (.space, "Space"), (.upArrow, "↑"), (.downArrow, "↓"), (.leftArrow, "←"), (.rightArrow, "→"),
            (.home, "↖"), (.end, "↘"), (.pageUp, "⇞"), (.pageDown, "⇟"), (.clear, "⌧"),
        ]
        if let match = named.first(where: { $0.0.character == key.character }) { return match.1 }
        return String(key.character).uppercased()
    }
}

#if DEBUG
/// Keycaps in a row on the window's background, as the Foundations-Components board draws them.
private struct KeycapRow: View {
    let keycaps: [Keycap]

    var body: some View {
        HStack(spacing: Metrics.space2) {
            ForEach(keycaps.indices, id: \.self) { keycaps[$0] }
        }
        .padding(Metrics.space4)
        .background(Palette.window)
    }
}

#Preview("Keycap") {
    KeycapRow(keycaps: [Keycap("⌘O"), Keycap("⇧⌘O"), Keycap("↩")])
}

#Preview("From shortcuts") {
    KeycapRow(keycaps: [
        Keycap(KeyboardShortcut(".", modifiers: .command)), Keycap(KeyboardShortcut("f", modifiers: [.control, .command])),
        Keycap(.cancelAction), Keycap(KeyboardShortcut(.space, modifiers: [])),
    ])
}
#endif
