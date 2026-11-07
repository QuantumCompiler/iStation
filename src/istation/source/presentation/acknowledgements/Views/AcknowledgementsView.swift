// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import PresentationStyles
import SwiftUI

/// The acknowledgements screen: each notice the app carries, or that there are none yet.
public struct AcknowledgementsView: View {
    private let viewModel: AcknowledgementsViewModel

    public init(viewModel: AcknowledgementsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        switch viewModel.state {
        case .empty:
            ContentUnavailableView {
                Label("Acknowledgements", systemImage: Symbols.acknowledgements)
            } description: {
                Text(viewModel.emptyMessage)
            }
        case .listed:
            List(viewModel.entries) { entry in
                VStack(alignment: .leading, spacing: Metrics.stackSpacing) {
                    Text(entry.name).font(Typography.title)
                    Text(entry.licence).font(Typography.body).foregroundStyle(Palette.secondaryText)
                    Text(entry.notice).font(Typography.body)
                }
            }
        }
    }
}

#if DEBUG
#Preview("Empty") {
    AcknowledgementsView(viewModel: AcknowledgementsViewModel())
}
#endif
