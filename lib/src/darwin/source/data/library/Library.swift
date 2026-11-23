// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import Foundation

/// What iStation keeps of the user's own files, as `library.json` holds it: the BIOS the check passed
/// (5c), and, from 5d, the games. Every file it names is kept where the user keeps it, by a bookmark —
/// never copied. A field a later version adds decodes with a default, so a library an older iStation
/// wrote keeps loading (ADR 0016 §5).
public struct Library: Sendable, Equatable, Codable {
    /// The format this build writes: 1 since 5c.
    public static let currentVersion = 1

    /// The format the library was written in: `currentVersion` for a new one, the file's own once loaded.
    /// Saving writes `currentVersion` whatever this says: a build writes only its own shape.
    public let version: Int
    /// The BIOS the check passed and the app keeps; nil until one is kept, and once it is forgotten.
    public var bios: BIOSRecord?

    /// An empty library in this build's format, or one that keeps `bios`.
    public init(bios: BIOSRecord? = nil) {
        version = Self.currentVersion
        self.bios = bios
    }

    private enum CodingKeys: String, CodingKey {
        case version, bios
    }

    /// Reads a library, its version required — a file without one isn't a library — and every other
    /// field defaulted when absent. Unknown keys, a later version's additions, are ignored here and
    /// dropped by the next save; `LibraryStore` refuses a version above `currentVersion` before saving
    /// over it could lose them. So a change that adds a field to the file raises `currentVersion`: a
    /// build from before it then refuses the file instead of saving over the field it doesn't know.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        bios = try container.decodeIfPresent(BIOSRecord.self, forKey: .bios)
    }

    /// Writes the library in this build's format: `currentVersion`, whichever version it was read in,
    /// and the BIOS record when one is kept.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentVersion, forKey: .version)
        try container.encodeIfPresent(bios, forKey: .bios)
    }
}

/// The BIOS the app keeps: where the user's file is, what it is, and when the check passed it. The file
/// is reached again through `bookmark`; the name and folder are what the BIOS pane shows, recorded when
/// it was kept. A field absent from the file — one a later version adds — decodes with its default
/// (ADR 0016 §5).
public struct BIOSRecord: Sendable, Equatable, Codable {
    /// The file's name, e.g. "my-console-bios.bin"; "" when the file didn't record one.
    public var fileName: String
    /// The path of the folder the file was in when it was kept; "" when the file didn't record one.
    public var folder: String
    /// The file's size in bytes: 524,288 for a BIOS the check passed; 0 when the file didn't record one.
    public var size: Int
    /// The file's SHA-1 fingerprint, 40 lowercase hexadecimal digits (`Fingerprint.sha1(of:)`); "" when
    /// the file didn't record one.
    public var sha1: String
    /// When the check passed the file, stored to the whole second (ISO 8601); `Date.distantPast` when
    /// the file didn't record it.
    public var checked: Date
    /// The bookmark the file is reached by (`KeptFile.bookmark(for:)`); empty when the file didn't record one.
    public var bookmark: Data

    /// A record of these values.
    public init(fileName: String, folder: String, size: Int, sha1: String, checked: Date, bookmark: Data) {
        self.fileName = fileName
        self.folder = folder
        self.size = size
        self.sha1 = sha1
        self.checked = checked
        self.bookmark = bookmark
    }

    private enum CodingKeys: String, CodingKey {
        case fileName, folder, size, sha1, checked, bookmark
    }

    /// Reads a record, each field defaulted when absent — a wrong type is still an error.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fileName = try container.decodeIfPresent(String.self, forKey: .fileName) ?? ""
        folder = try container.decodeIfPresent(String.self, forKey: .folder) ?? ""
        size = try container.decodeIfPresent(Int.self, forKey: .size) ?? 0
        sha1 = try container.decodeIfPresent(String.self, forKey: .sha1) ?? ""
        checked = try container.decodeIfPresent(Date.self, forKey: .checked) ?? .distantPast
        bookmark = try container.decodeIfPresent(Data.self, forKey: .bookmark) ?? Data()
    }

    /// Writes every field.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fileName, forKey: .fileName)
        try container.encode(folder, forKey: .folder)
        try container.encode(size, forKey: .size)
        try container.encode(sha1, forKey: .sha1)
        try container.encode(checked, forKey: .checked)
        try container.encode(bookmark, forKey: .bookmark)
    }
}
