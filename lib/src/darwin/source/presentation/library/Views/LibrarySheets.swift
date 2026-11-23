// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

#if os(macOS)
import PresentationStyles
import SwiftUI

extension View {
    /// The library's choosers, sheets and alerts over this view: Add Games…'s chooser (several files),
    /// Add Folder…'s (one folder) and Locate…'s (one file); the rename sheet; the alert the library asks
    /// or tells in, drawn as a `DetailsAlert`; and the scan's and the opening's job sheets. Each sits on a
    /// view of its own, so no two presentations share one.
    func libraryPresentations(_ viewModel: LibraryViewModel) -> some View {
        modifier(LibraryPresenter(viewModel: viewModel))
    }
}

/// Presents the library's choosers, sheets and alerts.
private struct LibraryPresenter: ViewModifier {
    @Bindable var viewModel: LibraryViewModel
    /// Whether the alert's sheet is on screen: from its appearance until its dismissal has finished.
    @State private var alertIsOnScreen = false

    func body(content: Content) -> some View {
        content
            .background {
                Color.clear
                    .fileImporter(
                        isPresented: $viewModel.isChoosingGames, allowedContentTypes: GameFileTypes.games,
                        allowsMultipleSelection: true
                    ) { result in
                        // A choice the system couldn't hand over is as if none was made.
                        viewModel.add((try? result.get()) ?? [])
                    }
                    .fileDialogMessage(Text(LibraryText.addGamesMessage))
                    .fileDialogConfirmationLabel(Text(LibraryText.addGamesConfirmation))
            }
            .background {
                Color.clear
                    .fileImporter(isPresented: Bindable(viewModel.scan).isChoosingFolder, allowedContentTypes: [.folder]) { result in
                        if case .success(let folder) = result { viewModel.scan.scan(folder) }
                    }
                    .fileDialogMessage(Text(LibraryText.addFolderMessage))
                    .fileDialogConfirmationLabel(Text(LibraryText.addFolderConfirmation))
            }
            .background {
                Color.clear
                    .fileImporter(isPresented: locates, allowedContentTypes: GameFileTypes.games) { result in
                        if case .success(let url) = result { viewModel.located(url) }
                    }
                    .fileDialogMessage(Text(LibraryText.locateMessage))
                    .fileDialogConfirmationLabel(Text(LibraryText.locateConfirmation))
            }
            .background {
                Color.clear
                    .sheet(isPresented: renames) { RenameSheet(viewModel: viewModel) }
            }
            .background {
                Color.clear
                    .sheet(item: alert, onDismiss: { alertIsOnScreen = false }) { alert in
                        LibraryAlertView(alert: alert) { viewModel.answer($0) }
                            .onAppear { alertIsOnScreen = true }
                    }
            }
            .background {
                Color.clear
                    .sheet(isPresented: scans) { ScanSheet(scan: viewModel.scan) }
            }
            .background {
                Color.clear
                    .sheet(isPresented: opens) { OpeningSheet(opening: viewModel.opening) }
            }
    }

    /// Whether Locate…'s chooser shows: while the library asks for the file and no alert is on screen.
    /// The missing file's Locate… closes its alert and asks for the chooser in one step; presented while
    /// the alert's sheet is still going away, the chooser could be dropped, so it waits for the sheet's
    /// `onDismiss`, as the BIOS check's chooser waits for its sheet.
    private var locates: Binding<Bool> {
        Binding(
            get: { viewModel.isLocating && !alertIsOnScreen },
            set: { if !$0 { viewModel.isLocating = false } }
        )
    }

    /// Whether the rename sheet shows; closed without a button, it changes nothing.
    private var renames: Binding<Bool> {
        Binding(
            get: { viewModel.renaming != nil },
            set: { if !$0 { viewModel.cancelRename() } }
        )
    }

    /// The open alert; closed without a button, it is answered Cancel.
    private var alert: Binding<LibraryAlert?> {
        Binding(
            get: { viewModel.alert },
            set: { if $0 == nil, viewModel.alert != nil { viewModel.answer(.cancel) } }
        )
    }

    /// Whether the scan's sheet shows; closed without a button, a running scan stops and an ended one closes.
    private var scans: Binding<Bool> {
        Binding(
            get: { viewModel.scan.isShowingJob },
            set: { if !$0 { viewModel.scan.dismiss() } }
        )
    }

    /// Whether the opening's sheet shows; closed without a button, a running job is cancelled.
    private var opens: Binding<Bool> {
        Binding(
            get: { viewModel.opening.isShowingJob },
            set: { if !$0 { viewModel.opening.dismiss() } }
        )
    }
}

