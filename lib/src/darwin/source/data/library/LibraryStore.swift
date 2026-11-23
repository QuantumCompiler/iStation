// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import Foundation

/// Why the library couldn't be loaded or saved. Each case carries what the app needs to say so in
/// plain words, and the system's own reason, for Details.
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
        try save(library)
        return library
    }

    /// Forgets the kept BIOS, if any, and saves; returns the library saved. The user's file is left as it is.
    @discardableResult
    public func forgetBIOS() throws(LibraryStoreError) -> Library {
        var library = try load()
        library.bios = nil
        try save(library)
        return library
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
