// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

#if os(macOS)
import SwiftUI

/// The first run's and the BIOS's menu items, as the design's menus give them today: in the File
/// menu, in New's place, Choose BIOS File… (⌘O) while no BIOS is kept — Welcome's button, which 5d's
/// Add Games… takes over once one is; and the Console menu's Run the BIOS, while a BIOS is kept,
/// nothing plays and neither the check's chooser nor its sheet is open. Both do nothing under the
/// check's sheet, as the design's keys do under any sheet.
public struct BIOSCommands: Commands {
    private let check: BIOSCheckViewModel
    private let pane: BIOSPaneViewModel
    private let isPlaying: @MainActor () -> Bool

    /// The menu items over `check` and `pane`; `isPlaying` says whether a run plays, when Run the BIOS
    /// gives way to the player's own controls.
    public init(check: BIOSCheckViewModel, pane: BIOSPaneViewModel, isPlaying: @escaping @MainActor () -> Bool) {
        self.check = check
        self.pane = pane
        self.isPlaying = isPlaying
    }

    public var body: some Commands {
        CommandGroup(replacing: .newItem) {
            if !pane.hasBIOS {
                Button(BIOSText.chooseBIOSFile) { check.chooseFile() }
                    .keyboardShortcut("o")
                    .disabled(!check.canChooseFile)
            }
        }
        CommandMenu("Console") {
            Button(BIOSText.runTheBIOS) { pane.runBIOS() }
                .disabled(!pane.canRun || isPlaying() || check.isShowingJob || check.isChoosingFile)
        }
    }
}
#endif
