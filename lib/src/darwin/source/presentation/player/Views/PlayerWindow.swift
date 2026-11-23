// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

#if os(macOS)
import AppKit
import PresentationStyles
import SwiftUI

extension View {
    /// The player's window on macOS, as the design draws it: `playerChrome(_:idleTitle:)` and
    /// `playerFullScreen(_:)` together, for a window the player has to itself. The previews apply only
    /// the chrome, so no preview moves a window.
    public func playerWindow(_ viewModel: PlayerViewModel, idleTitle: String) -> some View {
        playerChrome(viewModel, idleTitle: idleTitle)
            .playerFullScreen(viewModel)
    }

    /// What the window draws around the player while it shows: the toolbar's Stop, Pause or Resume,
    /// Reset and Full screen, hidden in full screen; and the window's title, the run's name while it
    /// plays and `idleTitle` otherwise, with the run's status line under it. A window the player shares
    /// with other places (5c's Welcome and BIOS pane) applies it to the player alone.
    public func playerChrome(_ viewModel: PlayerViewModel, idleTitle: String) -> some View {
        modifier(PlayerChrome(viewModel: viewModel, idleTitle: idleTitle))
    }

    /// The window itself taken into and out of full screen with the player, and the player told when
    /// the system takes it there. Applied where it stays in the window whatever the window shows, so a
    /// run that ends in full screen still takes the window out of it when the player gives the window
    /// back.
    public func playerFullScreen(_ viewModel: PlayerViewModel) -> some View {
        modifier(PlayerWindowSync(viewModel: viewModel))
    }
}

/// The Game menu: what the app puts first (the library's Play, ↩), then Pause or Resume (⌘P), Reset…
/// (⌘R), Enter or Exit Full Screen (⌃⌘F) and Stop… (⌘.), each enabled only when it applies and the
/// player holds the window, as the design's shortcuts give them.
public struct PlayerCommands<Leading: View>: Commands {
    private let viewModel: PlayerViewModel
    private let isActive: @MainActor () -> Bool
    private let leading: Leading

    /// The Game menu for `viewModel`, opening with `leading`: the items the menu holds beyond the player's
    /// own, as the design's Game menu opens with Play. The player's own items act only while `isActive`
    /// says the player holds the window — a window that shows another place first, as the library's
    /// opening sheet does while the player already follows the session it powers on, says no.
    public init(viewModel: PlayerViewModel, isActive: @escaping @MainActor () -> Bool = { true }, @ViewBuilder leading: () -> Leading) {
        self.viewModel = viewModel
        self.isActive = isActive
        self.leading = leading()
    }

    public var body: some Commands {
        // ⌘P is the player's Pause: the File menu's printing items, which have nothing to print, give way.
        CommandGroup(replacing: .printItem) {}
        CommandMenu("Game") {
            leading
            Button(viewModel.pauseTitle) { viewModel.togglePause() }
                .keyboardShortcut("p")
                .disabled(!isActive() || !viewModel.canTogglePause)
            Button("Reset…") { viewModel.askToReset() }
                .keyboardShortcut("r")
                .disabled(!isActive() || !viewModel.canReset)
            Divider()
            Button(viewModel.fullScreenTitle) { viewModel.toggleFullScreen() }
                .keyboardShortcut("f", modifiers: [.control, .command])
                .disabled(!isActive() || !viewModel.canToggleFullScreen)
            Divider()
            Button("Stop…") { viewModel.askToStop() }
                .keyboardShortcut(".")
                .disabled(!isActive() || !viewModel.canStop)
        }
    }
}

extension PlayerCommands where Leading == EmptyView {
    /// The Game menu for `viewModel`, the player's own items alone, acting while `isActive`.
    public init(viewModel: PlayerViewModel, isActive: @escaping @MainActor () -> Bool = { true }) {
        self.init(viewModel: viewModel, isActive: isActive) { EmptyView() }
    }
}

/// What the window draws around the player: the toolbar, hidden in full screen, and the window's
/// title and status line.
private struct PlayerChrome: ViewModifier {
    let viewModel: PlayerViewModel
    let idleTitle: String

    func body(content: Content) -> some View {
        content
            .toolbar { PlayerToolbar(viewModel: viewModel) }
            .toolbar(viewModel.isFullScreen ? .hidden : .visible, for: .windowToolbar)
            .toolbarBackground(Palette.toolbar, for: .windowToolbar)
            .navigationTitle(viewModel.windowTitle ?? idleTitle)
            .modifier(PlayerSubtitle(viewModel: viewModel))
    }
}

/// The window's own full screen, kept in step with the player's both ways: the player's Full screen
/// takes the window there, and the window's green button or the View menu tells the player.
private struct PlayerWindowSync: ViewModifier {
    let viewModel: PlayerViewModel
    @State private var window = WindowReference()

