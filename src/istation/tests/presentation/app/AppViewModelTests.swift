import Foundation
import InfrastructureBundles
import InfrastructureLocations
import InfrastructureProcess
import PresentationApp
import SupportSandbox
import Testing

private struct NoRunner: ProcessRunning {
    func run(_ command: Command, onExit: @escaping @Sendable (ProcessExit) -> Void) throws {}
}

private struct TableLookup: AppLookup {
    var apps: [String: URL] = [:]
    func installedApp(bundleIdentifier: String) -> URL? { apps[bundleIdentifier] }
}

@MainActor
@Suite struct AppViewModelTests {
    @Test func theLibraryFileLivesInTheGivenApplicationSupport() throws {
        let sandbox = try Sandbox()
        let model = AppViewModel(locations: .sandbox(root: sandbox.root), runner: NoRunner(), lookup: TableLookup())

        model.settings.startsFullscreen = false

        let file = sandbox.url("Library/Application Support/iStation/library.json")
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test func emulatorsAreFoundInTheGivenFolders() throws {
        let sandbox = try Sandbox()
        try sandbox.makeApp("Applications/DuckStation.app", binary: "DuckStation")
        let lookup = TableLookup(apps: ["net.rpcs3.rpcs3": URL(fileURLWithPath: "/Elsewhere/RPCS3.app")])

        let model = AppViewModel(locations: .sandbox(root: sandbox.root), runner: NoRunner(), lookup: lookup)

        #expect(model.settings.emulators.map { $0.appPath != nil } == [true, false, true])
    }

    @Test func theGridFollowsTheShellsRouteAndSearch() throws {
        let sandbox = try Sandbox()
        try sandbox.write(Self.twoGames, to: "Library/Application Support/iStation/library.json")
        let model = AppViewModel(locations: .sandbox(root: sandbox.root), runner: NoRunner(), lookup: TableLookup())

        #expect(model.grid.tiles.map(\.title) == ["Crash Bandicoot", "game"])
        model.shell.route = .recent
        #expect(model.grid.tiles.map(\.title) == ["Crash Bandicoot"])
        model.shell.route = .all
        model.shell.search = "sles"
        #expect(model.grid.tiles.map(\.title) == ["game"])
        #expect(!model.isPlaying)
    }

    /// A library.json as LibraryStore writes it: one played PS1 game, one unplayed PS2 game.
    private static let twoGames = """
    {
      "games" : [
        {
          "bootTarget" : { "path" : { "_0" : "file:///Games/PS1/Crash%20Bandicoot%20(USA).cue" } },
          "id" : "ps1:/Games/PS1/Crash Bandicoot (USA).cue",
          "lastPlayed" : "2026-10-26T18:00:00Z",
          "location" : "file:///Games/PS1/Crash%20Bandicoot%20(USA).cue",
          "platform" : "ps1",
          "playTime" : 600,
          "serial" : "SCUS-94900",
          "title" : "Crash Bandicoot"
        },
        {
          "bootTarget" : { "path" : { "_0" : "file:///Games/PS2/game.iso" } },
          "id" : "ps2:/Games/PS2/game.iso",
          "location" : "file:///Games/PS2/game.iso",
          "platform" : "ps2",
          "playTime" : 0,
          "serial" : "SLES-52338",
          "title" : "game"
        }
      ]
    }
    """
}
