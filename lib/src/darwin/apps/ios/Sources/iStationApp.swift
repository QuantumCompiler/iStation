// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessPS1
import PresentationAcknowledgements
import PresentationPlayer
import PresentationStyles
import SwiftUI

/// The iOS app: the player, with the acknowledgements one tap away.
/// The composition root: it builds the console and the view-models, and holds no logic.
@main
struct iStationApp: App {
    @State private var player = PlayerViewModel(console: PS1Console())
    @State private var acknowledgements = AcknowledgementsViewModel(entries: Acknowledgement.bundled(for: "iOS"))

    var body: some Scene {
        WindowGroup {
            RootView(player: player, acknowledgements: acknowledgements)
        }
    }
}

/// The one screen: the player, a toolbar button for the acknowledgements, and the routine's name.
struct RootView: View {
    let player: PlayerViewModel
    let acknowledgements: AcknowledgementsViewModel
    @State private var showsAcknowledgements = false

    var body: some View {
        NavigationStack {
            PlayerView(viewModel: player)
                .navigationTitle(Self.title)
                .toolbar {
                    Button { showsAcknowledgements = true } label: {
                        Label("Acknowledgements", systemImage: Symbols.acknowledgements)
                    }
                }
                .sheet(isPresented: $showsAcknowledgements) {
                    AcknowledgementsView(viewModel: acknowledgements)
                }
        }
    }

    /// The title says which routine built the app.
    static var title: String {
        #if PERSONAL_BUILD
        "iStation — Personal build"
        #else
        "iStation"
        #endif
    }
}
