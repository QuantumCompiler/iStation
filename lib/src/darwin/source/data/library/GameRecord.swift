// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import CryptoKit
import Foundation

/// What kind of file a game is, as the library keeps it: a cue sheet, an ISO image, a playlist of discs
/// or a PS-EXE program. It is read leniently: a value this build doesn't know is kept as it was written,
/// never refused, so a game a later iStation recorded in a new format stays in the library.
public enum GameFormat: Sendable, Hashable, Codable {
    /// A .cue sheet, whose `FILE` lines name its tracks — the .bin files that come with it.
    case cue
    /// An .iso image.
    case iso
    /// An .m3u playlist, one disc per line.
    case m3u
    /// A PS-EXE program, an .exe file.
    case psexe
    /// A format this build doesn't know, kept as `library.json` wrote it.
    case unknown(String)

    /// The extensions of the files the library keeps, lowercase: .cue, .iso, .m3u and .exe.
    public static let fileExtensions = ["cue", "iso", "m3u", "exe"]

    /// The format `library.json` names by `rawValue` — "cue", "iso", "m3u" or "exe" — and any other
    /// value kept as `.unknown`.
    public init(rawValue: String) {
        switch rawValue {
        case "cue": self = .cue
        case "iso": self = .iso
        case "m3u": self = .m3u
        case "exe": self = .psexe
        default: self = .unknown(rawValue)
        }
    }

    /// The format of a file named `fileName`, by its extension in any case — "Glass Orchard (Europe).CUE"
    /// is a cue sheet — or nil for a file the library doesn't keep as a game: a .bin track, or anything else.
    public init?(fileName: String) {
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        guard Self.fileExtensions.contains(fileExtension) else { return nil }
        self.init(rawValue: fileExtension)
    }

    /// The name `library.json` keeps the format by: the file extension, "exe" for a PS-EXE.
    public var rawValue: String {
        switch self {
        case .cue: "cue"
        case .iso: "iso"
        case .m3u: "m3u"
        case .psexe: "exe"
        case .unknown(let value): value
        }
    }

    /// Reads the format's name; one this build doesn't know is kept, and only a value that isn't a
    /// string is an error.
    public init(from decoder: any Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }

    /// Writes the format's name.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// A game the library keeps: where the user's file is, what kind it is, and what the library knows of
/// it. The file is reached again through `bookmark`, never copied; its name and folder are what the
/// library shows, recorded when it was added and again whenever it is found somewhere else. A field
/// absent from the file decodes with its default (ADR 0016 §5).
public struct GameRecord: Sendable, Equatable, Identifiable, Codable {
    /// The game's own identifier, which the store's calls name it by: made when it is added, kept for
    /// good. A record without one is given one made from its file's path and bookmark, so it is the same
    /// game every time the library is read, until the next save writes it.
    public let id: UUID
    /// The file's name, e.g. "Glass Orchard (Europe).cue"; "" when the record didn't keep one.
    public var fileName: String
    /// The path of the folder the file was in when it was added or last found; "" when the record didn't
    /// keep one.
    public var folder: String
    /// What kind of file it is; by default the kind its file name says, else `.unknown("")`.
    public var format: GameFormat
    /// The game's size in bytes — the file's own, with a .cue's tracks and an .m3u's discs — as it was
    /// when added or last found; 0 when the record didn't keep one.
    public var size: Int
    /// When the game was added, to the whole second; `Date.distantPast` when the record didn't keep it.
    public var added: Date
    /// When the game was last played, to the whole second; nil for never.
    public var lastPlayed: Date?
    /// The name the person gave the game in the library — it never renames the file; nil (or empty) for
    /// none, and the library shows the file's name.
    public var name: String?
    /// The bookmark the file is reached by (`KeptFile.bookmark(for:)`); empty when the record didn't keep one.
    public var bookmark: Data
    /// For a .cue, the names of the track files its `FILE` lines name; empty otherwise.
    public var tracks: [String]
    /// For an .m3u, the names of the disc files it lists; empty otherwise.
    public var discs: [String]

