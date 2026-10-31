import BusinessScanning
import DataCatalog
import Foundation
import SupportDiscFixtures
import SupportSandbox
import Testing

@Suite struct LibraryScannerTests {
    @Test func foldsACueAndItsBinIntoOneGame() throws {
        let sandbox = try Sandbox()
        try sandbox.write(
            makeISO(files: ["SYSTEM.CNF": Array("BOOT = cdrom:\\SCUS_949.00;1\n".utf8)], raw: true),
            to: "Crash Bandicoot (USA).bin"
        )
        try sandbox.write(
            "FILE \"Crash Bandicoot (USA).bin\" BINARY\n  TRACK 01 MODE2/2352\n    INDEX 01 00:00:00\n",
            to: "Crash Bandicoot (USA).cue"
        )

        let games = LibraryScanner().scan(folder: sandbox.root, hint: nil)
        #expect(games.count == 1)
        #expect(games.first?.title == "Crash Bandicoot")
        #expect(games.first?.platform == .ps1)
        #expect(games.first?.serial == "SCUS-94900")
        #expect(games.first?.location.pathExtension == "cue")
    }

    @Test func foldsAMultiDiscSetIntoItsPlaylist() throws {
        let sandbox = try Sandbox()
        let disc = makeISO(files: ["SYSTEM.CNF": Array("BOOT = cdrom:\\SLUS_005.94;1\n".utf8)], raw: true)
        try sandbox.write(disc, to: "Set/Game (Disc 1).bin")
        try sandbox.write(disc, to: "Set/Game (Disc 2).bin")
        try sandbox.write("FILE \"Game (Disc 1).bin\" BINARY\n", to: "Set/Game (Disc 1).cue")
        try sandbox.write("FILE \"Game (Disc 2).bin\" BINARY\n", to: "Set/Game (Disc 2).cue")
        try sandbox.write("Game (Disc 1).cue\nGame (Disc 2).cue\n", to: "Set/Game.m3u")

        let games = LibraryScanner().scan(folder: sandbox.root, hint: nil)
        #expect(games.map(\.location.lastPathComponent) == ["Game.m3u"])
        #expect(games.first?.serial == "SLUS-00594")
    }

    @Test func findsAPS3DiscFolder() throws {
        let sandbox = try Sandbox()
        try sandbox.write(
            Data(makeSFO([("CATEGORY", "DG"), ("TITLE", "Demon's Souls"), ("TITLE_ID", "BLUS30443")])),
            to: "BLUS30443/PS3_GAME/PARAM.SFO"
        )

        let games = LibraryScanner().scan(folder: sandbox.root, hint: nil)
        #expect(games.map(\.title) == ["Demon's Souls"])
        #expect(games.first?.platform == .ps3)
        guard case .path(let folder)? = games.first?.bootTarget else {
            Issue.record("expected a path boot target")
            return
        }
        #expect(folder.resolvingSymlinksInPath().path == sandbox.url("BLUS30443").resolvingSymlinksInPath().path)
    }

    @Test func aGameInTwoFoldersAppearsOnce() throws {
        let sandbox = try Sandbox()
        try sandbox.write(makeISO(files: ["SYSTEM.CNF": Array("BOOT2 = cdrom0:\\SLUS_200.62;1\n".utf8)]), to: "PS2/a.iso")
        let folder = LibraryFolder(url: sandbox.url("PS2"))
        #expect(LibraryScanner().scan(folders: [folder, folder]).count == 1)
    }

    @Test func installedRPCS3TitlesSkipPatchesAndDLC() throws {
        let sandbox = try Sandbox()
        try sandbox.write(Data(makeSFO([("CATEGORY", "HG"), ("TITLE", "Flower"), ("TITLE_ID", "NPUA80083")])),
                          to: "game/NPUA80083/PARAM.SFO")
        try sandbox.write(Data(makeSFO([("CATEGORY", "GD"), ("TITLE", "Patch"), ("TITLE_ID", "BLUS30443")])),
                          to: "game/BLUS30443/PARAM.SFO")

        let games = LibraryScanner().scanRPCS3Installed(gameFolder: sandbox.url("game"))
        #expect(games.map(\.title) == ["Flower"])
        #expect(games.first?.bootTarget == .rpcs3TitleID("NPUA80083"))
    }
}
