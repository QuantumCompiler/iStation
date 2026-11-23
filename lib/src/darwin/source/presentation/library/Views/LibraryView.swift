// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

#if os(macOS)
import AppKit
import PresentationStyles
import SwiftUI

/// The library window, as the design draws it at the Today level (boards `Mac-LibraryEmpty`,
/// `Mac-TodayLibrary`, `Mac-LibraryGrid`, `Mac-LibraryInspector`, `Mac-LibrarySearchEmpty`,
/// `Mac-LibraryMissing`, `Mac-LibraryMin`): the sidebar's places beside the place shown — the games, in
/// the table or the grid, with search and Game info in the toolbar, or the BIOS pane the app hands in —
/// and the library's choosers, sheets and alerts over them. Its layout follows the design's Layout page:
/// under 1,100 points of window Game info hides the sidebar, and the table drops Format under 880 points
/// of content and Last played under 700, so it fits the window's least, 800 × 560: the games never get
/// narrower than `gamesMinWidth`, which the least window holds beside the sidebar and Game info together.
/// It looks for the games' files again whenever the app becomes active.
public struct LibraryView<BIOSPane: View>: View {
    @Bindable private var viewModel: LibraryViewModel
    private let biosPane: BIOSPane
    /// Shows a file in the Finder: the system's way in the app, nothing in the previews.
    private let reveal: @MainActor (URL) -> Void
    /// The window's width, which the layout's breakpoints read.
    @State private var windowWidth = Metrics.layout.windowWidth
    @FocusState private var isSearchFocused: Bool

    /// The library over `viewModel`, its BIOS place drawing `biosPane`.
    public init(viewModel: LibraryViewModel, @ViewBuilder biosPane: () -> BIOSPane) {
        self.init(viewModel: viewModel, reveal: Finder.select, biosPane: biosPane)
    }

    /// The library, showing files through `reveal`: the previews pass one that does nothing, so no preview
    /// reaches the Finder.
    init(viewModel: LibraryViewModel, reveal: @escaping @MainActor (URL) -> Void, @ViewBuilder biosPane: () -> BIOSPane) {
        self.viewModel = viewModel
        self.reveal = reveal
        self.biosPane = biosPane()
    }

    public var body: some View {
        let layout = viewModel.layout(windowWidth: windowWidth)
        NavigationSplitView(columnVisibility: sidebarVisibility(layout)) {
            // The split view's own sidebar button gives way to the view-model's, as the design has one.
            LibrarySidebar(viewModel: viewModel)
                .toolbar(removing: .sidebarToggle)
                .navigationSplitViewColumnWidth(Metrics.layout.sidebar)
        } detail: {
            detail(layout)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { viewModel.toggleSidebar() } label: {
                    Label(viewModel.sidebarButton.title, systemImage: Symbols.sidebar)
                }
                .help(viewModel.sidebarButton.help)
            }
        }
        .toolbarBackground(Palette.toolbar, for: .windowToolbar)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { windowWidth = $0 }
        .libraryPresentations(viewModel)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            viewModel.checkFiles()
        }
    }

    /// The place shown: the games, with their toolbar, search and Game info; or the BIOS pane, which titles
    /// the window itself.
    @ViewBuilder private func detail(_ layout: LibraryLayout) -> some View {
        if viewModel.place.listsGames {
            // A least width no wider than the least window holds beside the sidebar — which the split view
            // counts twice once the games have an inspector — and Game info together: the split view shows
            // the two for a moment when the window narrows with Game info open, before the breakpoint hides
            // the sidebar, and when Game info closes and the sidebar comes back, and AppKit throws on a
            // window whose split view can't fit. A height that doesn't follow the games' content, so the
            // split view measuring them that narrow — the banner and the empty library's text wrapped word
            // by word — asks the window for no height.
            GamesView(viewModel: viewModel, columns: layout.columns)
                .frame(minWidth: Metrics.layout.gamesMinWidth)
                .frame(minHeight: .zero, maxHeight: .infinity, alignment: .top)
                .navigationTitle(viewModel.windowTitle)
                .navigationSubtitle(viewModel.windowSubtitle)
                .toolbar { LibraryToolbar(viewModel: viewModel) }
                .searchable(text: $viewModel.query, placement: .toolbar, prompt: Text(LibraryText.search))
                .modifier(SearchFocus(isFocused: $isSearchFocused, search: LibrarySearch { isSearchFocused = true }))
                .onChange(of: isSearchFocused) { _, isFocused in viewModel.isSearchFocused = isFocused }
                // The field goes with the games — the player taking the window, or the BIOS place — and
                // hears no change of focus as it goes: so it no longer has Return and ⌘⌫.
                .onDisappear { viewModel.isSearchFocused = false }
                .inspector(isPresented: showsInfo) {
                    GameInfoView(viewModel: viewModel, reveal: reveal)
                        .inspectorColumnWidth(Metrics.layout.inspector)
                }
        } else {
            biosPane
        }
    }

    /// The sidebar shown or hidden as `layout`, this draw's, has it, so one draw never shows two layouts —
    /// and the split view's own changes handed to the view-model, which keeps the person's alone, whatever
    /// layout an earlier draw captured: hiding the sidebar while Game info shows is the breakpoint's. The
    /// window's least width is what keeps AppKit's constraints settling (`Metrics.layout.gamesMinWidth`).
    private func sidebarVisibility(_ layout: LibraryLayout) -> Binding<NavigationSplitViewVisibility> {
        Binding(
            get: { layout.showsSidebar ? .all : .detailOnly },
            set: { viewModel.splitViewShowsSidebar($0 != .detailOnly) }
        )
    }

    /// Game info shown as the view-model has it; closed by hand, it is the person's ⌘I.
    private var showsInfo: Binding<Bool> {
        Binding(
            get: { viewModel.showsInfo },
            set: { if $0 != viewModel.showsInfo { viewModel.toggleInfo() } }
        )
    }
}

