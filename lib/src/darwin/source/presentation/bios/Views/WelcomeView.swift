// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import PresentationStyles
import SwiftUI

/// Welcome, the first run's screen, as the design's `Mac-Welcome` draws it: what iStation does, what a
/// BIOS is and why it needs yours, the one sentence of guidance, Choose BIOS File… and
/// Acknowledgements, and that nothing is downloaded or sent. Choose BIOS File… opens the check's file
/// chooser, which `biosCheck(_:)` presents; the app applies that where it outlasts Welcome, so the check
/// that keeps a BIOS isn't closed when the pane takes Welcome's place.
public struct WelcomeView: View {
    private let check: BIOSCheckViewModel
    private let showAcknowledgements: () -> Void

    /// Welcome over `check`, its Acknowledgements button calling `showAcknowledgements`.
    public init(check: BIOSCheckViewModel, showAcknowledgements: @escaping () -> Void) {
        self.check = check
        self.showAcknowledgements = showAcknowledgements
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Metrics.space4) {
            Image(systemName: Symbols.disc)
                .font(Typography.screenSymbol)
                .foregroundStyle(Palette.accentText)
                .accessibilityHidden(true)
            Text(BIOSText.welcomeTitle)
                .textStyle(.largeTitle)
                .accessibilityAddTraits(.isHeader)
            Text(BIOSText.welcomeLead)
            Text(BIOSText.guidance)
            HStack(spacing: Metrics.space2) {
                Button(BIOSText.chooseBIOSFile) { check.chooseFile() }
                    .buttonStyle(SheetButtonStyle(.primary))
                    .help(BIOSText.chooseBIOSFileHelp)
                    .disabled(!check.canChooseFile)
                Button(BIOSText.acknowledgements, action: showAcknowledgements)
                    .buttonStyle(SheetButtonStyle(.bordered))
            }
            Text(BIOSText.neverSendsAnything)
                .textStyle(.caption)
                .foregroundStyle(Palette.secondaryText)
        }
        .textStyle(.body)
        .foregroundStyle(Palette.text)
        // A column of one width, the design's, whatever the window proposes: its words wrap at that
        // width, so the window's minimum height is the column's own, never the height of words wrapped
        // to nothing.
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: Metrics.layout.welcomeWidth, alignment: .leading)
        .padding(Metrics.space10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.content)
    }
}

#if DEBUG
#Preview("Welcome") {
    WelcomeView(check: PreviewBIOS.check()) {}
        .biosCheck(PreviewBIOS.check())
        .inPreviewWindow()
}

#Preview("Picker") {
    // The system's own file chooser opens over Welcome; no preview draws it.
    let check = PreviewBIOS.choosing()
    WelcomeView(check: check) {}
        .biosCheck(check)
        .inPreviewWindow()
}

#Preview("Minimum size") {
    WelcomeView(check: PreviewBIOS.check()) {}
        .frame(width: Metrics.layout.windowMinWidth, height: Metrics.layout.windowMinHeight - Metrics.layout.toolbar)
}
#endif
