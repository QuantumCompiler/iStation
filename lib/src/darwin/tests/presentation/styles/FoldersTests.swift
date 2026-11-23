// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import PresentationStyles
import Testing

/// A folder under the person's home is written from "~", as the design writes "~/Documents/Console";
/// any other as it is.
@Suite struct FoldersTests {
    @Test func aFolderUnderHomeIsWrittenFromTheTilde() {
        #expect(Folders.shown("/Users/you/Documents/Console", home: "/Users/you") == "~/Documents/Console")
        #expect(Folders.shown("/Users/you", home: "/Users/you") == "~")
        #expect(Folders.shown("/Users/you/Games", home: "/Users/you/") == "~/Games", "a home written with its slash")
    }

    @Test func anyOtherFolderIsWrittenAsItIs() {
        #expect(Folders.shown("/Users/younger/Games", home: "/Users/you") == "/Users/younger/Games", "a folder beside home isn't in it")
        #expect(Folders.shown("/Volumes/Archive/Console", home: "/Users/you") == "/Volumes/Archive/Console")
        #expect(Folders.shown("/Users/you/Games", home: nil) == "/Users/you/Games")
        #expect(Folders.shown("/Users/you/Games", home: "") == "/Users/you/Games")
    }
}