/// The rename sheet, as the design's `Mac-Rename` draws it: the name the library shows, in a field, and
/// Cancel and Rename; Rename is off while the field is blank, and Return presses it.
struct RenameSheet: View {
    @Bindable var viewModel: LibraryViewModel
    @FocusState private var isEditing: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.radiusControl)
        VStack(alignment: .leading, spacing: Metrics.space3) {
            Text(LibraryText.rename)
                .textStyle(.title3, weight: .bold)
                .accessibilityAddTraits(.isHeader)
            Text(LibraryText.renameNote)
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            TextField(LibraryText.rename, text: $viewModel.renameDraft)
                .textFieldStyle(.plain)
                .labelsHidden()
                .focused($isEditing)
                .onSubmit { viewModel.saveRename() }
                .padding(.horizontal, Metrics.space2)
                .frame(minHeight: Metrics.layout.control)
                .background(Palette.content, in: shape)
                .overlay(shape.strokeBorder(Palette.controlBorder))
                .accessibilityLabel(LibraryText.renameNote)
            HStack(spacing: Metrics.space2) {
                Spacer()
                Button(LibraryText.cancel) { viewModel.cancelRename() }
                    .buttonStyle(SheetButtonStyle(.bordered))
                    .keyboardShortcut(.cancelAction)
                Button(LibraryText.rename) { viewModel.saveRename() }
                    .buttonStyle(SheetButtonStyle(.primary))
                    .keyboardShortcut(.defaultAction)
                    .disabled(!viewModel.canSaveRename)
            }
        }
        .textStyle(.body)
        .foregroundStyle(Palette.text)
        .padding(Metrics.space5)
        .frame(width: Metrics.layout.sheetWidth)
        .background(Palette.raised)
        .presentationBackground(Palette.raised)
        .defaultFocus($isEditing, true)
    }
}

/// The library's alert as a `DetailsAlert`, as the design's `Mac-RemoveConfirm` and the missing file's
/// dialog draw them: each button hands its choice back, and Escape answers Cancel.
struct LibraryAlertView: View {
    let alert: LibraryAlert
    /// Answers the alert with a button's choice.
    let answer: @MainActor (LibraryAlert.Choice) -> Void

    var body: some View {
        DetailsAlert(alert.title, message: alert.message, details: alert.details, tone: alert.tone, actions: alert.buttons.map { button in
            DetailsAlert.Action(button.title, role: Self.role(of: button.role)) { answer(button.choice) }
        })
        .onExitCommand { answer(.cancel) }
    }

    private static func role(of role: LibraryAlert.Role) -> DetailsAlert.Action.Role {
        switch role {
        case .cancel: .cancel
        case .primary: .primary
        case .secondary: .secondary
        }
    }
}

/// Add Folder…'s job sheet, as the design's `Mac-ScanRunning`, `Mac-ScanStopped` and `Mac-ScanDone` draw
/// it at the Today level: its three steps, the bar while it reads, what became of each file, the tally,
/// and Stop, Done or Scan Again.
struct ScanSheet: View {
    let scan: ScanViewModel

    var body: some View {
        PresentedJobSheet(scan.job) { scan.perform($0) }
    }
}

/// A PS-EXE's opening job sheet, as the design's today flow runs it: open the file, power on with your
/// BIOS, start the program once the BIOS reaches its shell, and Cancel; or why it stopped, and Close.
struct OpeningSheet: View {
    let opening: OpeningViewModel

    var body: some View {
        PresentedJobSheet(opening.job) { opening.perform($0) }
    }
}

#if DEBUG
#Preview("Rename") {
    RenameSheet(viewModel: PreviewLibrary.rename())
}

#Preview("Remove confirm") {
    let library = PreviewLibrary.removeConfirm()
    if let alert = library.alert {
        LibraryAlertView(alert: alert) { library.answer($0) }
    }
}

#Preview("Locate or remove") {
    LocateOrRemovePreview(library: PreviewLibrary.locateOrRemove())
}

/// The missing file's alert, once the library has looked for the file and asked.
private struct LocateOrRemovePreview: View {
    let library: LibraryViewModel

    var body: some View {
        if let alert = library.alert {
            LibraryAlertView(alert: alert) { library.answer($0) }
        }
    }
}

#Preview("Scanning") {
    ScanSheet(scan: PreviewLibrary.scanRunning().scan)
}

#Preview("Scan stopped") {
    ScanSheet(scan: PreviewLibrary.scanStopped().scan)
}

#Preview("Scan done") {
    ScanSheet(scan: PreviewLibrary.scanDone().scan)
}

#Preview("Opening") {
    OpeningSheet(opening: PreviewLibrary.opening().opening)
}

#Preview("Opening refused") {
    OpeningSheet(opening: PreviewLibrary.openingRefused().opening)
}
#endif
#endif
