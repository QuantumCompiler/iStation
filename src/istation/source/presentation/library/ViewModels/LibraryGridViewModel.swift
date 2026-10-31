import BusinessLibrary
import Foundation
import Observation

/// The game grid for the place the shell is showing.
@MainActor
@Observable
public final class LibraryGridViewModel {
    /// The shell's current place and search text.
    public typealias Query = @MainActor () -> (filter: LibraryFilter, search: String)

    private let library: Library
    private let query: Query
    private let requestFolders: @MainActor () -> Void

    /// `requestFolders` asks the shell to show its folder chooser, for the empty state's button.
    public init(library: Library, query: @escaping Query, requestFolders: @escaping @MainActor () -> Void) {
        self.library = library
        self.query = query
        self.requestFolders = requestFolders
    }

    /// The tiles for the current place and search, in library order.
    public var tiles: [GameTileModel] {
        let (filter, search) = query()
        return library.games(for: filter, matching: search).map { game in
            GameTileModel(game: game, isRunning: library.runningGameID == game.id)
        }
    }

    public func play(_ tile: GameTileModel) {
        guard let game = library.games.first(where: { $0.id == tile.id }) else { return }
        library.launch(game)
    }

    public func chooseFolders() {
        requestFolders()
    }
}
