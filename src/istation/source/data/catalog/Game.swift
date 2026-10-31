import Foundation

/// What gets handed to the emulator to boot a game.
public enum BootTarget: Codable, Hashable, Sendable {
    /// A disc image, playlist (.m3u), or PS3 disc folder.
    case path(URL)
    /// A game installed into RPCS3's dev_hdd0 (PSN titles), booted by title ID.
    case rpcs3TitleID(String)
}

public struct Game: Identifiable, Codable, Hashable, Sendable {
    /// Stable key used to keep play history across rescans: the console plus the boot path, or plus
    /// the title ID for installed PS3 games. Moving a file starts its history over.
    public var id: String
    public var title: String
    /// Normalised product code, e.g. "SLUS-20062" or "BLUS30443".
    public var serial: String?
    public var platform: Platform
    /// The file or folder shown to the user (Reveal in Finder).
    public var location: URL
    public var bootTarget: BootTarget
    public var lastPlayed: Date?
    public var playTime: TimeInterval

    public init(
        title: String,
        serial: String?,
        platform: Platform,
        location: URL,
        bootTarget: BootTarget,
        lastPlayed: Date? = nil,
        playTime: TimeInterval = 0
    ) {
        switch bootTarget {
        case .path(let url): id = "\(platform.rawValue):\(url.standardizedFileURL.path)"
        case .rpcs3TitleID(let titleID): id = "\(platform.rawValue):id:\(titleID)"
        }
        self.title = title
        self.serial = serial
        self.platform = platform
        self.location = location
        self.bootTarget = bootTarget
        self.lastPlayed = lastPlayed
        self.playTime = playTime
    }
}

/// A folder the user added to the library.
public struct LibraryFolder: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var url: URL
    /// Used when a disc image's contents can't be read (e.g. compressed .chd files).
    public var platformHint: Platform?

    public init(id: UUID = UUID(), url: URL, platformHint: Platform? = nil) {
        self.id = id
        self.url = url
        self.platformHint = platformHint
    }
}
