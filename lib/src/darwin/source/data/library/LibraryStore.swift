// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import Foundation

/// Why the library couldn't be loaded, changed or saved. Each case carries what the app needs to say so
/// in plain words, and the system's own reason, for Details.
public enum LibraryStoreError: Error, Equatable, Sendable {
    /// The file isn't a library: not JSON, JSON of another shape, or without a library's version.
    case notALibrary(path: String, reason: String)
    /// The library was written by a later iStation, in format `version`, which this one doesn't know:
    /// it is left as it is rather than misread or saved over.
    case newerVersion(Int, path: String)
    /// The file is there but couldn't be read.
    case cannotRead(path: String, reason: String)
    /// The library couldn't be written, or its folder made.
    case cannotWrite(path: String, reason: String)
    /// The library keeps no game with this id — it was removed — so nothing was changed.
    case noSuchGame(UUID)
    /// The file at this standardized path is another game's already: the library keeps one game per
    /// file, so nothing was changed.
    case alreadyKept(path: String)
}

/// Keeps the library — `library.json`, versioned — at the URL the app hands in: in its container, or on
/// the unsandboxed macOS personal build its own Application Support folder. Nothing in the package names
/// that place: tests hand in a URL inside a `Sandbox`. A file not there yet is an empty library; a
/// corrupt, foreign or newer one is a thrown error, never a trap, and is never saved over by `load()`.
/// Saving replaces the file atomically, so a crash mid-save leaves the old library whole. The store holds
/// no state of its own: every call reads or writes the file.
public struct LibraryStore: Sendable {
    /// Where `library.json` is, or will be once saved.
    public let url: URL

    /// A store for the library at `url`; nothing is read or written until it is asked.
    public init(url: URL) {
        self.url = url
    }

    /// The library in the file: an empty one when there is no file yet.
    public func load() throws(LibraryStoreError) -> Library {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return Library()
        } catch {
            throw .cannotRead(path: url.path, reason: error.localizedDescription)
        }
        let library: Library
        do {
            library = try Self.decoder.decode(Library.self, from: data)
        } catch {
            throw .notALibrary(path: url.path, reason: String(describing: error))
        }
        guard library.version >= 1 else {
            throw .notALibrary(path: url.path, reason: "version \(library.version) is not a library's")
        }
        guard library.version <= Library.currentVersion else { throw .newerVersion(library.version, path: url.path) }
        return library
    }

    /// Writes `library` to the file, replacing it atomically, its folder made if it isn't there.
    public func save(_ library: Library) throws(LibraryStoreError) {
        do {
            let data = try Self.encoder.encode(library)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            throw .cannotWrite(path: url.path, reason: error.localizedDescription)
        }
    }

    /// Keeps `record` as the library's BIOS, in place of any kept before, and saves; returns the library saved.
    @discardableResult
    public func keepBIOS(_ record: BIOSRecord) throws(LibraryStoreError) -> Library {
        var library = try load()
        library.bios = record
        return try saved(library)
    }

    /// Forgets the kept BIOS, if any, and saves; returns the library saved. The user's file is left as it is.
    @discardableResult
    public func forgetBIOS() throws(LibraryStoreError) -> Library {
        var library = try load()
        library.bios = nil
        return try saved(library)
    }

    // MARK: - Games

    /// What adding games did: the library as it is now, and the games added — a game whose file the
    /// library kept already is not among them.
    public struct Added: Sendable, Equatable {
        /// The library after the games were added.
        public var library: Library
        /// The games added, in the order given; each one skipped is left out.
        public var added: [GameRecord]

        /// A result of these values.
        public init(library: Library, added: [GameRecord]) {
            self.library = library
            self.added = added
        }
    }

    /// Adds each of `games` whose file the library doesn't keep yet — by its standardized path, so a
    /// folder scanned again adds no game twice — and saves (`Library.add(_:)`). Nothing is written when
    /// every game was kept already.
    @discardableResult
    public func addGames(_ games: [GameRecord]) throws(LibraryStoreError) -> Added {
        var library = try load()
        let added = library.add(games)
        guard !added.isEmpty else { return Added(library: library, added: []) }
        return Added(library: try saved(library), added: added)
    }

    /// Gives game `id` the name `name` in the library — empty or nil for none, so its file's name shows —
    /// and saves (`Library.rename(_:to:)`). Throws `noSuchGame`, writing nothing, when it isn't kept.
    @discardableResult
    public func renameGame(_ id: GameRecord.ID, to name: String?) throws(LibraryStoreError) -> Library {
        var library = try load()
        try library.rename(id, to: name)
        return try saved(library)
    }

    /// Takes the games `ids` names out of the library and saves; their files are left where they are,
    /// and an id the library doesn't keep is passed over. Nothing is written when none was kept.
    @discardableResult
    public func removeGames(_ ids: Set<GameRecord.ID>) throws(LibraryStoreError) -> Library {
        var library = try load()
        guard !library.remove(ids).isEmpty else { return library }
        return try saved(library)
    }

    /// Notes that game `id` was played at `date`, to the whole second, and saves. Throws `noSuchGame`,
    /// writing nothing, when it isn't kept.
    @discardableResult
    public func markPlayed(_ id: GameRecord.ID, at date: Date) throws(LibraryStoreError) -> Library {
        var library = try load()
        try library.markPlayed(id, at: date)
        return try saved(library)
    }

    /// Keeps game `id` by `file`, the record of where its file is now — Locate…, or a bookmark that
    /// resolved stale — its own name and dates kept (`Library.relocate(_:to:)`), and saves. Throws
    /// `noSuchGame` when it isn't kept and `alreadyKept` when `file` is another game's, writing nothing.
    @discardableResult
    public func relocateGame(_ id: GameRecord.ID, to file: GameRecord) throws(LibraryStoreError) -> Library {
        var library = try load()
        try library.relocate(id, to: file)
        return try saved(library)
    }

    /// Keeps each game `moves` names by its file's record where it is now — the library's look, finding a
    /// folder of games moved — in one load and one save, however many there are (`Library.relocate(_:)`):
    /// a game no longer kept, or whose file is another game's by then, is passed over. Nothing is written
    /// when none was relocated.
    @discardableResult
    public func relocateGames(_ moves: [GameRecord.ID: GameRecord]) throws(LibraryStoreError) -> Library {
        var library = try load()
        guard !library.relocate(moves).isEmpty else { return library }
        return try saved(library)
    }

    /// Saves `library` and returns it as the file now holds it: in this build's format.
    private func saved(_ library: Library) throws(LibraryStoreError) -> Library {
        try save(library)
        return Library(bios: library.bios, games: library.games)
    }

    /// Dates as ISO 8601, to the whole second; keys sorted and indented, and paths' slashes unescaped, so
    /// the file reads and diffs plainly.
    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    /// Reads what `encoder` writes.
    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
