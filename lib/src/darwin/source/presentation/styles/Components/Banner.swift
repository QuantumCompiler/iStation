// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import SwiftUI

/// A note across a pane or a sheet in a tone's colors, as the design draws them: what this version
/// can't do yet, a BIOS that works, a job that stopped, a file of the wrong size. It leads with the
/// tone's symbol unless asked not to, and can end with one action.
public struct Banner: View {
    /// A button at the banner's end, drawn in the banner's own colors.
    public struct Action: Sendable {
        /// The button's title, in title case: "Locate…".
        public let title: String
        let perform: @MainActor () -> Void

        /// A button that runs `perform` when pressed.
        public init(_ title: String, perform: @escaping @MainActor () -> Void) {
            self.title = title
            self.perform = perform
        }
    }

    private let text: String
    private let tone: Tone
    private let showsSymbol: Bool
    private let action: Action?

    /// A banner saying `text` in `tone`'s colors, led by its symbol unless `showsSymbol` is false
    /// (as a job's summary and the inspector's notes are drawn), with an optional action.
    public init(_ text: String, tone: Tone, showsSymbol: Bool = true, action: Action? = nil) {
        self.text = text
        self.tone = tone
        self.showsSymbol = showsSymbol
        self.action = action
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metrics.space2) {
            if showsSymbol {
                Image(systemName: tone.symbol)
                    .accessibilityHidden(true)
            }
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let action {
                Button(action.title, action: action.perform)
                    .buttonStyle(.plain)
                    .textStyle(.body, weight: .semibold)
            }
        }
        .textStyle(.body)
        .foregroundStyle(tone.foreground)
        .padding(Metrics.space3)
        .background(tone.fill, in: RoundedRectangle(cornerRadius: Metrics.radiusControl))
        .accessibilityElement(children: .contain)
    }
}

#if DEBUG
/// A banner at the inspector's width on the window's background, where the design shows them.
private struct BannerPreview: View {
    let banner: Banner

    var body: some View {
        banner
            .frame(width: Metrics.layout.inspector)
            .padding(Metrics.space4)
            .background(Palette.window)
    }
}

#Preview("Info") {
    BannerPreview(banner: Banner("This version lists your disc images but can’t read or play them yet. Discs play from v0.2.0.", tone: .info))
}

#Preview("OK") {
    BannerPreview(banner: Banner("Your BIOS works: it reached its shell.", tone: .ok))
}

#Preview("Warning") {
    BannerPreview(banner: Banner("Stopped after 5 of 9.", tone: .warning))
}

#Preview("Danger") {
    BannerPreview(banner: Banner("A PS1 BIOS is exactly 524,288 bytes.", tone: .danger))
}

#Preview("Neutral") {
    BannerPreview(banner: Banner("This disc boots on a PS2. This version of iStation plays PS1 games; PS2 games come in a later version.", tone: .neutral, showsSymbol: false))
}

#Preview("With an action") {
    BannerPreview(banner: Banner("iStation can’t find this file. It may have been moved, renamed or deleted.", tone: .warning, action: Banner.Action("Locate…") {}))
}
#endif
