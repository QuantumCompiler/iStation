import DataCatalog
import DataEmulators
import DataStore
import Foundation
import SupportSandbox
import Testing

@Suite struct LibraryStoreTests {
    @Test func savesAndLoadsTheWholeState() throws {
        let sandbox = try Sandbox()
        let store = LibraryStore(fileURL: LibraryStore.file(inApplicationSupport: sandbox.url("Library/Application Support")))
        var state = LibraryState()
        let url = URL(fileURLWithPath: "/Games/PS2/a.iso")
        state.folders = [LibraryFolder(url: URL(fileURLWithPath: "/Games/PS2"), platformHint: .ps2)]
        state.games = [Game(title: "A", serial: "SLUS-20062", platform: .ps2, location: url, bootTarget: .path(url),
                            lastPlayed: Date(timeIntervalSince1970: 1_793_000_000), playTime: 120)]
        state.settings.setApp(URL(fileURLWithPath: "/Applications/PCSX2.app"), for: .pcsx2)
        state.settings.launchOptions.fastBoot = false

        try store.save(state)
        #expect(store.fileURL.path.hasSuffix("Library/Application Support/iStation/library.json"))
        #expect(store.load() == state)
    }

    @Test func noFileLoadsAnEmptyLibrary() throws {
        let sandbox = try Sandbox()
        #expect(LibraryStore(fileURL: sandbox.url("missing.json")).load() == LibraryState())
    }

    @Test func aFileWrittenBeforeSettingsExistedStillLoads() throws {
        let sandbox = try Sandbox()
        let file = try sandbox.write(#"{ "folders": [ { "id": "6F9619FF-8B86-D011-B42D-00C04FC964FF", "url": "file:///Games/" } ] }"#, to: "old.json")
        let state = LibraryStore(fileURL: file).load()
        #expect(state.folders.map(\.url.path) == ["/Games"])
        #expect(state.folders.first?.platformHint == nil)
        #expect(state.games.isEmpty)
        #expect(state.settings == AppSettings())
    }

    @Test func missingSettingsFieldsTakeTheirDefaults() throws {
        let sandbox = try Sandbox()
        let file = try sandbox.write(#"{ "settings": { "launchOptions": { "fullscreen": false } } }"#, to: "partial.json")
        let settings = LibraryStore(fileURL: file).load().settings
        #expect(settings.launchOptions == LaunchOptions(fullscreen: false, fastBoot: true))
        #expect(settings.includeRPCS3InstalledGames)
        #expect(settings.rpcs3GameFolder == nil)
        #expect(settings.emulatorApps.isEmpty)
    }
}
