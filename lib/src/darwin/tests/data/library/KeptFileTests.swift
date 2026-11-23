// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import DataLibrary
import Foundation
import SupportSandbox
import Testing

/// A file kept by a bookmark, inside a `Sandbox`: bookmarked, found again — after a rename too, and from
/// a plain bookmark — and read, and a deleted file or a damaged bookmark refused. The tests run
/// unsandboxed, where macOS makes a security-scoped bookmark; whether the App Store sandbox does, and
/// whether it opens after a relaunch, is the bookmark probe's question.
@Suite struct KeptFileTests {
    /// 512 KB of made-up bytes, built in code: never a real BIOS.
    static let image = (0..<524_288).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ 7) }

    /// The same file, however the system spells its path (the temporary folder sits behind a symbolic link).
    func samePath(_ one: URL, _ other: URL) -> Bool {
        one.resolvingSymlinksInPath().standardizedFileURL.path == other.resolvingSymlinksInPath().standardizedFileURL.path
    }

    @Test func aBookmarkFindsTheFileAgainAndItsBytesRead() throws {
        let sandbox = try Sandbox()
        let url = try sandbox.write(Data(Self.image), to: "Console/my-console-bios.bin")
        let bookmark = try KeptFile.bookmark(for: url)
        #expect(!bookmark.isEmpty)
        let resolved = try KeptFile.resolve(bookmark)
        #expect(samePath(resolved.url, url))
        #expect(!resolved.isStale)
        #expect(try KeptFile.size(at: resolved.url) == 524_288)
        #expect(try KeptFile.bytes(at: resolved.url) == Self.image)
    }

    @Test func aBookmarkFollowsTheFileWhenItIsRenamed() throws {
        let sandbox = try Sandbox()
        let url = try sandbox.write(Data(Self.image), to: "Console/my-console-bios.bin")
        let bookmark = try KeptFile.bookmark(for: url)
        let renamed = sandbox.url("Console/bios-backup.bin")
        try FileManager.default.moveItem(at: url, to: renamed)
        let resolved = try KeptFile.resolve(bookmark)
        #expect(samePath(resolved.url, renamed))
        #expect(try KeptFile.bytes(at: resolved.url) == Self.image)
        // A bookmark made again where the file is now finds it there.
        let again = try KeptFile.resolve(try KeptFile.bookmark(for: resolved.url))
        #expect(samePath(again.url, renamed))
        #expect(!again.isStale)
    }

    @Test func aPlainBookmarkIsFoundToo() throws {
        // What `bookmark(for:)` falls back to where the sandbox refuses a security-scoped one; resolving it
        // with the security scope fails (measured 2026-11-22), so `resolve` tries it plainly.
        let sandbox = try Sandbox()
        let url = try sandbox.write(Data(Self.image), to: "bios-backup.bin")
        let plain = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        let resolved = try KeptFile.resolve(plain)
        #expect(samePath(resolved.url, url))
        #expect(try KeptFile.bytes(at: resolved.url) == Self.image)
    }

    @Test func aBookmarkToADeletedFileIsRefused() throws {
        let sandbox = try Sandbox()
        let url = try sandbox.write(Data(Self.image), to: "my-console-bios.bin")
        let bookmark = try KeptFile.bookmark(for: url)
        try FileManager.default.removeItem(at: url)
        let error = #expect(throws: KeptFileError.self) { try KeptFile.resolve(bookmark) }
        guard case .cannotResolve? = error else {
            Issue.record("\(String(describing: error)) is not cannotResolve")
            return
        }
    }

    @Test func aDamagedBookmarkIsRefused() {
        let error = #expect(throws: KeptFileError.self) { try KeptFile.resolve(Data("not a bookmark".utf8)) }
        guard case .cannotResolve? = error else {
            Issue.record("\(String(describing: error)) is not cannotResolve")
            return
        }
    }

    @Test func noBookmarkIsMadeToAFileThatIsntThere() throws {
        let sandbox = try Sandbox()
        let url = sandbox.url("missing.bin")
        #expect(throws: KeptFileError.self) { try KeptFile.bookmark(for: url) }
    }

    @Test func aFileThatIsntThereCannotBeReadOrSized() throws {
        let sandbox = try Sandbox()
        let url = sandbox.url("missing.bin")
        #expect(throws: KeptFileError.self) { try KeptFile.bytes(at: url) }
        #expect(throws: KeptFileError.self) { try KeptFile.size(at: url) }
        let error = #expect(throws: KeptFileError.self) { try KeptFile.bytes(at: url) }
        guard case .cannotRead(let path, _)? = error else {
            Issue.record("\(String(describing: error)) is not cannotRead")
            return
        }
        #expect(path == url.path)
    }

    @Test func aFileOfAnotherSizeIsSizedWithoutReadingIt() throws {
        let sandbox = try Sandbox()
        let url = try sandbox.write(Data(repeating: 0, count: 1000), to: "bios-backup.bin")
        #expect(try KeptFile.size(at: url) == 1000)
    }

    @Test func aFileReachedThroughALinkIsSizedAsTheFileItLeadsTo() throws {
        let sandbox = try Sandbox()
        let target = try sandbox.write(Data(Self.image), to: "Console/my-console-bios.bin")
        let link = sandbox.url("bios-link.bin")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        #expect(try KeptFile.size(at: link) == 524_288, "the link's own size isn't the file's")
        #expect(try KeptFile.bytes(at: link).count == 524_288)
    }
}
