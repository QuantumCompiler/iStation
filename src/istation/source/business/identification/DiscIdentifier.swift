import DataCatalog
import DataISO9660
import DataParamSFO
import DataPlaylists
import DataSystemCNF
import Foundation

/// What we learned by looking inside a disc image or game folder.
public struct DiscInfo: Equatable, Sendable {
    public var platform: Platform
    public var serial: String?
    public var title: String?

    public init(platform: Platform, serial: String? = nil, title: String? = nil) {
        self.platform = platform
        self.serial = serial
        self.title = title
    }
}

/// Decides which console a game file or folder belongs to: by what is on the disc first, then by
/// the folder's hint, and only then by extension or size (SPEC: Game identification).
public enum DiscIdentifier {
    /// Images we can open and read the filesystem of.
    public static let readableImageExtensions: Set<String> = ["iso", "bin", "img"]
    /// Compressed images we can't look inside (yet); identified by extension or folder hint.
    public static let compressedImageExtensions: Set<String> = ["chd", "cso", "zso", "gz", "pbp", "ecm"]
    public static let playlistExtensions: Set<String> = ["cue", "m3u"]
    /// Every extension a library scan treats as a game file.
    public static var gameFileExtensions: Set<String> {
        readableImageExtensions.union(compressedImageExtensions).union(playlistExtensions)
    }

    /// Inspect a readable disc image (.iso, .bin, .img).
    public static func identify(image url: URL) -> DiscInfo? {
        guard let iso = try? ISO9660(url: url) else { return nil }
        defer { iso.close() }

        if let entry = try? iso.find("SYSTEM.CNF"),
           let bytes = try? iso.read(entry),
           let cnf = SystemCNF(text: String(decoding: bytes, as: UTF8.self)) {
            return DiscInfo(platform: cnf.platform, serial: cnf.serial)
        }
        if let entry = try? iso.find("PS3_GAME/PARAM.SFO"),
           let bytes = try? iso.read(entry),
           let sfo = try? ParamSFO(bytes: bytes) {
            return DiscInfo(platform: .ps3, serial: sfo.titleID, title: sfo.title)
        }
        if (try? iso.find("PSX.EXE")) != nil {
            // Very early PS1 discs boot PSX.EXE without a SYSTEM.CNF.
            return DiscInfo(platform: .ps1)
        }
        return nil
    }

    /// A PS3 disc folder: `<folder>/PS3_GAME/PARAM.SFO`.
    public static func identify(ps3DiscFolder folder: URL) -> DiscInfo? {
        let sfoURL = folder.appendingPathComponent("PS3_GAME/PARAM.SFO")
        guard let sfo = try? ParamSFO(url: sfoURL) else { return nil }
        return DiscInfo(platform: .ps3, serial: sfo.titleID, title: sfo.title)
    }

    /// Any game file: an image, a playlist or a compressed image, with the folder's console hint as
    /// the fallback when the contents can't be read.
    public static func identify(file url: URL, hint: Platform?) -> DiscInfo? {
        switch url.pathExtension.lowercased() {
        case "m3u":
            Playlists.m3uEntries(url).first.flatMap { probe($0, hint: hint) }
        default:
            probe(url, hint: hint)
        }
    }

    /// Guess a platform from folder names like ".../PS2/..." or ".../psx/...".
    public static func platformHint(fromPath url: URL) -> Platform? {
        for component in url.pathComponents.reversed().map({ $0.lowercased() }) {
            switch component {
            case "ps1", "psx", "psone", "playstation", "playstation 1", "duckstation": return .ps1
            case "ps2", "playstation 2", "pcsx2": return .ps2
            case "ps3", "playstation 3", "rpcs3": return .ps3
            default: continue
            }
        }
        return nil
    }

    private static func probe(_ url: URL, hint: Platform?) -> DiscInfo? {
        switch url.pathExtension.lowercased() {
        case "cue":
            guard let firstTrack = Playlists.cueTracks(url).first else { return nil }
            // A cue sheet is a CD, so PS3 is impossible.
            if let info = identify(image: firstTrack) { return info }
            return DiscInfo(platform: hint == .ps2 ? .ps2 : .ps1)
        case "iso", "bin", "img":
            if let info = identify(image: url) { return info }
            return hint.map { DiscInfo(platform: $0) }
        case "pbp":
            return DiscInfo(platform: .ps1) // PSN PS1 classics (EBOOT.PBP)
        case "cso", "zso":
            return DiscInfo(platform: .ps2)
        case "chd", "gz", "ecm":
            // TODO: decompress the first hunks of a CHD to read SYSTEM.CNF (ROADMAP v0.2.0).
            if let hint { return DiscInfo(platform: hint) }
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return DiscInfo(platform: size > 800_000_000 ? .ps2 : .ps1)
        default:
            return nil
        }
    }
}
