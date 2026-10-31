import Foundation
import InfrastructureBundles
import SupportSandbox
import Testing

@Suite struct AppBundlesTests {
    @Test func findsTheBinaryInsideAnAppBundle() throws {
        let sandbox = try Sandbox()
        let app = try sandbox.makeApp("Applications/PCSX2.app", binary: "PCSX2")
        let executable = try #require(AppBundles.executable(inAppBundle: app))
        #expect(executable.lastPathComponent == "PCSX2")
    }

    @Test func noBinaryMeansNoExecutable() throws {
        let sandbox = try Sandbox()
        let app = try sandbox.makeFolder("Applications/Empty.app")
        #expect(AppBundles.executable(inAppBundle: app) == nil)
    }

    @Test func firstAppTriesFoldersInOrderThenNames() throws {
        let sandbox = try Sandbox()
        try sandbox.makeApp("Second/rpcs3.app", binary: "rpcs3")
        try sandbox.makeApp("Second/RPCS3.app", binary: "rpcs3")
        let folders = [sandbox.url("First"), sandbox.url("Second")]

        let found = AppBundles.firstApp(named: ["RPCS3.app", "rpcs3.app"], in: folders)
        #expect(found?.lastPathComponent == "RPCS3.app")
        #expect(AppBundles.firstApp(named: ["DuckStation.app"], in: folders) == nil)
    }
}
