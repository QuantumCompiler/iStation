// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import Foundation

/// How a caller reaches the files the library keeps: where a bookmark leads now, a file's size without
/// reading it, and its bytes. `KeptFileReader` is the files themselves, through `KeptFile`; a view-model's
/// storage refines this protocol (the BIOS's `BIOSStorage`), so its fakes stand in for the files and the
/// shared sequences below run over them too. Every call is synchronous: the caller chooses where each
/// runs, a file's bytes off the main actor.
public protocol KeptFileReading: Sendable {
    /// Where `bookmark` leads now, and whether it should be made again (`KeptFile.resolve(_:)`).
    func resolve(_ bookmark: Data) throws -> KeptFile.Resolved

    /// The size in bytes of the file at `url`, without reading it (`KeptFile.size(at:)`).
    func size(of url: URL) throws -> Int

    /// The bytes of the file at `url` (`KeptFile.bytes(at:)`).
    func bytes(of url: URL) throws -> [UInt8]
}

/// The kept files themselves, read through `KeptFile`, each call inside the file's security-scoped access.
public struct KeptFileReader: KeptFileReading {
    /// A reader of the files where the user keeps them.
    public init() {}

    /// Where `bookmark` leads now (`KeptFile.resolve(_:)`).
    public func resolve(_ bookmark: Data) throws -> KeptFile.Resolved {
        try KeptFile.resolve(bookmark)
    }

    /// The size of the file at `url`, without reading it (`KeptFile.size(at:)`).
    public func size(of url: URL) throws -> Int {
        try KeptFile.size(at: url)
    }

    /// The bytes of the file at `url` (`KeptFile.bytes(at:)`).
    public func bytes(of url: URL) throws -> [UInt8] {
        try KeptFile.bytes(at: url)
    }
}

extension KeptFile {
    /// Where a kept game's file is now, as the library tells it: found where the library recorded it,
    /// found somewhere else — the bookmark should be made again and the record kept with the file's name
    /// and folder now — or missing. A missing game stays in the library: the person can Locate… it, or
    /// it comes back when its file does.
    public enum Whereabouts: Sendable, Equatable {
        /// The bookmark leads to the file, where the library recorded it.
        case found(URL)
        /// The bookmark leads to the file, but it moved or was renamed: the system says the bookmark is
        /// stale, or the file is no longer at the recorded path.
        case moved(URL)
        /// The bookmark leads to no file — it was deleted, its volume is gone, or the bookmark is
        /// damaged — or to one that can't be reached: what was thrown, for Details.
        case missing(KeptFileError)
    }
}

/// Why the kept BIOS couldn't be read where the user keeps it. Each case carries what `KeptFile` threw,
/// so Details can name the call that failed: finding it, sizing it or reading it.
public enum KeptBIOSError: Error, Equatable, Sendable {
    /// The bookmark no longer leads to a file: `KeptFile.resolve(_:)` threw this.
    case cannotFind(KeptFileError)
    /// The file was found but couldn't be sized: `KeptFile.size(at:)` threw this. Nothing was read.
    case cannotSize(KeptFileError)
    /// The file is no longer a BIOS's size: it is this many bytes now. It wasn't read.
    case wrongSize(Int)
    /// The file was found and sized but couldn't be read: `KeptFile.bytes(at:)` threw this.
    case cannotRead(KeptFileError)
}

/// The kept BIOS, read where the user keeps it: the file its bookmark leads to, whether that bookmark
/// should be made again, and the file's bytes.
public struct KeptBIOS: Sendable, Equatable {
    /// The file the bookmark led to.
    public var url: URL
    /// True when the file moved or was renamed: the bookmark should be made again where it is now
    /// (`BIOSRecord.moved(to:bookmark:)`) and the record kept again.
    public var isStale: Bool
    /// The file's bytes.
    public var bytes: [UInt8]

    /// A read of these values.
    public init(url: URL, isStale: Bool, bytes: [UInt8]) {
        self.url = url
        self.isStale = isStale
        self.bytes = bytes
    }
}

extension KeptFileReading {
    /// Reads the kept BIOS `record` names, as Run the BIOS and a game's opening job do: its bookmark
    /// resolved, its file sized without reading it — one that is no longer `expectedSize` bytes, a BIOS's
    /// size, is refused unread, as the BIOS check refuses one — then its bytes read. Nothing is kept
    /// again here: a stale bookmark is the caller's to make again, once the BIOS has been used.
    public func readBIOS(_ record: BIOSRecord, expectedSize: Int) throws(KeptBIOSError) -> KeptBIOS {
        let resolved: KeptFile.Resolved
        do {
            resolved = try resolve(record.bookmark)
        } catch {
            throw .cannotFind(Self.kept(error) { .cannotResolve(reason: $0) })
        }
        let size: Int
        do {
            size = try self.size(of: resolved.url)
        } catch {
            throw .cannotSize(Self.kept(error) { .cannotRead(path: resolved.url.path, reason: $0) })
        }
        guard size == expectedSize else { throw .wrongSize(size) }
        let bytes: [UInt8]
        do {
            bytes = try self.bytes(of: resolved.url)
        } catch {
            throw .cannotRead(Self.kept(error) { .cannotRead(path: resolved.url.path, reason: $0) })
        }
        return KeptBIOS(url: resolved.url, isStale: resolved.isStale, bytes: bytes)
    }

    /// Where `game`'s file is now: its bookmark resolved and the file it leads to sized, which tells a
    /// file that is there from one that isn't. A bookmark that doesn't resolve, or leads to a file that
    /// can't be sized, is `.missing`; one that resolves stale, or to another path than the record's
    /// (`GameRecord.path`), is `.moved`; else `.found`. Nothing is changed: the record stays as it is.
    public func whereabouts(of game: GameRecord) -> KeptFile.Whereabouts {
        let resolved: KeptFile.Resolved
        do {
            resolved = try resolve(game.bookmark)
        } catch {
            return .missing(Self.kept(error) { .cannotResolve(reason: $0) })
        }
        do {
            _ = try size(of: resolved.url)
        } catch {
            return .missing(Self.kept(error) { .cannotRead(path: resolved.url.path, reason: $0) })
        }
        if resolved.isStale || GameRecord.standardizedPath(of: resolved.url) != game.path {
            return .moved(resolved.url)
        }
        return .found(resolved.url)
    }

    /// `error` as `KeptFile` throws it: itself when it is a `KeptFileError`, as every `KeptFileReader`
    /// call's is, else made one by `wrap` from its description.
    private static func kept(_ error: any Error, _ wrap: (String) -> KeptFileError) -> KeptFileError {
        error as? KeptFileError ?? wrap(error.localizedDescription)
    }
}
