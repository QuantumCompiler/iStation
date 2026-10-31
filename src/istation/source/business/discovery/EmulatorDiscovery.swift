import DataEmulators
import Foundation
import InfrastructureBundles
import InfrastructureLocations

/// Finds the emulator apps already installed on this Mac.
public struct EmulatorDiscovery: Sendable {
    private let applicationFolders: [URL]
    private let lookup: any AppLookup

    public init(locations: Locations, lookup: any AppLookup) {
        applicationFolders = locations.applications
        self.lookup = lookup
    }

    /// The emulator's app in /Applications or ~/Applications by its usual name, else wherever
    /// Launch Services knows it by bundle identifier.
    public func installedApp(for kind: EmulatorKind) -> URL? {
        AppBundles.firstApp(named: kind.commonAppNames, in: applicationFolders)
            ?? lookup.installedApp(bundleIdentifier: kind.bundleIdentifier)
    }
}
