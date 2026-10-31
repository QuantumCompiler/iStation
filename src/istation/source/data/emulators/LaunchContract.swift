import DataCatalog
import Foundation

public struct LaunchOptions: Codable, Equatable, Sendable {
    public var fullscreen: Bool = true
    /// Skip the BIOS boot animation (DuckStation / PCSX2).
    public var fastBoot: Bool = true

    public init(fullscreen: Bool = true, fastBoot: Bool = true) {
        self.fullscreen = fullscreen
        self.fastBoot = fastBoot
    }

    // Decode field by field so a library file written before a field existed still loads (ADR 0007).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = LaunchOptions()
        fullscreen = try c.decodeIfPresent(Bool.self, forKey: .fullscreen) ?? defaults.fullscreen
        fastBoot = try c.decodeIfPresent(Bool.self, forKey: .fastBoot) ?? defaults.fastBoot
    }
}

/// Each emulator's command line, as its own argument parser reads it (reference/emulator-launch-contract.md).
///
/// Flags taken from DuckStation `src/duckstation-qt/qthost.cpp`, PCSX2 `pcsx2-qt/QtHost.cpp` and
/// RPCS3 `rpcs3/rpcs3.cpp`, checked against their sources on 2026-10-25.
public enum LaunchContract {
    public static func arguments(for emulator: EmulatorKind, booting target: BootTarget, options: LaunchOptions) -> [String] {
        var arguments: [String] = []

        switch emulator {
        case .duckstation, .pcsx2:
            // -batch: quit when the game shuts down, so the process exit marks the end of the session.
            arguments.append("-batch")
            if options.fullscreen { arguments.append("-fullscreen") }
            if options.fastBoot { arguments.append("-fastboot") }
            arguments.append("--") // everything after this is the boot path, even if it starts with "-"
            arguments.append(bootString(target))

        case .rpcs3:
            arguments.append("--no-gui")
            if options.fullscreen { arguments.append("--fullscreen") }
            arguments.append(bootString(target))
        }

        return arguments
    }

    static func bootString(_ target: BootTarget) -> String {
        switch target {
        case .path(let url): url.path
        case .rpcs3TitleID(let titleID): "%RPCS3_GAMEID%:\(titleID)"
        }
    }
}

/// Where RPCS3 keeps its files on macOS.
public enum RPCS3Layout {
    /// The virtual HDD's installed-games folder: ~/Library/Application Support/rpcs3/dev_hdd0/game.
    public static func installedGamesFolder(applicationSupport: URL) -> URL {
        applicationSupport.appendingPathComponent("rpcs3/dev_hdd0/game")
    }
}
