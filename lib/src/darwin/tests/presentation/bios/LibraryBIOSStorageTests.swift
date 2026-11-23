// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import DataLibrary
import Foundation
import PresentationBIOS
import SupportSandbox
import Testing

/// The storage the app hands the view-models, over the real library and kept file, inside a `Sandbox`:
/// a kept BIOS is in `library.json` and found again by its bookmark.
@Suite struct LibraryBIOSStorageTests {
    @Test func aKeptBIOSIsInTheLibraryAndItsFileIsFoundByItsBookmark() throws {
        let sandbox = try Sandbox()
        let file = try sandbox.write(Data(biosImage), to: "Console/my-console-bios.bin")
        let library = sandbox.url("Container/library.json")
        let storage = LibraryBIOSStorage(store: LibraryStore(url: library))
        #expect(try storage.keptBIOS() == nil)
        #expect(!FileManager.default.fileExists(atPath: library.path), "reading an empty library writes nothing")

        #expect(try storage.size(of: file) == 524_288)
        let bookmark = try storage.bookmark(for: file)
        let record = BIOSRecord(
            fileName: file.lastPathComponent, folder: file.deletingLastPathComponent().path, size: 524_288,
            sha1: Fingerprint.sha1(of: biosImage), checked: Date(timeIntervalSinceReferenceDate: 816_000_000), bookmark: bookmark
        )
        try storage.keep(record)
        #expect(try storage.keptBIOS() == record)
        #expect(try LibraryStore(url: library).load().bios == record, "kept in library.json itself")

        let resolved = try storage.resolve(bookmark)
        #expect(resolved.url.resolvingSymlinksInPath().path == file.resolvingSymlinksInPath().path)
        #expect(try storage.bytes(of: resolved.url) == biosImage)
    }

    @Test func keepingAnotherBIOSReplacesTheOneBefore() throws {
        let sandbox = try Sandbox()
        let storage = LibraryBIOSStorage(store: LibraryStore(url: sandbox.url("library.json")))
        let first = BIOSRecord(fileName: "my-console-bios.bin", folder: "/a", size: 524_288, sha1: "", checked: .distantPast, bookmark: Data([1]))
        let second = BIOSRecord(fileName: "bios-copy.bin", folder: "/b", size: 524_288, sha1: "", checked: .distantPast, bookmark: Data([2]))
        try storage.keep(first)
        try storage.keep(second)
        #expect(try storage.keptBIOS() == second)
    }
}
