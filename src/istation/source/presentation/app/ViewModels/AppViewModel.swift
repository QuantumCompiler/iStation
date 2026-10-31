import BusinessDiscovery
import BusinessLaunching
import BusinessLibrary
import BusinessScanning
import DataEmulators
import DataStore
import Foundation
import InfrastructureBundles
import InfrastructureLocations
import InfrastructureProcess
import Observation
import PresentationLibrary
import PresentationSettings
import PresentationShell

/// The composition root: builds the real services over one set of folders, the `Library` on top of
/// them, and every place's view-model. The only module that knows the concrete implementations.
@MainActor
@Observable
public final class AppViewModel {
    public let shell: ShellViewModel
    public let grid: LibraryGridViewModel
    public let settings: SettingsViewModel

    private let library: Library

    public init(
        locations: Locations,
        runner: any ProcessRunning = ProcessRunner(),
        lookup: any AppLookup = LaunchServicesLookup()
    ) {
        let library = Library(
            store: LibraryStore(fileURL: LibraryStore.file(inApplicationSupport: locations.applicationSupport)),
            scanner: LibraryScanner(),
            launcher: GameLauncher(runner: runner),
            detector: EmulatorDiscovery(locations: locations, lookup: lookup),
            defaultRPCS3GameFolder: RPCS3Layout.installedGamesFolder(applicationSupport: locations.applicationSupport)
        )
        let shell = ShellViewModel(library: library)
        self.library = library
        self.shell = shell
        grid = LibraryGridViewModel(
            library: library,
            query: { (shell.filter, shell.search) },
            requestFolders: { shell.chooseFolders() }
        )
        settings = SettingsViewModel(library: library)
    }

    /// True while a game's emulator is running.
    public var isPlaying: Bool { library.runningGameID != nil }
}
