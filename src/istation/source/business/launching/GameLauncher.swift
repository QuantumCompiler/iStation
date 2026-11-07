import DataCatalog
import DataEmulators
import Foundation
import InfrastructureBundles
import InfrastructureProcess

/// Which emulator runs each console's games.
public enum EmulatorChoice {
    public static func emulator(for platform: Platform) -> EmulatorKind {
        switch platform {
        case .ps1: .duckstation
        case .ps2: .pcsx2
        case .ps3: .rpcs3
        }
    }
}

public enum LaunchError: LocalizedError, Equatable {
    case emulatorNotSetUp(EmulatorKind)
    case couldNotStart(EmulatorKind, reason: String)

    public var errorDescription: String? {
        switch self {
        case .emulatorNotSetUp(let kind):
            "\(kind.displayName) isn’t set up yet. Choose its app in Settings (⌘,)."
        case .couldNotStart(let kind, let reason):
            "Couldn’t start \(kind.displayName): \(reason)"
        }
    }
}

/// Starts a game in its emulator, as a separate process driven only by its command line (ADR 0013),
/// and reports how long the session lasted.
public struct GameLauncher: Sendable {
    private let runner: any ProcessRunning

    public init(runner: any ProcessRunning) {
        self.runner = runner
    }

    /// The command line that boots `game` with the emulator app at `appBundle`.
    public func command(for game: Game, appBundle: URL?, options: LaunchOptions) throws -> Command {
        let kind = EmulatorChoice.emulator(for: game.platform)
        guard let appBundle, let executable = AppBundles.executable(inAppBundle: appBundle) else {
            throw LaunchError.emulatorNotSetUp(kind)
        }
        let arguments = LaunchContract.arguments(for: kind, booting: game.bootTarget, options: options)
        return Command(executable: executable, arguments: arguments)
    }

    /// Returns once the emulator is running; `onExit` gets the session's length when it quits.
    public func start(
        _ game: Game,
        appBundle: URL?,
        options: LaunchOptions,
        onExit: @escaping @Sendable (TimeInterval) -> Void
    ) throws {
        let command = try command(for: game, appBundle: appBundle, options: options)
        do {
            try runner.run(command) { exit in onExit(exit.duration) }
        } catch {
            throw LaunchError.couldNotStart(EmulatorChoice.emulator(for: game.platform), reason: error.localizedDescription)
        }
    }
}
