// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessPS1
import PresentationPlayer
import Testing

@MainActor
@Suite struct PlayerViewModelTests {
    @Test func aNewPlayerHasNothingLoaded() {
        let player = PlayerViewModel(console: PS1Console())
        #expect(player.state == .nothingLoaded)
        #expect(player.consoleName == "PlayStation")
        #expect(player.message == "Nothing to play yet.")
    }
}
