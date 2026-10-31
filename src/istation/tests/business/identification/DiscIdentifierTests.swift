import BusinessIdentification
import DataCatalog
import Foundation
import SupportDiscFixtures
import SupportSandbox
import Testing

@Suite struct DiscIdentifierTests {
    @Test func identifiesAPS2ISOBySystemCNF() throws {
        let sandbox = try Sandbox()
        let url = try sandbox.write(makeISO(files: ["SYSTEM.CNF": Array("BOOT2 = cdrom0:\\SLES_523.38;1\n".utf8)]), to: "game.iso")
        #expect(DiscIdentifier.identify(image: url) == DiscInfo(platform: .ps2, serial: "SLES-52338"))
    }

    @Test func identifiesARawPS1Bin() throws {
        let sandbox = try Sandbox()
        let url = try sandbox.write(
            makeISO(files: ["SYSTEM.CNF": Array("BOOT = cdrom:\\SLUS_005.94;1\n".utf8)], raw: true), to: "game.bin"
        )
        #expect(DiscIdentifier.identify(image: url) == DiscInfo(platform: .ps1, serial: "SLUS-00594"))
    }

    @Test func anEarlyPS1DiscBootsPSXEXE() throws {
        let sandbox = try Sandbox()
        let url = try sandbox.write(makeISO(files: ["PSX.EXE": [0x50, 0x53]]), to: "early.iso")
        #expect(DiscIdentifier.identify(image: url) == DiscInfo(platform: .ps1))
    }

    @Test func aPS3DiscFolderUsesItsParamSFO() throws {
        let sandbox = try Sandbox()
        try sandbox.write(
            Data(makeSFO([("CATEGORY", "DG"), ("TITLE", "Demon's Souls"), ("TITLE_ID", "BLUS30443")])),
            to: "BLUS30443/PS3_GAME/PARAM.SFO"
        )
        let info = DiscIdentifier.identify(ps3DiscFolder: sandbox.url("BLUS30443"))
        #expect(info == DiscInfo(platform: .ps3, serial: "BLUS30443", title: "Demon's Souls"))
    }

    @Test func theDiscBeatsTheFolderHint() throws {
        let sandbox = try Sandbox()
        let url = try sandbox.write(makeISO(files: ["SYSTEM.CNF": Array("BOOT2 = cdrom0:\\SLUS_200.62;1\n".utf8)]), to: "PS1/a.iso")
        #expect(DiscIdentifier.identify(file: url, hint: .ps1)?.platform == .ps2)
    }

    @Test func unreadableImagesFallBackToTheHintThenTheExtension() throws {
        let sandbox = try Sandbox()
        let chd = try sandbox.write(Data([0x4D]), to: "small.chd")
        #expect(DiscIdentifier.identify(file: chd, hint: .ps2)?.platform == .ps2)
        #expect(DiscIdentifier.identify(file: chd, hint: nil)?.platform == .ps1) // under 800 MB
        #expect(DiscIdentifier.identify(file: sandbox.url("a.cso"), hint: nil)?.platform == .ps2)
        #expect(DiscIdentifier.identify(file: sandbox.url("EBOOT.pbp"), hint: nil)?.platform == .ps1)
        let blank = try sandbox.write(Data(count: 40_000), to: "blank.iso")
        #expect(DiscIdentifier.identify(file: blank, hint: nil) == nil)
    }

    @Test func folderNamesHintTheirConsole() {
        #expect(DiscIdentifier.platformHint(fromPath: URL(fileURLWithPath: "/Games/PSX/a.cue")) == .ps1)
        #expect(DiscIdentifier.platformHint(fromPath: URL(fileURLWithPath: "/Games/ps2/a.iso")) == .ps2)
        #expect(DiscIdentifier.platformHint(fromPath: URL(fileURLWithPath: "/Games/RPCS3/x")) == .ps3)
        #expect(DiscIdentifier.platformHint(fromPath: URL(fileURLWithPath: "/Games/misc/a.iso")) == nil)
    }

    @Test func titlesComeFromCleanedFileNames() {
        #expect(TitleCleaner.clean("Final Fantasy VII (USA) (Disc 1) [!].cue") == "Final Fantasy VII")
        #expect(TitleCleaner.clean("ico_ntsc.iso") == "ico ntsc")
        #expect(TitleCleaner.clean("(USA).iso") == "(USA)")
    }
}
