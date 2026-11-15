// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import DataPlaylists
import Foundation
import SupportSandbox
import Testing

@Suite struct PlaylistsTests {
    @Test func cueTracksReadQuotedAndUnquotedFiles() throws {
        let sandbox = try Sandbox()
        let cue = try sandbox.write(
            "FILE \"Track (1).bin\" BINARY\n  TRACK 01 MODE2/2352\nFILE track2.bin BINARY\n",
            to: "Game/game.cue"
        )
        #expect(Playlists.cueTracks(cue).map(\.lastPathComponent) == ["Track (1).bin", "track2.bin"])
        #expect(Playlists.cueTracks(cue).allSatisfy { $0.deletingLastPathComponent().lastPathComponent == "Game" })
    }

    @Test func m3uEntriesSkipCommentsAndBlankLines() throws {
        let sandbox = try Sandbox()
        let m3u = try sandbox.write("#EXTM3U\nDisc 1.cue\n\n/abs/Disc 2.cue\n", to: "Set/set.m3u")
        let entries = Playlists.m3uEntries(m3u)
        #expect(entries.map(\.lastPathComponent) == ["Disc 1.cue", "Disc 2.cue"])
        #expect(entries[1].path == "/abs/Disc 2.cue")
    }

    @Test func anUnreadablePlaylistHasNoEntries() {
        let missing = URL(fileURLWithPath: "/nonexistent/iStation/none.cue")
        #expect(Playlists.cueTracks(missing).isEmpty)
        #expect(Playlists.m3uEntries(missing).isEmpty)
    }
}
