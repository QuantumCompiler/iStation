// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import PresentationStyles
import SwiftUI

/// The bar along the bottom of the player, as the design draws it: the status chip, what plays, the
/// frame counter and the frames per second; in full screen, where the toolbar is hidden, also Pause or
/// Resume and Exit full screen.
struct PlayerHUD: View {
    let viewModel: PlayerViewModel

    var body: some View {
        HStack(spacing: Metrics.space3) {
            Chip(viewModel.statusText, tone: viewModel.state == .paused ? .warning : .ok)
            Text(viewModel.name)
                .textStyle(.body, weight: .semibold)
                .lineLimit(1)
                .truncationMode(.tail)
            Text(viewModel.hudFrameText)
                .textStyle(.caption, monospaced: true)
                .foregroundStyle(Palette.secondaryText)
            if let framesPerSecond = viewModel.framesPerSecondText {
                Text(framesPerSecond)
                    .textStyle(.caption, monospaced: true)
                    .foregroundStyle(Palette.secondaryText)
            }
            Spacer(minLength: 0)
            if viewModel.isFullScreen {
                HUDButton(viewModel.pauseTitle, symbol: viewModel.state == .paused ? Symbols.play : Symbols.pause, key: "⌘P") {
                    viewModel.togglePause()
                }
                .disabled(!viewModel.canTogglePause)
                HUDButton("Exit full screen", symbol: Symbols.fullScreen, key: "Esc") {
                    viewModel.exitFullScreen()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
        .padding(.vertical, Metrics.space2)
        .padding(.horizontal, Metrics.space3)
        .foregroundStyle(Palette.text)
        .background {
            // The shadow falls from the bar's shape alone, not from each label and chip on it.
            RoundedRectangle(cornerRadius: Metrics.radiusCard)
                .fill(Palette.raised)
                .shadow(color: Palette.shadow, radius: Metrics.space2, y: Metrics.space1)
        }
    }
}

/// One of the HUD's icon buttons, as the design's toolbar buttons (`.tb`) look: the muted symbol on
/// nothing, the control's fill under the pointer, and the faint symbol while disabled.
private struct HUDButton: View {
    let title: String
    let symbol: String
    let key: String
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    init(_ title: String, symbol: String, key: String, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.key = key
        self.action = action
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.radiusControl)
        Button(action: action) {
            Image(systemName: symbol)
                .imageScale(.large)
                .frame(minWidth: Metrics.layout.control + Metrics.space1, minHeight: Metrics.layout.control)
                .foregroundStyle(isEnabled ? (isHovered ? Palette.text : Palette.secondaryText) : Palette.disabledText)
                .background {
                    if isHovered && isEnabled { shape.fill(Palette.control) }
                }
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("\(title) (\(key))")
        .accessibilityLabel(title)
    }
}

#if DEBUG
/// The HUD on the player's screen, at the default window's width.
private struct HUDOnScreen: View {
    let viewModel: PlayerViewModel

    var body: some View {
        PlayerHUD(viewModel: viewModel)
            .padding(Metrics.space4)
            .frame(width: Metrics.layout.windowWidth)
            .background(Palette.screen)
    }
}

#Preview("HUD running") {
    HUDOnScreen(viewModel: PreviewPlayer.running())
}

#Preview("HUD running, first second") {
    HUDOnScreen(viewModel: PreviewPlayer.justStarted())
}

#Preview("HUD paused") {
    HUDOnScreen(viewModel: PreviewPlayer.paused())
}

#Preview("HUD full screen") {
    HUDOnScreen(viewModel: PreviewPlayer.fullScreen())
}
#endif
