// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessSession
import PresentationAcknowledgements
import PresentationPlayer
import PresentationStyles
import SwiftUI

/// The macOS app: one main window, which the player takes, with its toolbar and the Game menu; and
/// the acknowledgements window from the app menu.
/// The composition root: it builds the console session and the view-models, and holds no logic.
@main
struct iStationApp: App {
    /// The one console session, paced by the system's clock. The player drives it; what starts a run
    /// (5c's BIOS check, 5d's library) powers it on.
    private let session: ConsoleSession<ContinuousClock>
    @State private var player: PlayerViewModel
    @State private var acknowledgements = AcknowledgementsViewModel(entries: Acknowledgement.bundled(for: "macOS"))

    init() {
        let session = ConsoleSession()
        self.session = session
        _player = State(initialValue: PlayerViewModel(session: session))
    }

    var body: some Scene {
        // One window, one console at a time: a single `Window`, not a group, so neither File › New
        // nor the tab bar's + opens a second window over the same player.
        Window(Self.windowTitle, id: Self.mainWindowID) {
            PlayerView(viewModel: player)
                .playerWindow(player, idleTitle: Self.windowTitle)
                .frame(minWidth: Metrics.mac.windowMinWidth, minHeight: Metrics.mac.windowMinHeight - Metrics.mac.toolbar)
        }
        .defaultSize(width: Metrics.mac.windowWidth, height: Metrics.mac.windowHeight)
        .commands {
            CommandGroup(replacing: .newItem) {}
            AcknowledgementsCommand()
            PlayerCommands(viewModel: player)
        }

        Window("Acknowledgements", id: AcknowledgementsCommand.windowID) {
            AcknowledgementsView(viewModel: acknowledgements)
        }
    }

    /// The main window's identifier.
    static let mainWindowID = "main"

    /// The window title while nothing plays says which routine built the app; while a run plays the
    /// player names it there instead, as the design does.
    static var windowTitle: String {
        #if PERSONAL_BUILD
        "iStation — Personal build"
        #else
        "iStation"
        #endif
    }
}

/// "Acknowledgements…" in the app menu, after "About iStation".
struct AcknowledgementsCommand: Commands {
    static let windowID = "acknowledgements"

    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Acknowledgements…") { openWindow(id: Self.windowID) }
        }
    }
}
