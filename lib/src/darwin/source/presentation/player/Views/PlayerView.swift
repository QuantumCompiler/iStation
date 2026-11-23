// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import PresentationStyles
import SwiftUI

/// The player's screen, as the design's Today player draws it: while a run plays, the "No picture
/// yet" panel counting its frames — the picture is 5g's — under the HUD, with the paused overlay
/// while paused; while nothing plays, what's happening. Reset and Stop ask in a `DetailsAlert`. On
/// macOS the app adds the window's title and toolbar with `playerChrome(_:idleTitle:)`, and keeps
/// full screen with `playerFullScreen(_:)` at its window's root; `playerWindow(_:idleTitle:)` is the
/// two together, for a window the player has to itself.
public struct PlayerView: View {
    private let viewModel: PlayerViewModel

    /// The screen for `viewModel`.
    public init(viewModel: PlayerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            Palette.screen
                .ignoresSafeArea()
            if viewModel.isPlaying {
                PlayingScreen(viewModel: viewModel)
            } else {
                IdleScreen(viewModel: viewModel)
            }
        }
        .foregroundStyle(Palette.onScreen)
        #if os(macOS)
        .frame(minWidth: Metrics.playerMinWidth, minHeight: Metrics.playerMinHeight)
        #endif
        .sheet(item: alert) { alert in
            DetailsAlert(alert.title, message: alert.message, details: alert.details, actions: [
                DetailsAlert.Action("Cancel", role: .cancel) { viewModel.cancel() },
                DetailsAlert.Action(alert.confirmTitle, role: .destructive) { viewModel.confirm() },
            ])
        }
    }

    /// The open question's alert; dismissing the sheet cancels it.
    private var alert: Binding<PlayerAlert?> {
        Binding(
            get: { viewModel.alert },
            set: { if $0 == nil { viewModel.cancel() } }
        )
    }
}

/// The screen while nothing plays: the console's name and what's happening.
private struct IdleScreen: View {
    let viewModel: PlayerViewModel

    var body: some View {
        VStack(spacing: Metrics.stackSpacing) {
            Image(systemName: viewModel.state == .stopped ? Symbols.stopped : Symbols.nothingToPlay)
                .font(Typography.screenSymbol)
                .accessibilityHidden(true)
            Text(viewModel.consoleName)
                .textStyle(.title2)
            Text(viewModel.message)
                .textStyle(.body)
        }
        .multilineTextAlignment(.center)
        .padding(Metrics.contentPadding)
    }
}

/// The screen while a run plays: the "No picture yet" panel or, while paused, the overlay in its place,
/// and the HUD over both. The design centers both the panel and the overlay's words; with no picture
/// for the scrim to dim, the panel would show through them, so the overlay stands in for it.
private struct PlayingScreen: View {
    let viewModel: PlayerViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            if viewModel.showsPausedOverlay {
                PausedOverlay(viewModel: viewModel)
            } else {
                NoPictureYet(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            PlayerHUD(viewModel: viewModel)
                .padding(.horizontal, Metrics.space4)
                .padding(.bottom, Metrics.space3)
        }
    }
}

/// Where the picture will stand: until the console draws one (6b, 5g), the frames it has run.
private struct NoPictureYet: View {
    let viewModel: PlayerViewModel

    var body: some View {
        VStack(spacing: Metrics.space3) {
            Text("No picture yet")
                .textStyle(.title2)
            Text(viewModel.message)
                .textStyle(.body)
                .foregroundStyle(Palette.onScreenSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(viewModel.frameText)
                .textStyle(.largeTitle, weight: .regular, monospaced: true)
            Text(viewModel.framesRunCaption)
                .textStyle(.caption)
                .foregroundStyle(Palette.onScreenSecondary)
        }
        .multilineTextAlignment(.center)
        .padding(Metrics.contentPadding)
        .accessibilityElement(children: .combine)
    }
}

/// The scrim over a paused game, with Resume.
private struct PausedOverlay: View {
    let viewModel: PlayerViewModel

    var body: some View {
        ZStack {
            Palette.overlay
                .ignoresSafeArea()
            VStack(spacing: Metrics.space3) {
                Text("Paused")
                    .textStyle(.title2)
                    .accessibilityAddTraits(.isHeader)
                Button("Resume") { viewModel.resume() }
                    .buttonStyle(SheetButtonStyle(.primary))
                    .help("Resume (⌘P)")
            }
        }
    }
}

#if DEBUG
extension View {
    /// The preview as the window's content shows it: the default window, below its toolbar.
    fileprivate func inWindow() -> some View {
        frame(width: Metrics.layout.windowWidth, height: Metrics.layout.windowHeight - Metrics.layout.toolbar)
    }
}

#Preview("Nothing loaded") {
    PlayerView(viewModel: PreviewPlayer.nothingLoaded())
        .inWindow()
}

#Preview("Running") {
    PlayerView(viewModel: PreviewPlayer.running())
        .inWindow()
}

#Preview("Running, first second") {
    PlayerView(viewModel: PreviewPlayer.justStarted())
        .inWindow()
}

#Preview("Running a PS-EXE") {
    PlayerView(viewModel: PreviewPlayer.running(PreviewPlayer.program))
        .inWindow()
}

#Preview("Paused") {
    PlayerView(viewModel: PreviewPlayer.paused())
        .inWindow()
}

#Preview("Stopped") {
    PlayerView(viewModel: PreviewPlayer.stopped())
        .inWindow()
}

#Preview("Reset confirm") {
    PlayerView(viewModel: PreviewPlayer.resetConfirm())
        .inWindow()
}

#Preview("Reset confirm, PS-EXE") {
    PlayerView(viewModel: PreviewPlayer.resetConfirm(PreviewPlayer.program))
        .inWindow()
}

#Preview("Stop confirm") {
    PlayerView(viewModel: PreviewPlayer.stopConfirm())
        .inWindow()
}

#Preview("Stop confirm, PS-EXE") {
    PlayerView(viewModel: PreviewPlayer.stopConfirm(PreviewPlayer.program))
        .inWindow()
}

#Preview("Full screen") {
    PlayerView(viewModel: PreviewPlayer.fullScreen())
        .frame(width: Metrics.layout.windowWidth, height: Metrics.layout.windowHeight)
}

#Preview("Minimum size") {
    PlayerView(viewModel: PreviewPlayer.running())
        .frame(width: Metrics.layout.windowMinWidth, height: Metrics.layout.windowMinHeight - Metrics.layout.toolbar)
}
#endif
