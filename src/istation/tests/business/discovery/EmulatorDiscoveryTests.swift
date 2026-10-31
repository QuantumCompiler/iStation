import BusinessDiscovery
import DataEmulators
import Foundation
import InfrastructureBundles
import InfrastructureLocations
import SupportSandbox
import Testing

private struct TableLookup: AppLookup {
    var apps: [String: URL] = [:]
    func installedApp(bundleIdentifier: String) -> URL? { apps[bundleIdentifier] }
}

@Suite struct EmulatorDiscoveryTests {
    @Test func findsAnAppByItsUsualNameFirst() throws {
        let sandbox = try Sandbox()
        let app = try sandbox.makeApp("Applications/PCSX2.app", binary: "PCSX2")
        let elsewhere = URL(fileURLWithPath: "/Elsewhere/PCSX2.app")
        let discovery = EmulatorDiscovery(
            locations: .sandbox(root: sandbox.root),
            lookup: TableLookup(apps: ["net.pcsx2.pcsx2": elsewhere])
        )
        #expect(discovery.installedApp(for: .pcsx2)?.path == app.path)
    }

    @Test func fallsBackToTheBundleIdentifier() throws {
        let sandbox = try Sandbox()
        let elsewhere = URL(fileURLWithPath: "/Elsewhere/RPCS3.app")
        let discovery = EmulatorDiscovery(
            locations: .sandbox(root: sandbox.root),
            lookup: TableLookup(apps: ["net.rpcs3.rpcs3": elsewhere])
        )
        #expect(discovery.installedApp(for: .rpcs3) == elsewhere)
        #expect(discovery.installedApp(for: .duckstation) == nil)
    }
}
