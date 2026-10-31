import BusinessLibrary
import DataCatalog
import DataStore
import Foundation
@testable import PresentationLibrary
import SupportLibraryFakes
import Testing

@MainActor
@Suite struct LibraryGridViewModelTests {
    @Test func tilesFollowTheShellsPlaceAndSearch() {
        let library = LibraryHarness(LibraryState(games: FixtureGames.all)).library
        var query: (filter: LibraryFilter, search: String) = (.all, "")
        let grid = LibraryGridViewModel(library: library, query: { query }, requestFolders: {})

        #expect(grid.tiles.map(\.title) == ["Crash Bandicoot", "game", "Demon's Souls"])
        query = (.platform(.ps3), "")
        #expect(grid.tiles.map(\.title) == ["Demon's Souls"])
        query = (.all, "SCUS")
        #expect(grid.tiles.map(\.title) == ["Crash Bandicoot"])
    }

    @Test func playingMarksTheTileRunning() {
        let harness = LibraryHarness(LibraryState(games: FixtureGames.all))
        let grid = LibraryGridViewModel(library: harness.library, query: { (.all, "") }, requestFolders: {})

        grid.play(grid.tiles[1])

        #expect(harness.starter.started == [FixtureGames.ps2])
        #expect(grid.tiles.map(\.isRunning) == [false, true, false])
    }

    @Test func detailShowsTheSerialAndPlayTimeAfterAMinute() {
        var long = FixtureGames.crash
        long.playTime = 3 * 3600 + 5 * 60
        var short = FixtureGames.ps2
        short.playTime = 59
        let unknown = Game(title: "X", serial: nil, platform: .ps1, location: URL(fileURLWithPath: "/x.cue"),
                           bootTarget: .path(URL(fileURLWithPath: "/x.cue")))

        #expect(GameTileModel(game: long, isRunning: false).detail == "SCUS-94900 · 3h 5m")
        #expect(GameTileModel(game: short, isRunning: false).detail == "SLES-52338")
        #expect(GameTileModel(game: unknown, isRunning: false).detail == "Unknown serial")
    }

    @Test func theEmptyStateAsksTheShellForFolders() {
        var asked = 0
        let grid = LibraryGridViewModel(library: LibraryHarness().library, query: { (.all, "") }, requestFolders: { asked += 1 })
        #expect(grid.tiles.isEmpty)
        grid.chooseFolders()
        #expect(asked == 1)
    }
}
