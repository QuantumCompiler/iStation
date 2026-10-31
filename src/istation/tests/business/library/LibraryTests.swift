import BusinessLibrary
import DataCatalog
import DataEmulators
import DataStore
import Foundation
import SupportLibraryFakes
import Testing

@MainActor
@Suite struct LibraryTests {
    @Test func loadsTheSavedStateAndFillsInInstalledEmulators() {
        var settings = AppSettings()
        let chosen = URL(fileURLWithPath: "/Chosen/PCSX2.app")
        settings.setApp(chosen, for: .pcsx2)
        let found = URL(fileURLWithPath: "/Applications/RPCS3.app")
        let harness = LibraryHarness(
            LibraryState(games: FixtureGames.all, settings: settings),
            installed: [.pcsx2: URL(fileURLWithPath: "/Other/PCSX2.app"), .rpcs3: found]
        )

        #expect(harness.library.games == FixtureGames.all)
        #expect(harness.library.settings.app(for: .pcsx2) == chosen) // a chosen app is never replaced
        #expect(harness.library.settings.app(for: .rpcs3) == found)
        #expect(harness.store.state.settings.app(for: .rpcs3) == found)
    }

    @Test func rescanKeepsPlayHistoryByGameID() async {
        var played = FixtureGames.crash
        played.playTime = 600
        played.lastPlayed = Date(timeIntervalSince1970: 1_700_000_000)
        let harness = LibraryHarness(LibraryState(games: [played]), scanned: [FixtureGames.crash, FixtureGames.ps2])

        await harness.library.rescan()

        #expect(harness.library.games.map(\.id) == [FixtureGames.crash.id, FixtureGames.ps2.id])
        #expect(harness.library.games[0].playTime == 600)
        #expect(harness.library.games[0].lastPlayed == played.lastPlayed)
        #expect(harness.library.games[1].playTime == 0)
        #expect(harness.store.state.games == harness.library.games)
        #expect(!harness.library.isScanning)
    }

    @Test func rescanIncludesRPCS3InstalledGamesOnlyWhenAsked() async {
        let harness = LibraryHarness()
        await harness.library.rescan()
        harness.library.updateSettings { $0.includeRPCS3InstalledGames = false }
        await harness.library.rescan()

        #expect(harness.scanner.scans.map(\.rpcs3GameFolder) == [LibraryHarness.defaultRPCS3GameFolder, nil])
    }

    @Test func addingFoldersHintsTheirConsoleAndRescans() async {
        let harness = LibraryHarness(scanned: [FixtureGames.ps2])
        let ps2 = URL(fileURLWithPath: "/Games/PS2")

        await harness.library.addFolders([ps2, ps2])

        #expect(harness.library.folders.map(\.url) == [ps2])
        #expect(harness.library.folders.first?.platformHint == .ps2)
        #expect(harness.scanner.scans.count == 1)
        #expect(harness.library.games == [FixtureGames.ps2])
    }

    @Test func removingAFolderRescans() async {
        let folder = LibraryFolder(url: URL(fileURLWithPath: "/Games"))
        let harness = LibraryHarness(LibraryState(folders: [folder]))

        await harness.library.removeFolder(id: folder.id)

        #expect(harness.library.folders.isEmpty)
        #expect(harness.scanner.scans.map(\.folders) == [[]])
    }

    @Test func aPlayedSessionAddsItsPlayTime() async {
        let harness = LibraryHarness(LibraryState(games: FixtureGames.all))
        let library = harness.library

        library.launch(FixtureGames.ps2)
        #expect(library.runningGameID == FixtureGames.ps2.id)
        #expect(library.games[1].lastPlayed == Date(timeIntervalSince1970: 1_793_000_000))

        harness.starter.finish(after: 125)
        await harness.settle { library.runningGameID == nil }

        #expect(library.runningGameID == nil)
        #expect(library.games[1].playTime == 125)
        #expect(harness.store.state.games[1].playTime == 125)
    }

    @Test func onlyOneGameRunsAtATime() {
        let harness = LibraryHarness(LibraryState(games: FixtureGames.all))
        harness.library.launch(FixtureGames.crash)
        harness.library.launch(FixtureGames.ps2)

        #expect(harness.starter.started == [FixtureGames.crash])
        #expect(harness.library.lastError == "Another game is already running.")
        harness.library.dismissError()
        #expect(harness.library.lastError == nil)
    }

    @Test func aFailedLaunchIsShownAndNothingRuns() {
        struct NotSetUp: LocalizedError { var errorDescription: String? { "PCSX2 isn’t set up yet." } }
        let harness = LibraryHarness(LibraryState(games: FixtureGames.all))
        harness.starter.failure = NotSetUp()

        harness.library.launch(FixtureGames.ps2)

        #expect(harness.library.runningGameID == nil)
        #expect(harness.library.lastError == "PCSX2 isn’t set up yet.")
        #expect(harness.library.games[1].lastPlayed == nil)
    }

    @Test func aFailedSaveIsShown() {
        let harness = LibraryHarness()
        harness.store.failsToSave = true
        harness.library.updateSettings { $0.launchOptions.fullscreen = false }
        #expect(harness.library.lastError == "Couldn’t save the library: The disk is full.")
    }

    @Test func filtersSearchAndCounts() {
        var recent = FixtureGames.demonsSouls
        recent.lastPlayed = Date(timeIntervalSince1970: 2_000)
        var older = FixtureGames.crash
        older.lastPlayed = Date(timeIntervalSince1970: 1_000)
        let harness = LibraryHarness(LibraryState(games: [older, FixtureGames.ps2, recent]))
        let library = harness.library

        #expect(library.games(for: .all, matching: "").count == 3)
        #expect(library.games(for: .recent, matching: "").map(\.title) == ["Demon's Souls", "Crash Bandicoot"])
        #expect(library.games(for: .platform(.ps2), matching: "").map(\.title) == ["game"])
        #expect(library.games(for: .all, matching: " blus30443 ").map(\.title) == ["Demon's Souls"])
        #expect(library.games(for: .all, matching: "crash").map(\.title) == ["Crash Bandicoot"])
        #expect(library.count(of: .ps1) == 1)
    }

    @Test func theRPCS3FolderDefaultsUntilOneIsSet() {
        let harness = LibraryHarness()
        #expect(harness.library.rpcs3GameFolder == LibraryHarness.defaultRPCS3GameFolder)
        let custom = URL(fileURLWithPath: "/Custom/game")
        harness.library.updateSettings { $0.rpcs3GameFolder = custom }
        #expect(harness.library.rpcs3GameFolder == custom)
    }

    @Test func playHistoryMergesByID() {
        var old = FixtureGames.crash
        old.playTime = 60
        let merged = PlayHistory.merge(scanned: [FixtureGames.crash], previous: [old, old])
        #expect(merged.map(\.playTime) == [60])
    }
}