    func body(content: Content) -> some View {
        content
            .background(WindowReader(reference: window))
            .onChange(of: viewModel.isFullScreen) { _, isFullScreen in
                window.setFullScreen(isFullScreen)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { notification in
                if window.holds(notification.object) { viewModel.fullScreenDidChange(true) }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { notification in
                if window.holds(notification.object) { viewModel.fullScreenDidChange(false) }
            }
    }
}

/// The status line under the window's title: on its own, since it changes every frame and nothing
/// else in the window needs to redraw with it.
private struct PlayerSubtitle: ViewModifier {
    let viewModel: PlayerViewModel

    func body(content: Content) -> some View {
        content.navigationSubtitle(viewModel.statusLine)
    }
}

/// The toolbar as the design draws it in the player: Stop and go back to the library at the leading edge,
/// then Pause or Resume and Reset, and after the design's separator Full screen, at the trailing edge,
/// each naming its shortcut in its help.
private struct PlayerToolbar: ToolbarContent {
    let viewModel: PlayerViewModel

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button { viewModel.askToStop() } label: {
                Label("Stop and go back to the library", systemImage: Symbols.back)
            }
            .help("Stop and go back to the library (⌘.)")
            .disabled(!viewModel.canStop)
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button { viewModel.togglePause() } label: {
                Label(viewModel.pauseTitle, systemImage: viewModel.state == .paused ? Symbols.play : Symbols.pause)
            }
            .help("\(viewModel.pauseTitle) (⌘P)")
            .disabled(!viewModel.canTogglePause)
            Button { viewModel.askToReset() } label: {
                Label("Reset", systemImage: Symbols.reset)
            }
            .help("Reset (⌘R)")
            .disabled(!viewModel.canReset)
        }
        // A group of its own: macOS toolbars have no separator item, so the design's separator before
        // Full screen is the gap between two groups.
        ToolbarItemGroup(placement: .primaryAction) {
            Button { viewModel.toggleFullScreen() } label: {
                Label("Full screen", systemImage: Symbols.fullScreen)
            }
            .help("Full screen (⌃⌘F)")
            .disabled(!viewModel.canToggleFullScreen)
        }
    }
}

/// The window the player is in, once it is in one.
@MainActor
private final class WindowReference {
    weak var window: NSWindow?

    /// Whether `object`, a notification's sender, is this window.
    func holds(_ object: Any?) -> Bool {
        guard let window, let sender = object as? NSWindow else { return false }
        return sender === window
    }

    /// Takes the window into full screen or out of it, unless it is there already.
    func setFullScreen(_ isFullScreen: Bool) {
        guard let window, window.styleMask.contains(.fullScreen) != isFullScreen else { return }
        window.toggleFullScreen(nil)
    }
}

/// Finds the window it is drawn in, for `WindowReference`.
private struct WindowReader: NSViewRepresentable {
    let reference: WindowReference

    func makeNSView(context: Context) -> NSView {
        WindowReaderView(reference: reference)
    }

    func updateNSView(_ view: NSView, context: Context) {}
}

/// An empty view that tells its reference the window it moves into.
private final class WindowReaderView: NSView {
    private let reference: WindowReference

    init(reference: WindowReference) {
        self.reference = reference
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        reference.window = window
    }
}

#if DEBUG
/// The player in its window's chrome, for the previews: the title, the status line and the toolbar,
/// never the window's full screen, so no preview moves a window. Xcode's canvas draws the chrome; an
/// image renderer draws the content alone.
private struct PlayerInWindow: View {
    let viewModel: PlayerViewModel

    var body: some View {
        NavigationStack {
            PlayerView(viewModel: viewModel)
                .modifier(PlayerChrome(viewModel: viewModel, idleTitle: "iStation"))
        }
        .frame(width: Metrics.layout.windowWidth, height: Metrics.layout.windowHeight)
    }
}

#Preview("Window, nothing loaded") {
    PlayerInWindow(viewModel: PreviewPlayer.nothingLoaded())
}

#Preview("Window, running") {
    PlayerInWindow(viewModel: PreviewPlayer.running())
}

#Preview("Window, running a PS-EXE") {
    PlayerInWindow(viewModel: PreviewPlayer.running(PreviewPlayer.program))
}

#Preview("Window, paused") {
    PlayerInWindow(viewModel: PreviewPlayer.paused())
}

#Preview("Window, Reset confirm") {
    PlayerInWindow(viewModel: PreviewPlayer.resetConfirm())
}

#Preview("Window, stopped") {
    PlayerInWindow(viewModel: PreviewPlayer.stopped())
}
#endif
#endif
