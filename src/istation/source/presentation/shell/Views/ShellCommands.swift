import SwiftUI

/// The File menu's library commands: Add Library Folder… (⌘O) and Rescan Library (⌘R).
public struct ShellCommands: Commands {
    private let viewModel: ShellViewModel

    public init(viewModel: ShellViewModel) {
        self.viewModel = viewModel
    }

    public var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Add Library Folder…") { viewModel.chooseFolders() }
                .keyboardShortcut("o")
            Button("Rescan Library") { Task { await viewModel.rescan() } }
                .keyboardShortcut("r")
        }
    }
}
