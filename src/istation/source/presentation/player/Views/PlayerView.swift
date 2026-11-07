// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import PresentationStyles
import SwiftUI

/// The player's screen: the console's picture, or, while nothing runs, what to do next.
public struct PlayerView: View {
    private let viewModel: PlayerViewModel

    public init(viewModel: PlayerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            Palette.screen
            VStack(spacing: Metrics.stackSpacing) {
                Image(systemName: Symbols.nothingToPlay)
                    .font(Typography.screenSymbol)
                Text(viewModel.consoleName)
                    .font(Typography.title)
                Text(viewModel.message)
                    .font(Typography.body)
            }
            .foregroundStyle(Palette.onScreen)
            .padding(Metrics.contentPadding)
        }
        .aspectRatio(Metrics.screenAspectRatio, contentMode: .fit)
    }
}

#if DEBUG
#Preview("Nothing loaded") {
    PlayerView(viewModel: PreviewPlayer.nothingLoaded())
}
#endif
