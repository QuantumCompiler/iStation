import DataCatalog

/// One of the three external emulators iStation drives.
public enum EmulatorKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case duckstation, pcsx2, rpcs3

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .duckstation: "DuckStation"
        case .pcsx2: "PCSX2"
        case .rpcs3: "RPCS3"
        }
    }

    /// The console this emulator emulates.
    public var platform: Platform {
        switch self {
        case .duckstation: .ps1
        case .pcsx2: .ps2
        case .rpcs3: .ps3
        }
    }

    /// CFBundleIdentifier from each project's Info.plist.
    public var bundleIdentifier: String {
        switch self {
        case .duckstation: "com.github.stenzek.duckstation"
        case .pcsx2: "net.pcsx2.pcsx2"
        case .rpcs3: "net.rpcs3.rpcs3"
        }
    }

    /// App bundle names to look for in /Applications and ~/Applications.
    public var commonAppNames: [String] {
        switch self {
        case .duckstation: ["DuckStation.app"]
        case .pcsx2: ["PCSX2.app"]
        case .rpcs3: ["RPCS3.app", "rpcs3.app"]
        }
    }
}
