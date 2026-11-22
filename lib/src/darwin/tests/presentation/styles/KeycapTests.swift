// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import PresentationStyles
import SwiftUI
import Testing

/// A keycap drawn from a shortcut writes it as the design's shortcuts sheet does (html/main.html's
/// SHORTCUTS), so the sheet and the menus can't disagree.
@Suite("A shortcut's keycap writes it as the design does")
struct KeycapTests {
    @Test("Modifiers come in Apple's order, ⌃ ⌥ ⇧ ⌘, before the key in capitals", arguments: [
        (KeyboardShortcut("o", modifiers: .command), "⌘O"),
        (KeyboardShortcut("o", modifiers: [.command, .shift]), "⇧⌘O"),
        (KeyboardShortcut("f", modifiers: [.command, .control]), "⌃⌘F"),
        (KeyboardShortcut("a", modifiers: [.command, .option]), "⌥⌘A"),
        (KeyboardShortcut("k", modifiers: [.command, .shift, .option, .control]), "⌃⌥⇧⌘K"),
        (KeyboardShortcut(".", modifiers: .command), "⌘."),
        (KeyboardShortcut(",", modifiers: .command), "⌘,"),
        (KeyboardShortcut("/", modifiers: .command), "⌘/"),
        (KeyboardShortcut("1", modifiers: .command), "⌘1"),
    ])
    func modifiersThenTheKey(shortcut: KeyboardShortcut, glyphs: String) {
        #expect(Keycap.glyphs(for: shortcut) == glyphs)
    }

    @Test("Named keys are written as the design writes them", arguments: [
        (KeyboardShortcut.defaultAction, "↩"), (.cancelAction, "Esc"),
        (KeyboardShortcut(.space, modifiers: []), "Space"), (KeyboardShortcut(.tab, modifiers: []), "⇥"),
        (KeyboardShortcut(.delete, modifiers: .command), "⌘⌫"),
        (KeyboardShortcut(.upArrow, modifiers: []), "↑"), (KeyboardShortcut(.downArrow, modifiers: []), "↓"),
        (KeyboardShortcut(.leftArrow, modifiers: []), "←"), (KeyboardShortcut(.rightArrow, modifiers: []), "→"),
    ])
    func namedKeys(shortcut: KeyboardShortcut, glyphs: String) {
        #expect(Keycap.glyphs(for: shortcut) == glyphs)
    }
}
