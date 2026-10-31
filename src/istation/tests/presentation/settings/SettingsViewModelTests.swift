import BusinessLibrary
import DataCatalog
import DataEmulators
import DataStore
import Foundation
import PresentationSettings
import SupportLibraryFakes
import Testing

@MainActor
@Suite struct SettingsViewModelTests {
    @Test func emulatorRowsNameTheConsoleAndTheChosenApp() {
        let harness = LibraryHarness(installed: [.pcsx2: URL(fileURLWithPath: "/Applications/PCSX2.app")])
        let settings = SettingsViewModel(library: harness.library)

        #expect(settings.emulators.map(\.title) == ["DuckStation (PS1)", "PCSX2 (PS2)", "RPCS3 (PS3)"])
        #expect(settings.emulators.map(\.appPath) == [nil, "/Applications/PCSX2.app", nil])
    }

    @Test func choosingAnAppSetsItForThatEmulator() {
        let harness = LibraryHarness()
        let settings = SettingsViewModel(library: harness.library)

        settings.chooseApp(for: .rpcs3)
        #expect(settings.isChoosingApp)
        settings.isChoosingApp = false // the chooser closes before its result arrives
        settings.useApp(URL(fileURLWithPath: "/Apps/RPCS3.app"))

        #expect(harness.library.settings.app(for: .rpcs3)?.path == "/Apps/RPCS3.app")
        #expect(harness.store.state.settings.app(for: .rpcs3)?.path == "/Apps/RPCS3.app")
    }

    @Test func togglesAreSaved() {
        let harness = LibraryHarness()
        let settings = SettingsViewModel(library: harness.library)

        settings.startsFullscreen = false
        settings.skipsBIOSIntro = false
        settings.includesRPCS3InstalledGames = false

        #expect(harness.store.state.settings.launchOptions == LaunchOptions(fullscreen: false, fastBoot: false))
        #expect(!harness.store.state.settings.includeRPCS3InstalledGames)
        #expect(!settings.startsFullscreen)
    }

    @Test func foldersCanBeHintedAndRemoved() async {
        let folder = LibraryFolder(url: URL(fileURLWithPath: "/Games"))
        let harness = LibraryHarness(LibraryState(folders: [folder]))
        let settings = SettingsViewModel(library: harness.library)

        settings.setPlatformHint(.ps2, for: folder)
        #expect(settings.folders.first?.platformHint == .ps2)

        await settings.removeFolder(folder)
        #expect(settings.folders.isEmpty)
    }

    @Test func showsRPCS3sDefaultFolder() {
        let settings = SettingsViewModel(library: LibraryHarness().library)
        #expect(settings.rpcs3GameFolderPath == LibraryHarness.defaultRPCS3GameFolder.path)
    }
}
