// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

#if os(macOS)
import AppKit
#endif
import PresentationStyles
import SwiftUI

/// The BIOS pane, as the design's `Mac-BiosPane` draws it: the kept BIOS's card — its file, size,
/// SHA-1 fingerprint in groups of four, folder, and when it was checked — then Run the BIOS, Choose
/// Another BIOS… and, on macOS, Show in Finder, and the notes on how the file is kept and what a BIOS
/// is. Choose Another BIOS… opens the check's chooser, presented by `biosCheck(_:)` where the app
/// applies it; a run or a file that can't be found says why in a `DetailsAlert`. On macOS it titles
/// the window "BIOS", the file's name under it.
public struct BIOSPaneView: View {
    private let viewModel: BIOSPaneViewModel
    private let check: BIOSCheckViewModel
    /// Shows a file in the Finder: the system's way in the app, nothing in the previews.
    private let reveal: @MainActor (URL) -> Void

    /// The pane for `viewModel`, choosing another BIOS through `check`.
    public init(viewModel: BIOSPaneViewModel, check: BIOSCheckViewModel) {
        self.init(viewModel: viewModel, check: check, reveal: Self.selectInFinder)
    }

    /// The pane, showing the kept file through `reveal`: the previews pass one that does nothing, so no
    /// preview reaches the Finder.
    init(viewModel: BIOSPaneViewModel, check: BIOSCheckViewModel, reveal: @escaping @MainActor (URL) -> Void) {
        self.viewModel = viewModel
        self.check = check
        self.reveal = reveal
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.space4) {
                BIOSCard(viewModel: viewModel)
                buttons
                Text(viewModel.keptByBookmarkText)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(viewModel.noteText)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .textStyle(.body)
            .foregroundStyle(Palette.text)
            .padding(Metrics.space6)
            .frame(maxWidth: Metrics.layout.paneMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Palette.content)
        .navigationTitle(viewModel.windowTitle)
        #if os(macOS)
        .navigationSubtitle(viewModel.windowSubtitle)
        #endif
        .sheet(item: alert) { alert in
            DetailsAlert(alert.title, message: alert.message, details: alert.details, tone: .danger, actions: [
                DetailsAlert.Action("OK", role: .primary) { viewModel.dismissAlert() },
            ])
        }
    }

    private var buttons: some View {
        HStack(spacing: Metrics.space2) {
            Button(BIOSText.runTheBIOS) { viewModel.runBIOS() }
                .buttonStyle(SheetButtonStyle(.primary))
                .disabled(!viewModel.canRun)
            Button(BIOSText.chooseAnotherBIOS) { check.chooseFile() }
                .buttonStyle(SheetButtonStyle(.bordered))
                .disabled(!check.canChooseFile)
            #if os(macOS)
            Button(BIOSText.showInFinder) { showInFinder() }
                .buttonStyle(SheetButtonStyle(.bordered))
            #endif
        }
    }

    /// The open alert; closing its sheet dismisses it.
    private var alert: Binding<BIOSAlert?> {
        Binding(
            get: { viewModel.alert },
            set: { if $0 == nil { viewModel.dismissAlert() } }
        )
    }

    /// Shows the kept file, once the view-model has found it.
    private func showInFinder() {
        guard let url = viewModel.fileToShowInFinder() else { return }
        reveal(url)
    }

    /// Selects `url` in a Finder window, inside its security-scoped access; nothing off macOS.
    @MainActor
    private static func selectInFinder(_ url: URL) {
        #if os(macOS)
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        NSWorkspace.shared.activateFileViewerSelecting([url])
        #endif
    }
}

/// The kept BIOS's card: the chip, then the file's name, size, fingerprint, folder and check.
private struct BIOSCard: View {
    let viewModel: BIOSPaneViewModel

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.radiusCard)
        HStack(alignment: .top, spacing: Metrics.space4) {
            Image(systemName: Symbols.bios)
                .textStyle(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(Palette.accentText)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Metrics.space1) {
                Text(viewModel.fileName)
                    .textStyle(.body, weight: .semibold, monospaced: true)
                    .textSelection(.enabled)
                Text(viewModel.sizeText)
                    .foregroundStyle(Palette.secondaryText)
                Text(viewModel.fingerprintText)
                    .textStyle(.caption, monospaced: true)
                    .foregroundStyle(Palette.secondaryText)
                    .textSelection(.enabled)
                Text(viewModel.folderText)
                    .textStyle(.caption)
                    .foregroundStyle(Palette.secondaryText)
                HStack(spacing: Metrics.space1) {
                    Image(systemName: Symbols.done)
                        .accessibilityHidden(true)
                    Text(viewModel.checkedText)
                }
                .foregroundStyle(Palette.ok)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Metrics.space4)
        .background(Palette.raised, in: shape)
        .overlay(shape.strokeBorder(Palette.separator))
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("BIOS pane") {
    BIOSPaneView(viewModel: PreviewBIOS.pane(), check: PreviewBIOS.check(), reveal: { _ in })
        .inPreviewWindow()
}

#Preview("BIOS pane, checked today") {
    BIOSPaneView(viewModel: PreviewBIOS.pane(checkedToday: true), check: PreviewBIOS.check(), reveal: { _ in })
        .inPreviewWindow()
}

#Preview("BIOS pane, can’t run") {
    BIOSPaneView(viewModel: PreviewBIOS.paneThatCantRun(), check: PreviewBIOS.check(), reveal: { _ in })
        .inPreviewWindow()
}

#Preview("BIOS pane, minimum size") {
    BIOSPaneView(viewModel: PreviewBIOS.pane(), check: PreviewBIOS.check(), reveal: { _ in })
        .frame(width: Metrics.layout.windowMinWidth, height: Metrics.layout.windowMinHeight - Metrics.layout.toolbar)
}
#endif
