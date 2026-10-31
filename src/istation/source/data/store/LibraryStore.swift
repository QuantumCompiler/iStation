import DataCatalog
import DataEmulators
import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    /// Emulator .app bundles, keyed by `EmulatorKind.rawValue`.
    public var emulatorApps: [String: URL] = [:]
    public var launchOptions = LaunchOptions()
    public var includeRPCS3InstalledGames = true
    /// RPCS3's dev_hdd0/game folder; nil means RPCS3's default location.
    public var rpcs3GameFolder: URL?

    public init() {}

    // Decode field by field so adding a setting later doesn't wipe an existing library file (ADR 0007).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings()
        emulatorApps = try c.decodeIfPresent([String: URL].self, forKey: .emulatorApps) ?? defaults.emulatorApps
        launchOptions = try c.decodeIfPresent(LaunchOptions.self, forKey: .launchOptions) ?? defaults.launchOptions
        includeRPCS3InstalledGames = try c.decodeIfPresent(Bool.self, forKey: .includeRPCS3InstalledGames)
            ?? defaults.includeRPCS3InstalledGames
        rpcs3GameFolder = try c.decodeIfPresent(URL.self, forKey: .rpcs3GameFolder) ?? defaults.rpcs3GameFolder
    }

    public func app(for kind: EmulatorKind) -> URL? { emulatorApps[kind.rawValue] }

    public mutating func setApp(_ url: URL?, for kind: EmulatorKind) {
        emulatorApps[kind.rawValue] = url
    }
}

public struct LibraryState: Codable, Equatable, Sendable {
    public var folders: [LibraryFolder] = []
    public var games: [Game] = []
    public var settings = AppSettings()

    public init(folders: [LibraryFolder] = [], games: [Game] = [], settings: AppSettings = AppSettings()) {
        self.folders = folders
        self.games = games
        self.settings = settings
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        folders = try c.decodeIfPresent([LibraryFolder].self, forKey: .folders) ?? []
        games = try c.decodeIfPresent([Game].self, forKey: .games) ?? []
        settings = try c.decodeIfPresent(AppSettings.self, forKey: .settings) ?? AppSettings()
    }
}

/// Persists everything to one JSON file, `<Application Support>/iStation/library.json`
/// (reference/library-file.md).
public struct LibraryStore: Sendable {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// The library file inside an Application Support folder.
    public static func file(inApplicationSupport applicationSupport: URL) -> URL {
        applicationSupport.appendingPathComponent("iStation/library.json")
    }

    /// The saved state, or an empty library when there is no readable file.
    public func load() -> LibraryState {
        guard let data = try? Data(contentsOf: fileURL),
              let state = try? Self.decoder.decode(LibraryState.self, from: data)
        else { return LibraryState() }
        return state
    }

    public func save(_ state: LibraryState) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Self.encoder.encode(state).write(to: fileURL, options: .atomic)
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
