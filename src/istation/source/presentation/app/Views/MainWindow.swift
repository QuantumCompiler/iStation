import AppKit
import PresentationLibrary
import PresentationShell
import PresentationStyles
import SwiftUI

/// The main window: the shell with the game grid as its detail. Comes back to the front when the
/// running game's emulator quits.
struct MainWindow: View {
    let model: AppViewModel

    var body: some View {
        ShellView(viewModel: model.shell) {
            LibraryGridView(viewModel: model.grid)
        }
        .frame(minWidth: Metrics.windowMinWidth, minHeight: Metrics.windowMinHeight)
        .onChange(of: model.isPlaying) { wasPlaying, isPlaying in
            if wasPlaying && !isPlaying {
                NSApplication.shared.activate()
            }
        }
    }
}

#if DEBUG
#Preview("First launch") {
    MainWindow(model: PreviewApp.firstLaunch())
}
#endif
