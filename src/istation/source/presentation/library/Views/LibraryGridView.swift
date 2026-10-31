import AppKit
import PresentationStyles
import SwiftUI

/// The game grid for the current place (double-click to play), or an empty state inviting a folder.
public struct LibraryGridView: View {
    private let viewModel: LibraryGridViewModel

    private let columns = [
        GridItem(.adaptive(minimum: Metrics.tileMinWidth, maximum: Metrics.tileMaxWidth), spacing: Metrics.gridColumnSpacing),
    ]

    public init(viewModel: LibraryGridViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        let tiles = viewModel.tiles
        if tiles.isEmpty {
            ContentUnavailableView {
                Label("No Games", systemImage: Symbols.noGames)
            } description: {
                Text("Add a folder of disc images (.cue, .iso, .chd, .m3u…) or PS3 game folders.")
            } actions: {
                Button("Add Library Folder…") { viewModel.chooseFolders() }
            }
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: Metrics.gridRowSpacing) {
                    ForEach(tiles) { tile in
                        GameTile(model: tile)
                            .onTapGesture(count: 2) { viewModel.play(tile) }
                            .contextMenu {
                                Button("Play") { viewModel.play(tile) }
                                Button("Show in Finder") {
                                    NSWorkspace.shared.activateFileViewerSelecting([tile.location])
                                }
                            }
                    }
                }
                .padding(Metrics.gridPadding)
            }
        }
    }
}

#if DEBUG
#Preview("Empty library") {
    LibraryGridView(viewModel: PreviewLibrary.grid(PreviewLibrary.make(.init())))
}

#Preview("Library") {
    LibraryGridView(viewModel: PreviewLibrary.grid(PreviewLibrary.make(PreviewLibrary.recorded)))
}

#Preview("Playing") {
    let library = PreviewLibrary.make(PreviewLibrary.recorded)
    let viewModel = PreviewLibrary.grid(library)
    viewModel.play(viewModel.tiles[0])
    return LibraryGridView(viewModel: viewModel)
}
#endif
