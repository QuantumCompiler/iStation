// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessPS1
import PresentationAcknowledgements
import PresentationPlayer
import PresentationStyles
import SwiftUI

/// The macOS app: the player window, and the acknowledgements window from the app menu.
/// The composition root: it builds the console and the view-models, and holds no logic.
@main
struct iStationApp: App {
    @State private var player = PlayerViewModel(console: PS1Console())
    @State private var acknowledgements = AcknowledgementsViewModel(entries: Acknowledgement.bundled(for: "macOS"))

    var body: some Scene {
        WindowGroup(Self.windowTitle) {
            PlayerView(viewModel: player)
                .frame(minWidth: Metrics.playerMinWidth, minHeight: Metrics.playerMinHeight)
        }
        .commands { AcknowledgementsCommand() }

        Window("Acknowledgements", id: AcknowledgementsCommand.windowID) {
            AcknowledgementsView(viewModel: acknowledgements)
        }
    }

    /// The window title says which routine built the app.
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
