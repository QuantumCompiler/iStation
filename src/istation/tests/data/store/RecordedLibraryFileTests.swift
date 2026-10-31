import DataCatalog
import DataEmulators
import DataStore
import Foundation
import SupportSandbox
import Testing

/// ADR 0007's guardrail: a library file written by an earlier release must keep loading, unchanged
/// in meaning. Add a new `library-v<x.y.z>` recording here whenever the file's shape changes; never
/// edit or delete an old one.
@Suite struct RecordedLibraryFileTests {
    @Test func v0_0_1() throws {
        let sandbox = try Sandbox()
        let file = try sandbox.write(Self.v0_0_1, to: "library.json")
        let state = LibraryStore(fileURL: file).load()

        #expect(state.folders.map(\.url.path) == ["/Games/PS1", "/Games/PS2"])
        #expect(state.folders.map(\.platformHint) == [.ps1, nil])
        #expect(state.games.map(\.title) == ["Crash Bandicoot", "game", "Flower"])
        #expect(state.games.map(\.id) == ["ps1:/Games/PS1/Crash Bandicoot (USA).cue", "ps2:/Games/PS2/game.iso", "ps3:id:NPUA80083"])
        #expect(state.games.map(\.playTime) == [11_100, 0, 1_800])
        #expect(state.games[0].lastPlayed == Date(timeIntervalSince1970: 1_793_000_000))
        #expect(state.games[2].bootTarget == .rpcs3TitleID("NPUA80083"))
        #expect(state.settings.app(for: .pcsx2)?.path == "/Applications/PCSX2.app")
        #expect(state.settings.app(for: .duckstation) == nil)
        #expect(state.settings.launchOptions == LaunchOptions(fullscreen: true, fastBoot: false))
        #expect(state.settings.includeRPCS3InstalledGames)
        #expect(state.settings.rpcs3GameFolder == nil)
    }

    /// Recorded 2026-10-31 from LibraryStore.save at v0.0.1, byte for byte.
    static let v0_0_1 = #"""
{
  "folders" : [
    {
      "id" : "6F9619FF-8B86-D011-B42D-00C04FC964FF",
      "platformHint" : "ps1",
      "url" : "file:\/\/\/Games\/PS1"
    },
    {
      "id" : "0E984725-C51C-4BF4-9960-E1C80E27ABA0",
      "url" : "file:\/\/\/Games\/PS2"
    }
  ],
  "games" : [
    {
      "bootTarget" : {
        "path" : {
          "_0" : "file:\/\/\/Games\/PS1\/Crash%20Bandicoot%20(USA).cue"
        }
      },
      "id" : "ps1:\/Games\/PS1\/Crash Bandicoot (USA).cue",
      "lastPlayed" : "2026-10-26T07:33:20Z",
      "location" : "file:\/\/\/Games\/PS1\/Crash%20Bandicoot%20(USA).cue",
      "platform" : "ps1",
      "playTime" : 11100,
      "serial" : "SCUS-94900",
      "title" : "Crash Bandicoot"
    },
    {
      "bootTarget" : {
        "path" : {
          "_0" : "file:\/\/\/Games\/PS2\/game.iso"
        }
      },
      "id" : "ps2:\/Games\/PS2\/game.iso",
      "location" : "file:\/\/\/Games\/PS2\/game.iso",
      "platform" : "ps2",
      "playTime" : 0,
      "serial" : "SLES-52338",
      "title" : "game"
    },
    {
      "bootTarget" : {
        "rpcs3TitleID" : {
          "_0" : "NPUA80083"
        }
      },
      "id" : "ps3:id:NPUA80083",
      "location" : "file:\/\/\/Users\/me\/Library\/Application%20Support\/rpcs3\/dev_hdd0\/game\/NPUA80083",
      "platform" : "ps3",
      "playTime" : 1800,
      "serial" : "NPUA80083",
      "title" : "Flower"
    }
  ],
  "settings" : {
    "emulatorApps" : {
      "pcsx2" : "file:\/\/\/Applications\/PCSX2.app\/",
      "rpcs3" : "file:\/\/\/Applications\/RPCS3.app\/"
    },
    "includeRPCS3InstalledGames" : true,
    "launchOptions" : {
      "fastBoot" : false,
      "fullscreen" : true
    }
  }
}
"""#
}