    /// A record of these values; a new game gets a new `id`.
    public init(
        id: UUID = UUID(), fileName: String, folder: String, format: GameFormat, size: Int, added: Date,
        lastPlayed: Date? = nil, name: String? = nil, bookmark: Data, tracks: [String] = [], discs: [String] = []
    ) {
        self.id = id
        self.fileName = fileName
        self.folder = folder
        self.format = format
        self.size = size
        self.added = added
        self.lastPlayed = lastPlayed
        self.name = name
        self.bookmark = bookmark
        self.tracks = tracks
        self.discs = discs
    }

    /// The name the library shows: the one the person gave it, else the file's name without its
    /// extension, as the design writes "Glass Orchard (Europe)" for "Glass Orchard (Europe).cue".
    public var shownName: String {
        if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return name }
        let stem = (fileName as NSString).deletingPathExtension
        return stem.isEmpty ? fileName : stem
    }

    /// The file's path, standardized — "." and ".." resolved, "/private" taken off as the system spells
    /// its own folders — which tells two games apart: the library keeps one game per file. A record that
    /// didn't keep its folder is its file name alone.
    public var path: String {
        Self.standardizedPath(folder: folder, fileName: fileName)
    }

    /// The standardized path of the file at `url`, as `path` writes a record's.
    public static func standardizedPath(of url: URL) -> String {
        url.standardizedFileURL.path
    }

    private static func standardizedPath(folder: String, fileName: String) -> String {
        guard !folder.isEmpty else { return fileName }
        let joined = folder.hasSuffix("/") ? folder + fileName : folder + "/" + fileName
        guard joined.hasPrefix("/") else { return joined }
        return standardizedPath(of: URL(fileURLWithPath: joined))
    }

    private enum CodingKeys: String, CodingKey {
        case id, fileName, folder, format, size, added, lastPlayed, name, bookmark, tracks, discs
    }

    /// Reads a record, each field defaulted when absent — a wrong type is still an error.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fileName = try container.decodeIfPresent(String.self, forKey: .fileName) ?? ""
        folder = try container.decodeIfPresent(String.self, forKey: .folder) ?? ""
        format = try container.decodeIfPresent(GameFormat.self, forKey: .format)
            ?? GameFormat(fileName: fileName) ?? .unknown("")
        size = try container.decodeIfPresent(Int.self, forKey: .size) ?? 0
        added = try container.decodeIfPresent(Date.self, forKey: .added) ?? .distantPast
        lastPlayed = try container.decodeIfPresent(Date.self, forKey: .lastPlayed)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        bookmark = try container.decodeIfPresent(Data.self, forKey: .bookmark) ?? Data()
        tracks = try container.decodeIfPresent([String].self, forKey: .tracks) ?? []
        discs = try container.decodeIfPresent([String].self, forKey: .discs) ?? []
        id = try container.decodeIfPresent(UUID.self, forKey: .id)
            ?? Self.identifier(path: Self.standardizedPath(folder: folder, fileName: fileName), bookmark: bookmark)
    }

    /// Writes every field; the last-played date and the library's own name only when there is one.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fileName, forKey: .fileName)
        try container.encode(folder, forKey: .folder)
        try container.encode(format, forKey: .format)
        try container.encode(size, forKey: .size)
        try container.encode(added, forKey: .added)
        try container.encodeIfPresent(lastPlayed, forKey: .lastPlayed)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encode(bookmark, forKey: .bookmark)
        try container.encode(tracks, forKey: .tracks)
        try container.encode(discs, forKey: .discs)
    }

    /// This record under the id `id`: the same game's file, told apart from another record of the same id.
    func identified(as id: UUID) -> GameRecord {
        GameRecord(
            id: id, fileName: fileName, folder: folder, format: format, size: size, added: added, lastPlayed: lastPlayed,
            name: name, bookmark: bookmark, tracks: tracks, discs: discs
        )
    }

    /// The identifier of a record that didn't keep one: a name-based UUID (version 5's layout) made from
    /// the SHA-1 of its path and bookmark, so reading the same record twice gives the same game.
    static func identifier(path: String, bookmark: Data) -> UUID {
        var name = Data("istation.game:".utf8)
        name.append(Data(path.utf8))
        name.append(0)
        name.append(bookmark)
        var bytes = Array(Insecure.SHA1.hash(data: name).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}