/// The games a place shows: the note that discs can't be read or played yet, then the empty library, the
/// search with no results, or the games in the table or the grid.
struct GamesView: View {
    @Bindable var viewModel: LibraryViewModel
    /// The table's columns at the width the window leaves.
    let columns: [LibraryLayout.Column]

    var body: some View {
        VStack(alignment: .leading, spacing: .zero) {
            if viewModel.showsTodayBanner {
                Banner(LibraryText.todayBanner, tone: .info)
                    .padding(.horizontal, Metrics.space4)
                    .padding(.top, Metrics.space3)
                    .padding(.bottom, Metrics.space1)
            }
            switch viewModel.content {
            case .empty:
                LibraryEmptyView(viewModel: viewModel)
            case .noResults(let text):
                NoResultsView(text: text) { viewModel.clearSearch() }
            case .games:
                switch viewModel.viewMode {
                case .list: GameTable(viewModel: viewModel, columns: columns)
                case .grid: GameGrid(viewModel: viewModel)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.content)
    }
}

/// The toolbar over the games, as the design draws it: Add Games and Add Folder, the list and the grid,
/// and Game info, each naming its shortcut in its help; the search field follows, at the trailing edge.
private struct LibraryToolbar: ToolbarContent {
    @Bindable var viewModel: LibraryViewModel

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button { viewModel.chooseGames() } label: {
                Label(LibraryText.addGamesButton, systemImage: Symbols.add)
            }
            .help(LibraryText.addGamesHelp)
            .disabled(!viewModel.canAct)
            Button { viewModel.chooseFolder() } label: {
                Label(LibraryText.addFolderButton, systemImage: Symbols.addFolder)
            }
            .help(LibraryText.addFolderHelp)
            .disabled(!viewModel.canAct)
        }
        // Groups of their own: macOS toolbars have no separator item, so the design's separators are the
        // gaps between groups.
        ToolbarItem(placement: .primaryAction) {
            Picker(selection: $viewModel.viewMode) {
                Label(LibraryText.showAsList, systemImage: Symbols.listView)
                    .help(LibraryText.showAsList)
                    .tag(LibraryViewModel.ViewMode.list)
                Label(LibraryText.showAsGrid, systemImage: Symbols.gridView)
                    .help(LibraryText.showAsGrid)
                    .tag(LibraryViewModel.ViewMode.grid)
            } label: {
                Text(LibraryText.view)
            }
            .pickerStyle(.segmented)
        }
        ToolbarItem(placement: .primaryAction) {
            Toggle(isOn: showsInfo) {
                Label(LibraryText.gameInfo, systemImage: Symbols.info)
            }
            .toggleStyle(.button)
            .help(LibraryText.gameInfoHelp)
            .disabled(!viewModel.canToggleInfo)
        }
    }

