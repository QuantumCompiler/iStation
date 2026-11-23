// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessSession
import DataLibrary
import Foundation
import PresentationAcknowledgements
import PresentationBIOS
import PresentationLibrary
import PresentationPlayer
import PresentationStyles
import SwiftUI

/// The macOS app: one main window — Welcome until a BIOS is kept, then the library, its sidebar's places
/// the games and the BIOS pane, and the player while a run plays, with its toolbar and the Game menu — and
/// the acknowledgements window from the app menu. The composition root: it builds the library, the console
/// sessions and the view-models, and holds no logic.
@main
struct iStationApp: App {
    /// The player's console session, paced by the system's clock. The player drives it; Run the BIOS
    /// (5c) and a PS-EXE's opening job (5d) power it on.
    private let session: ConsoleSession<ContinuousClock>
    /// The BIOS check's own console session: the player follows its session across a stop, so a check
    /// on that one would take the window.
    private let checkSession: ConsoleSession<ContinuousClock>
    @State private var player: PlayerViewModel
    @State private var pane: BIOSPaneViewModel
    @State private var check: BIOSCheckViewModel
    @State private var library: LibraryViewModel
    @State private var acknowledgements = AcknowledgementsViewModel(entries: Acknowledgement.bundled(for: "macOS"))

    init() {
        let session = ConsoleSession()
        let checkSession = ConsoleSession()
        // One library.json, kept by the BIOS screens and the library alike.
        let store = LibraryStore(url: Self.libraryURL)
        let player = PlayerViewModel(session: session)
        let pane = BIOSPaneViewModel(storage: LibraryBIOSStorage(store: store), session: session, home: Self.homeFolder) { run in
            player.started(PlayerRun(biosFileName: run.fileName, biosSize: run.size))
        }
        let check = BIOSCheckViewModel(session: checkSession, storage: LibraryBIOSStorage(store: store), onKept: { record in
            pane.kept(record)
        })
        // The BIOS check's chooser and sheet, the BIOS pane's alert, and Run the BIOS while the pane reads the
        // BIOS, cover the library as its own do: so nothing of the library powers on the session meanwhile.
        let library = LibraryViewModel(
            storage: LibraryStoreStorage(store: store), session: session, home: Self.homeFolder,
            isCovered: { check.isChoosingFile || check.isShowingJob || pane.alert != nil || pane.isStarting },
            onRun: { run in
                player.started(PlayerRun(
                    biosFileName: run.biosFileName, biosSize: run.biosSize,
                    program: PlayerRun.Program(name: run.name, fileName: run.fileName)
                ))
            },
            onBIOSMoved: { pane.kept($0) }
        )
        self.session = session
        self.checkSession = checkSession
        _player = State(initialValue: player)
        _pane = State(initialValue: pane)
        _check = State(initialValue: check)
        _library = State(initialValue: library)
    }

    var body: some Scene {
        // One window, one console at a time: a single `Window`, not a group, so neither File › New
        // nor the tab bar's + opens a second window over the same player.
        Window(Self.windowTitle, id: Self.mainWindowID) {
            MainWindow(player: player, pane: pane, check: check, library: library, idleTitle: Self.windowTitle)
        }
        .defaultSize(width: Metrics.mac.windowWidth, height: Metrics.mac.windowHeight)
        .commands {
            AcknowledgementsCommand()
            PlayerCommands(viewModel: player, isActive: { MainWindow.playerShows(player: player, library: library) }) {
                LibraryMenuItem.play(library) { showsLibrary }
                Divider()
            }
            BIOSCommands(check: check, pane: pane, isPlaying: { player.isPlaying || !library.canAct }) {
                LibraryMenuItem.place(.bios, of: library) { showsLibrary }
            }
            LibraryCommands(library: library, isShown: { pane.hasBIOS }, isActive: { showsLibrary })
        }

        Window("Acknowledgements", id: AcknowledgementsCommand.windowID) {
            AcknowledgementsView(viewModel: acknowledgements)
        }
    }

    /// Whether the library holds the window: a BIOS is kept and no run has taken the window.
    private var showsLibrary: Bool {
        MainWindow.showsLibrary(player: player, pane: pane, library: library)
    }

    /// The main window's identifier.
    static let mainWindowID = "main"

    /// The window title while nothing plays says which routine built the app; while a run plays the
    /// player names it there instead, as the design does.
    static var windowTitle: String {
        #if PERSONAL_BUILD
        "iStation — Personal build"
        #else
        "iStation"
        #endif
    }

    /// The library, `library.json`, in this build's own Application Support folder: under the personal
    /// build's own identifier, unsandboxed, and inside the App Store build's container.
    static var libraryURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "local.istation.macos", isDirectory: true)
            .appendingPathComponent("library.json")
    }

    /// The person's own home folder, so the BIOS pane and the library write the folders in it from "~" —
    /// the account's, not the App Store build's container, which the sandbox reports as home.
    static var homeFolder: String? {
        guard let account = getpwuid(getuid()), let home = account.pointee.pw_dir else { return nil }
        return String(cString: home)
    }
}

/// The main window's content: the player while a run plays, else the library once a BIOS is kept, else
/// Welcome. The library keeps the window while a PS-EXE's opening job shows, though the player's session
/// is already running, until the job hands the run to the player. The check's chooser and sheet, and the
/// window's full screen, sit around all three, so a check that keeps a BIOS outlasts Welcome and lands on
/// the library, and a run that ends in full screen leaves it.
struct MainWindow: View {
    let player: PlayerViewModel
    let pane: BIOSPaneViewModel
    let check: BIOSCheckViewModel
    let library: LibraryViewModel
    let idleTitle: String
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            if Self.playerShows(player: player, library: library) {
                PlayerView(viewModel: player)
                    .playerChrome(player, idleTitle: idleTitle)
            } else if pane.hasBIOS {
                LibraryView(viewModel: library) {
                    BIOSPaneView(viewModel: pane, check: check)
                }
            } else {
                WelcomeView(check: check) { openWindow(id: AcknowledgementsCommand.windowID) }
                    .navigationTitle(idleTitle)
            }
        }
        .biosCheck(check)
        .playerFullScreen(player)
        .toolbarBackground(Palette.toolbar, for: .windowToolbar)
        .frame(minWidth: Metrics.mac.windowMinWidth, minHeight: Metrics.mac.windowMinHeight - Metrics.mac.toolbar)
    }

    /// Whether the player holds the window: a run plays, and no opening job is still handing one over or
    /// stopping the console of one it cancelled.
    static func playerShows(player: PlayerViewModel, library: LibraryViewModel) -> Bool {
        library.playerHoldsWindow(whilePlaying: player.isPlaying)
    }

    /// Whether the library holds the window: a BIOS is kept and the player doesn't hold it.
    static func showsLibrary(player: PlayerViewModel, pane: BIOSPaneViewModel, library: LibraryViewModel) -> Bool {
        pane.hasBIOS && !playerShows(player: player, library: library)
    }
}

/// "Acknowledgements…" in the app menu, after "About iStation".
struct AcknowledgementsCommand: Commands {
    static let windowID = "acknowledgements"

    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Acknowledgements…") { openWindow(id: Self.windowID) }
        }
    }
}
