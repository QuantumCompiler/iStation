import BusinessLaunching
import DataCatalog
import DataEmulators
import Foundation
import InfrastructureProcess
import SupportSandbox
import Testing

/// Records commands instead of running them; exits the moment it is asked to.
private final class RecordingRunner: ProcessRunning, @unchecked Sendable {
    var commands: [Command] = []
    var failure: (any Error)?
    var exitAfter: TimeInterval = 42

    func run(_ command: Command, onExit: @escaping @Sendable (ProcessExit) -> Void) throws {
        if let failure { throw failure }
        commands.append(command)
        onExit(ProcessExit(status: 0, duration: exitAfter))
    }
}

private struct NoSuchFile: LocalizedError {
    var errorDescription: String? { "The file doesn’t exist." }
}

@Suite struct GameLauncherTests {
    private let iso = URL(fileURLWithPath: "/g/a.iso")

    private func ps2Game() -> Game {
        Game(title: "T", serial: nil, platform: .ps2, location: iso, bootTarget: .path(iso))
    }

    @Test func startsTheConsolesEmulatorWithItsContractFlags() throws {
        let sandbox = try Sandbox()
        let app = try sandbox.makeApp("Applications/PCSX2.app", binary: "PCSX2")
        let runner = RecordingRunner()
        let lengths = LockedLengths()

        try GameLauncher(runner: runner).start(ps2Game(), appBundle: app, options: LaunchOptions()) { lengths.append($0) }

        #expect(runner.commands.count == 1)
        #expect(runner.commands.first?.executable.lastPathComponent == "PCSX2")
        #expect(runner.commands.first?.arguments == ["-batch", "-fullscreen", "-fastboot", "--", "/g/a.iso"])
        #expect(lengths.values == [42])
    }

    @Test func anEmulatorWithNoAppIsNotSetUp() {
        #expect(throws: LaunchError.emulatorNotSetUp(.pcsx2)) {
            try GameLauncher(runner: RecordingRunner()).start(ps2Game(), appBundle: nil, options: LaunchOptions()) { _ in }
        }
    }

    @Test func aProcessThatWontStartSaysWhy() throws {
        let sandbox = try Sandbox()
        let app = try sandbox.makeApp("Applications/PCSX2.app", binary: "PCSX2")
        let runner = RecordingRunner()
        runner.failure = NoSuchFile()
        #expect(throws: LaunchError.couldNotStart(.pcsx2, reason: "The file doesn’t exist.")) {
            try GameLauncher(runner: runner).start(ps2Game(), appBundle: app, options: LaunchOptions()) { _ in }
        }
    }

    @Test func errorsReadAsInstructions() {
        #expect(LaunchError.emulatorNotSetUp(.rpcs3).localizedDescription
            == "RPCS3 isn’t set up yet. Choose its app in Settings (⌘,).")
    }

    @Test func eachConsoleHasItsEmulator() {
        #expect(Platform.allCases.map(EmulatorChoice.emulator(for:)) == [.duckstation, .pcsx2, .rpcs3])
    }
}

private final class LockedLengths: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [TimeInterval] = []
    var values: [TimeInterval] { lock.withLock { stored } }
    func append(_ value: TimeInterval) { lock.withLock { stored.append(value) } }
}
