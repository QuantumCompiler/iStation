import BusinessLibrary
import DataCatalog
import DataStore
import Foundation
import PresentationShell
import SupportLibraryFakes
import Testing

@MainActor
@Suite struct ShellViewModelTests {
    @Test func eachPlaceHasItsTitleAndQuery() {
        let shell = ShellViewModel(library: LibraryHarness().library)
        #expect(shell.title == "All Games")
        #expect(shell.filter == .all)

        shell.route = .recent
        #expect(shell.title == "Recently Played")
        #expect(shell.filter == .recent)

        shell.route = .platform(.ps3)
        #expect(shell.title == "PlayStation 3")
        #expect(shell.filter == .platform(.ps3))

        shell.route = nil
        #expect(shell.filter == .all)
    }

    @Test func countsComeFromTheLibrary() {
        let shell = ShellViewModel(library: LibraryHarness(LibraryState(games: FixtureGames.all)).library)
        #expect(shell.gameCount == 3)
        #expect(shell.gameCount(for: .ps2) == 1)
    }

    @Test func choosingFoldersShowsTheChooserAndAddingThemScans() async {
        let harness = LibraryHarness(scanned: [FixtureGames.crash])
        let shell = ShellViewModel(library: harness.library)

        shell.chooseFolders()
        #expect(shell.isChoosingFolders)

        await shell.addFolders([URL(fileURLWithPath: "/Games/PSX")])
        #expect(harness.library.folders.map(\.platformHint) == [.ps1])
        #expect(shell.gameCount == 1)
        #expect(!shell.isScanning)
    }

    @Test func errorsShowUntilDismissed() {
        let harness = LibraryHarness(LibraryState(games: FixtureGames.all))
        let shell = ShellViewModel(library: harness.library)
        harness.library.launch(FixtureGames.crash)
        harness.library.launch(FixtureGames.ps2)

        #expect(shell.errorMessage == "Another game is already running.")
        shell.dismissError()
        #expect(shell.errorMessage == nil)
    }
}
