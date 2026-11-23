// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import PresentationStyles
import SwiftUI
import UniformTypeIdentifiers

extension View {
    /// The BIOS check over this view: the system's file chooser while `check` asks for a file — one file
    /// of any type, since a BIOS has no type of its own — and the check's job sheet while it has one to
    /// show. The app applies it to its window's content, around whichever place shows, so a check that
    /// keeps a BIOS outlasts Welcome giving way to the BIOS pane.
    public func biosCheck(_ check: BIOSCheckViewModel) -> some View {
        modifier(BIOSCheckPresenter(check: check))
    }
}

/// Presents the check's chooser and its sheet.
private struct BIOSCheckPresenter: ViewModifier {
    let check: BIOSCheckViewModel
    /// Whether the job sheet is on screen: from its appearance until its dismissal has finished.
    @State private var sheetIsOnScreen = false

    func body(content: Content) -> some View {
        content
            .fileImporter(isPresented: choosesFile, allowedContentTypes: [.data]) { result in
                // A file the system couldn't hand over is as if none was chosen: Welcome or the pane
                // stays, and the person can choose again.
                if case .success(let url) = result { check.check(url) }
            }
            // The chooser says how the file is kept and chooses it with Choose, as `Mac-BiosPicker`
            // draws it; the panel itself is the system's.
            .fileDialogMessage(Text(BIOSText.chooserMessage))
            .fileDialogConfirmationLabel(Text(BIOSText.chooserConfirmation))
            .sheet(isPresented: showsJob, onDismiss: { sheetIsOnScreen = false }) {
                BIOSCheckSheet(check: check)
                    .onAppear { sheetIsOnScreen = true }
            }
    }

    /// Whether the system's chooser shows: while the check asks for a file and no job sheet is on screen.
    ///
    /// A refusal's Choose Another File… and a stop's Check Again close the sheet and ask for the chooser
    /// in one step (`chooseFile()`), so asked for straight away the chooser would be presented while the
    /// sheet is still going away; SwiftUI can drop a presentation made then, leaving `isChoosingFile`
    /// true with no panel and nothing that could open one. Held back until the sheet's `onDismiss`, the
    /// chooser is presented once the sheet has gone. Closing the chooser passes `false` through to the
    /// check; the chooser never sets it true.
    private var choosesFile: Binding<Bool> {
        Binding(
            get: { check.isChoosingFile && !sheetIsOnScreen },
            set: { if !$0 { check.isChoosingFile = false } }
        )
    }

    /// Whether the job sheet shows; the sheet closed without a button stops, continues or closes the check.
    private var showsJob: Binding<Bool> {
        Binding(
            get: { check.isShowingJob },
            set: { if !$0 { check.dismiss() } }
        )
    }
}

/// The check's job sheet, as the design's `Mac-BiosChecking`, `Mac-BiosWrongSize`, `Mac-BiosNoShell`
/// and `Mac-BiosDone` draw it: `PresentedJobSheet` over the check's `JobPresentation`, each button handed
/// back to the check. While the sheet closes it keeps the last job it showed, so its words don't vanish first.
struct BIOSCheckSheet: View {
    let check: BIOSCheckViewModel

    var body: some View {
        PresentedJobSheet(check.job) { check.perform($0) }
    }
}

#if DEBUG
#Preview("Checking") {
    BIOSCheckSheet(check: PreviewBIOS.checking())
}

#Preview("Reaching the shell") {
    BIOSCheckSheet(check: PreviewBIOS.reachingShell())
}

#Preview("Wrong size") {
    BIOSCheckSheet(check: PreviewBIOS.wrongSize())
}

#Preview("No shell") {
    BIOSCheckSheet(check: PreviewBIOS.noShell())
}

#Preview("Done") {
    BIOSCheckSheet(check: PreviewBIOS.done())
}

#Preview("Stopped") {
    BIOSCheckSheet(check: PreviewBIOS.stopped())
}

#Preview("Couldn’t read") {
    BIOSCheckSheet(check: PreviewBIOS.unreadable())
}

#Preview("Couldn’t keep") {
    BIOSCheckSheet(check: PreviewBIOS.notKept())
}
#endif
