// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

#if os(macOS)
import PresentationStyles
import SwiftUI

/// Game info, the inspector, as the design's `Mac-TodayLibrary`, `Mac-LibraryInspector` and
/// `Mac-LibraryMissing` draw it at the Today level: the selected game's initials in place of artwork, its
/// name with Rename, a missing file's note, what the library knows of it, then Play — on only for a PS-EXE
/// whose file is there, with why not under it — or Locate… for a missing file, Show in Finder and Remove
/// from Library….
struct GameInfoView: View {
    let viewModel: LibraryViewModel
    /// Shows a file in the Finder.
    let reveal: @MainActor (URL) -> Void

    var body: some View {
        ScrollView {
            if let info = viewModel.info {
                content(info)
            }
        }
        .background(Palette.window)
    }

    private func content(_ info: GameInfo) -> some View {
        VStack(alignment: .leading, spacing: Metrics.space3) {
            art(info)
            HStack(alignment: .firstTextBaseline, spacing: Metrics.space2) {
                Text(info.name)
                    .textStyle(.title3, weight: .bold)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                Button { viewModel.rename(info.id) } label: {
                    Image(systemName: Symbols.rename)
                        .foregroundStyle(Palette.secondaryText)
                }
                .buttonStyle(.plain)
                .help(LibraryText.rename)
                .accessibilityLabel(LibraryText.rename)
            }
            if let banner = info.banner {
                Banner(banner, tone: info.bannerTone ?? .warning, showsSymbol: false)
            }
            facts(info)
            buttons(info)
                .padding(.top, Metrics.space1)
        }
        .textStyle(.body)
        .foregroundStyle(Palette.text)
        .padding(Metrics.space4)
    }

    /// The box standing in for artwork: the game's initials.
    private func art(_ info: GameInfo) -> some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.radiusCard)
        return shape.fill(Palette.raised)
            .overlay(shape.strokeBorder(Palette.separator))
            .overlay {
                Text(info.initials)
                    .textStyle(.largeTitle)
                    .foregroundStyle(Palette.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .frame(height: Metrics.layout.infoArtHeight)
            .accessibilityHidden(true)
    }

    /// What the library knows, a name and its value a line, the value wrapping beside its name.
    private func facts(_ info: GameInfo) -> some View {
        Grid(alignment: .topLeading, horizontalSpacing: Metrics.space3, verticalSpacing: Metrics.space2) {
            ForEach(info.facts, id: \.name) { fact in
                GridRow {
                    Text(fact.name)
                        .foregroundStyle(Palette.secondaryText)
                        .frame(width: Metrics.layout.factNameWidth, alignment: .leading)
                    Text(fact.value)
                        .textStyle(.body, monospaced: fact.style == .monospaced)
                        .foregroundStyle(fact.style == .muted ? Palette.secondaryText : Palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    /// Play or Locate…, why Play is off, Show in Finder and Remove from Library….
    private func buttons(_ info: GameInfo) -> some View {
        VStack(alignment: .leading, spacing: Metrics.space2) {
            Button(info.actionTitle) {
                switch info.action {
                case .play: viewModel.play(info.id)
                case .locate: viewModel.locate(info.id)
                }
            }
            .buttonStyle(SheetButtonStyle(.primary, fillsWidth: true))
            .help(info.actionHelp)
            .disabled(!info.isActionEnabled)
            if let reason = info.reason {
                Text(reason)
                    .textStyle(.caption)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(LibraryText.showInFinder) {
                if let url = viewModel.fileToShowInFinder() { reveal(url) }
            }
            .buttonStyle(SheetButtonStyle(.bordered, fillsWidth: true))
            .disabled(!info.canShowInFinder)
            Button(LibraryText.removeFromLibrary) { viewModel.askToRemove(info.id) }
                .buttonStyle(SheetButtonStyle(.bordered, fillsWidth: true))
                .help(LibraryText.removeFromLibraryHelp)
        }
    }
}

#if DEBUG
#Preview("Game info, a disc") {
    GameInfoView(viewModel: PreviewLibrary.today(), reveal: { _ in })
        .frame(width: Metrics.layout.inspector, height: Metrics.layout.windowHeight - Metrics.layout.toolbar)
}

#Preview("Game info, a playlist") {
    GameInfoView(viewModel: PreviewLibrary.info(), reveal: { _ in })
        .frame(width: Metrics.layout.inspector, height: Metrics.layout.windowHeight - Metrics.layout.toolbar)
}

#Preview("Game info, a PS-EXE") {
    GameInfoView(viewModel: PreviewLibrary.infoForAProgram(), reveal: { _ in })
        .frame(width: Metrics.layout.inspector, height: Metrics.layout.windowHeight - Metrics.layout.toolbar)
}

#Preview("Game info, file missing") {
    GameInfoView(viewModel: PreviewLibrary.missing(), reveal: { _ in })
        .frame(width: Metrics.layout.inspector, height: Metrics.layout.windowHeight - Metrics.layout.toolbar)
}
#endif
#endif
