// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

#if os(macOS)
import PresentationStyles
import SwiftUI

/// The library's menu items, in the menus the design's Layout page names, while a BIOS is kept and the
/// library is the window's home: in the File menu, Add Games… (⌘O, Welcome's Choose BIOS File… until a BIOS
/// is kept), Add Folder… (⇧⌘O), Show in Finder and Remove from Library… (⌘⌫); in the Edit menu, Search
/// (⌘F); in the View menu, All Games (⌘1) and Recently Played (⌘4), as List and as Grid, the sidebar
/// (⌃⌘S) and Game info (⌘I). The Game menu's Play (↩) and the Console menu's BIOS (⌘6) are
/// `LibraryMenuItem`s, which the app puts in those menus. Each does nothing while the library isn't on
/// screen, or a sheet, a chooser or an alert is open over it — the library's own, or another screen's its
/// `canAct` hears of — as the design's keys do under any sheet. Search is off on macOS 14, where SwiftUI
/// can't focus the toolbar's field; Play and Remove give way to the search field while it has focus.
public struct LibraryCommands: Commands {
    private let library: LibraryViewModel
    private let isShown: @MainActor () -> Bool
    private let isActive: @MainActor () -> Bool
    @FocusedValue(\.librarySearch) private var search

    /// The menu items over `library`: shown while `isShown` (a BIOS is kept), and acting while `isActive`
    /// (the library is on screen, not the player) and `library.canAct` (nothing is open over it).
    public init(library: LibraryViewModel, isShown: @escaping @MainActor () -> Bool, isActive: @escaping @MainActor () -> Bool) {
        self.library = library
        self.isShown = isShown
        self.isActive = isActive
    }

    public var body: some Commands {
        CommandGroup(after: .newItem) {
            if isShown() {
                Button(LibraryText.addGames) { library.chooseGames() }
                    .keyboardShortcut("o")
                    .disabled(!acts)
                Button(LibraryText.addFolder) { library.chooseFolder() }
                    .keyboardShortcut("o", modifiers: [.shift, .command])
                    .disabled(!acts)
                Divider()
                Button(LibraryText.showInFinder) {
                    if let url = library.fileToShowInFinder() { Finder.select(url) }
                }
                .disabled(!acts || !library.place.listsGames || library.info?.canShowInFinder != true)
                Button(LibraryText.removeFromLibrary) { library.askToRemove() }
                    .keyboardShortcut(.delete, modifiers: .command)
                    .disabled(!isActive() || !library.place.listsGames || !library.canRemoveSelected)
            }
        }
        CommandGroup(after: .textEditing) {
            if isShown() {
                Button(LibraryText.search) { search?.focus() }
                    .keyboardShortcut("f")
                    .disabled(!acts || search == nil)
            }
        }
        CommandGroup(before: .toolbar) {
            if isShown() {
                ForEach(LibraryPlace.Section.library.places) { place in
                    LibraryMenuItem.place(place, of: library, isActive: isActive)
                }
                Divider()
                Picker(LibraryText.view, selection: Bindable(library).viewMode) {
                    Text(LibraryText.asList).tag(LibraryViewModel.ViewMode.list)
                    Text(LibraryText.asGrid).tag(LibraryViewModel.ViewMode.grid)
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .disabled(!acts || !library.place.listsGames)
                Divider()
                Button(library.isShowingSidebar ? LibraryText.hideSidebarItem : LibraryText.showSidebarItem) {
                    library.toggleSidebar()
                }
                .keyboardShortcut("s", modifiers: [.control, .command])
                .disabled(!acts)
                Button(library.showsInfo ? LibraryText.hideGameInfo : LibraryText.showGameInfo) { library.toggleInfo() }
                    .keyboardShortcut("i")
                    .disabled(!acts || !library.canToggleInfo)
                Divider()
            }
        }
    }

    /// Whether the library's items act now: it is on screen, and nothing is open over it. Remove's and
    /// Play's keys ask `canRemoveSelected` and `canPlaySelected`, which hear the same and the search field.
    private var acts: Bool { isActive() && library.canAct }
}

/// A library item that can sit in any menu: the Game menu's Play (↩), which plays the selected game as
/// Return and a double-click do — on for a PS-EXE whose file is there, and for any game whose file is
/// missing, which asks to Locate… it or remove it — and a place with its shortcut: the View menu's All
/// Games (⌘1) and Recently Played (⌘4), which `LibraryCommands` puts there, and the Console menu's BIOS
/// (⌘6). The app puts Play in `PlayerCommands`' menu and BIOS in `BIOSCommands`'.
public struct LibraryMenuItem: View {
    private enum Kind {
        case play
        case place(LibraryPlace)
    }

    private let kind: Kind
    private let library: LibraryViewModel
    private let isActive: @MainActor () -> Bool

    /// Play (↩), over `library`, acting while `isActive` (the library is on screen).
    public static func play(_ library: LibraryViewModel, isActive: @escaping @MainActor () -> Bool) -> LibraryMenuItem {
        LibraryMenuItem(kind: .play, library: library, isActive: isActive)
    }

    /// `place`, with its shortcut (⌘1, ⌘4, ⌘6), over `library`, acting while `isActive`.
    public static func place(_ place: LibraryPlace, of library: LibraryViewModel, isActive: @escaping @MainActor () -> Bool) -> LibraryMenuItem {
        LibraryMenuItem(kind: .place(place), library: library, isActive: isActive)
    }

    public var body: some View {
        switch kind {
        case .play:
            Button(LibraryText.play) { library.play() }
                .keyboardShortcut(.return, modifiers: [])
                .disabled(!isActive() || !library.place.listsGames || !library.canPlaySelected)
        case .place(let place):
            Button(place.title) { library.go(to: place) }
                .keyboardShortcut(KeyEquivalent(place.shortcutKey))
                .disabled(!isActive() || !library.canAct)
        }
    }
}

#if DEBUG
#Preview("Menu items") {
    let library = PreviewLibrary.today()
    VStack(alignment: .leading, spacing: Metrics.space2) {
        LibraryMenuItem.play(library) { true }
        ForEach(LibraryPlace.allCases) { place in
            LibraryMenuItem.place(place, of: library) { true }
        }
    }
    .padding(Metrics.space4)
}
#endif
#endif
