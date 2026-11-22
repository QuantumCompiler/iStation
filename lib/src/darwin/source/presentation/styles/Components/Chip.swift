// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import SwiftUI

/// A small capsule label in a tone's colors, as the design draws its `.chip`: a game's state
/// (Running, Paused, File missing), its console (PS1), a licence, the Personal build mark.
public struct Chip: View {
    private let text: String
    private let tone: Tone

    /// A chip saying `text`, in `tone`'s colors.
    public init(_ text: String, tone: Tone = .neutral) {
        self.text = text
        self.tone = tone
    }

    public var body: some View {
        Text(text)
            .textStyle(.caption, weight: .semibold)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, Metrics.space2)
            // The design's chip takes its height from its line height; half a space step matches it.
            .padding(.vertical, Metrics.space1 / 2)
            .foregroundStyle(tone.foreground)
            .background(tone.fill, in: Capsule())
    }
}

extension Tone {
    /// The tone's text and symbol color: its `foregroundToken`'s role in `Palette`.
    public var foreground: Color {
        ToneColors.foreground[self, default: Palette.text]
    }

    /// The tone's fill: its `fillToken`'s role in `Palette`.
    public var fill: Color {
        ToneColors.fill[self, default: Palette.control]
    }
}

/// Each tone's two colors, built once from their rows of `Palette.roles`, so a tone draws exactly the
/// roles it names; the tone test checks that every name has its row.
private enum ToneColors {
    static let foreground = colors { $0.foregroundToken }
    static let fill = colors { $0.fillToken }

    static func colors(_ token: (Tone) -> String) -> [Tone: Color] {
        var colors: [Tone: Color] = [:]
        for tone in Tone.allCases {
            colors[tone] = Palette.roles.first { $0.token == token(tone) }?.color
        }
        return colors
    }
}

#if DEBUG
/// A row of chips on the window's background, as the Foundations-Components board lays them out.
private struct ChipRow: View {
    let chips: [Chip]

    var body: some View {
        HStack(spacing: Metrics.space2) {
            ForEach(chips.indices, id: \.self) { chips[$0] }
        }
        .padding(Metrics.space4)
        .background(Palette.window)
    }
}

#Preview("Neutral") {
    ChipRow(chips: [Chip("PS1"), Chip("MIT")])
}

#Preview("Muted") {
    ChipRow(chips: [Chip("Plays later", tone: .muted)])
}

#Preview("OK") {
    ChipRow(chips: [Chip("Running", tone: .ok), Chip("ready", tone: .ok)])
}

#Preview("Warning") {
    ChipRow(chips: [Chip("Paused", tone: .warning), Chip("File missing", tone: .warning), Chip("Older format", tone: .warning), Chip("gap", tone: .warning)])
}

#Preview("Danger") {
    ChipRow(chips: [Chip("Failed", tone: .danger)])
}

#Preview("Info") {
    ChipRow(chips: [Chip("app", tone: .info)])
}

#Preview("Verify") {
    ChipRow(chips: [Chip("Personal build", tone: .verify), Chip("verify", tone: .verify)])
}
#endif