    private var showsInfo: Binding<Bool> {
        Binding(
            get: { viewModel.showsInfo },
            set: { if $0 != viewModel.showsInfo { viewModel.toggleInfo() } }
        )
    }
}

/// Search (⌘F) puts the person in the toolbar's search field, and the field's focus is followed, from
/// macOS 15, where SwiftUI can focus it. On macOS 14 the menus are offered no search, so Search is off.
private struct SearchFocus: ViewModifier {
    let isFocused: FocusState<Bool>.Binding
    /// What the Edit menu's Search does.
    let search: LibrarySearch

    func body(content: Content) -> some View {
        if #available(macOS 15, *) {
            content
                .searchFocused(isFocused)
                .focusedSceneValue(\.librarySearch, search)
        } else {
            content
        }
    }
}

/// What the Edit menu's Search (⌘F) does while the games show: focus the search field.
struct LibrarySearch {
    /// Puts the person in the search field.
    let focus: @MainActor () -> Void
}

private struct LibrarySearchKey: FocusedValueKey {
    typealias Value = LibrarySearch
}

extension FocusedValues {
    /// The search the games' window offers its menus, while it is the key window.
    var librarySearch: LibrarySearch? {
        get { self[LibrarySearchKey.self] }
        set { self[LibrarySearchKey.self] = newValue }
    }
}

/// Shows files in the Finder, inside the access their bookmark gave.
enum Finder {
    /// Selects `url` in a Finder window, inside its security-scoped access.
    @MainActor
    static func select(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

#if DEBUG
/// The library window for the previews, its BIOS place a stand-in, showing no file in the Finder.
private struct PreviewLibraryWindow: View {
    let viewModel: LibraryViewModel

    var body: some View {
        LibraryView(viewModel: viewModel, reveal: { _ in }) {
            Text(LibraryPlace.bios.title)
        }
    }
}

#Preview("Empty") {
    PreviewLibraryWindow(viewModel: PreviewLibrary.empty())
        .inPreviewWindow()
}

#Preview("Today") {
    PreviewLibraryWindow(viewModel: PreviewLibrary.today())
        .inPreviewWindow()
}

#Preview("List") {
    PreviewLibraryWindow(viewModel: PreviewLibrary.listed())
        .inPreviewWindow()
}

#Preview("Grid") {
    PreviewLibraryWindow(viewModel: PreviewLibrary.grid())
        .inPreviewWindow()
}

#Preview("Game info") {
    PreviewLibraryWindow(viewModel: PreviewLibrary.info())
        .inPreviewWindow()
}

#Preview("Search with no results") {
    PreviewLibraryWindow(viewModel: PreviewLibrary.searchEmpty())
        .inPreviewWindow()
}

#Preview("File missing") {
    PreviewLibraryWindow(viewModel: PreviewLibrary.missing())
        .inPreviewWindow()
}

#Preview("Remove confirm") {
    PreviewLibraryWindow(viewModel: PreviewLibrary.removeConfirm())
        .inPreviewWindow()
}

#Preview("Rename") {
    PreviewLibraryWindow(viewModel: PreviewLibrary.rename())
        .inPreviewWindow()
}

#Preview("Minimum size") {
    PreviewLibraryWindow(viewModel: PreviewLibrary.listed())
        .inLeastWindow()
}

#Preview("Minimum size, Game info") {
    PreviewLibraryWindow(viewModel: PreviewLibrary.today())
        .inLeastWindow()
}

#Preview("Light") {
    PreviewLibraryWindow(viewModel: PreviewLibrary.today())
        .inPreviewWindow()
        .preferredColorScheme(.light)
}

#Preview("High contrast") {
    // The palette draws high contrast under Increase Contrast: the canvas's Increased Contrast variant.
    PreviewLibraryWindow(viewModel: PreviewLibrary.today())
        .inPreviewWindow()
        .preferredColorScheme(.dark)
}

#Preview("Scan picker") {
    // The system's own folder chooser opens over the library; no preview draws it.
    PreviewLibraryWindow(viewModel: PreviewLibrary.scanPicker())
        .inPreviewWindow()
}

#Preview("Scanning") {
    PreviewLibraryWindow(viewModel: PreviewLibrary.scanRunning())
        .inPreviewWindow()
}

#Preview("Opening") {
    PreviewLibraryWindow(viewModel: PreviewLibrary.opening())
        .inPreviewWindow()
}
#endif
#endif
