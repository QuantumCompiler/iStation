import PresentationStyles
import SwiftUI

/// The sidebar's places: the whole library, recently played, and one per console with its count.
struct SidebarView: View {
    @Bindable var viewModel: ShellViewModel

    var body: some View {
        List(selection: $viewModel.route) {
            Section("Library") {
                Label("All Games", systemImage: Symbols.allGames)
                    .badge(viewModel.gameCount)
                    .tag(SidebarItem.all)
                Label("Recently Played", systemImage: Symbols.recentlyPlayed)
                    .tag(SidebarItem.recent)
            }
            Section("Consoles") {
                ForEach(viewModel.platforms) { platform in
                    Label(platform.displayName, systemImage: Symbols.console(platform))
                        .badge(viewModel.gameCount(for: platform))
                        .tag(SidebarItem.platform(platform))
                }
            }
        }
    }
}

#if DEBUG
#Preview("Empty library") {
    SidebarView(viewModel: ShellViewModel(library: PreviewLibrary.make(.init())))
}

#Preview("Library") {
    SidebarView(viewModel: ShellViewModel(library: PreviewLibrary.make(PreviewLibrary.recorded)))
}
#endif
