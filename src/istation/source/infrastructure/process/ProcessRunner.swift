import Foundation

/// A program to run and its arguments.
public struct Command: Equatable, Sendable {
    public let executable: URL
    public let arguments: [String]

    public init(executable: URL, arguments: [String]) {
        self.executable = executable
        self.arguments = arguments
    }
}

/// How a finished child process ended.
public struct ProcessExit: Equatable, Sendable {
    public let status: Int32
    /// Wall-clock time from start to exit.
    public let duration: TimeInterval

    public init(status: Int32, duration: TimeInterval) {
        self.status = status
        self.duration = duration
    }
}

/// Starts child processes. This module is the one place iStation spawns one (ADR 0008).
public protocol ProcessRunning: Sendable {
    /// Starts `command` and returns once it is running. `onExit` is called once, on an arbitrary
    /// thread, when the process exits.
    func run(_ command: Command, onExit: @escaping @Sendable (ProcessExit) -> Void) throws
}

public struct ProcessRunner: ProcessRunning {
    public init() {}

    public func run(_ command: Command, onExit: @escaping @Sendable (ProcessExit) -> Void) throws {
        let process = Process()
        process.executableURL = command.executable
        process.arguments = command.arguments
        let start = Date()
        process.terminationHandler = { finished in
            onExit(ProcessExit(status: finished.terminationStatus, duration: Date().timeIntervalSince(start)))
        }
        try process.run()
    }
}
