// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import DataISO9660
import Foundation
import SupportDiscFixtures
import SupportSandbox
import Testing

@Suite struct ISO9660Tests {
    @Test(arguments: [false, true])
    func findsAndReadsAFileInCookedAndRawImages(raw: Bool) throws {
        let sandbox = try Sandbox()
        let content = Array("BOOT2 = cdrom0:\\SLES_523.38;1\n".utf8)
        let url = try sandbox.write(makeISO(files: ["SYSTEM.CNF": content], raw: raw), to: raw ? "game.bin" : "game.iso")

        let iso = try ISO9660(url: url)
        defer { iso.close() }
        let entry = try #require(try iso.find("system.cnf"))
        #expect(!entry.isDirectory)
        #expect(try iso.read(entry) == content)
        #expect(try iso.find("PS3_GAME/PARAM.SFO") == nil)
    }

    @Test func rejectsAFileThatIsNotISO9660() throws {
        let sandbox = try Sandbox()
        let url = try sandbox.write(Data(repeating: 0x41, count: 40_000), to: "junk.iso")
        #expect(throws: DiscError.self) { try ISO9660(url: url) }
    }
}
