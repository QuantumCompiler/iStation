// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import DataLibrary
import Foundation

/// Where the BIOS check and the BIOS pane reach files: the file the person picked, read where they keep
/// it through its bookmark, and the record the library keeps of it. The app hands in
/// `LibraryBIOSStorage`, over the library's `library.json` and `KeptFile`; previews and tests hand in
/// one held in memory, so no view-model test touches a file. Every call is synchronous, as the store's
/// and the kept file's are: the view-models choose where each runs, the file's bytes off the main actor.
public protocol BIOSStorage: Sendable {
    /// The BIOS the library keeps; nil for none.
    func keptBIOS() throws -> BIOSRecord?

    /// Keeps `record` as the library's BIOS, in place of the one before.
    func keep(_ record: BIOSRecord) throws

    /// A bookmark to the file at `url`, to keep it by (`KeptFile.bookmark(for:)`).
    func bookmark(for url: URL) throws -> Data

    /// Where `bookmark` leads now, and whether it should be made again (`KeptFile.resolve(_:)`).
    func resolve(_ bookmark: Data) throws -> KeptFile.Resolved

    /// The size in bytes of the file at `url`, without reading it (`KeptFile.size(at:)`).
    func size(of url: URL) throws -> Int

    /// The bytes of the file at `url` (`KeptFile.bytes(at:)`).
    func bytes(of url: URL) throws -> [UInt8]
}

/// The BIOS kept in the app's library: the record in `library.json` through `LibraryStore`, and the
/// file itself through `KeptFile`, by its bookmark and inside its security-scoped access. The app builds
/// it over the store at its own container's `library.json`.
public struct LibraryBIOSStorage: BIOSStorage {
    /// The library the record is kept in.
    public let store: LibraryStore

    /// Storage keeping the BIOS's record in `store`.
    public init(store: LibraryStore) {
        self.store = store
    }

    /// The BIOS `library.json` keeps; nil for none, or before the file exists.
    public func keptBIOS() throws -> BIOSRecord? {
        try store.load().bios
    }

    /// Keeps `record` in `library.json`, replacing the BIOS kept before.
    public func keep(_ record: BIOSRecord) throws {
        try store.keepBIOS(record)
    }

    /// A bookmark to the file at `url`.
    public func bookmark(for url: URL) throws -> Data {
        try KeptFile.bookmark(for: url)
    }

    /// Where `bookmark` leads now.
    public func resolve(_ bookmark: Data) throws -> KeptFile.Resolved {
        try KeptFile.resolve(bookmark)
    }

    /// The size of the file at `url`, without reading it.
    public func size(of url: URL) throws -> Int {
        try KeptFile.size(at: url)
    }

    /// The bytes of the file at `url`.
    public func bytes(of url: URL) throws -> [UInt8] {
        try KeptFile.bytes(at: url)
    }
}
