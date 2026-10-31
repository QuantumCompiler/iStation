import Foundation
import InfrastructureProcess
import Testing

@Suite struct ProcessRunnerTests {
    @Test func reportsExitStatusAndDuration() async throws {
        let command = Command(executable: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "sleep 0.1; exit 3"])
        let exit = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ProcessExit, any Error>) in
            do {
                try ProcessRunner().run(command) { continuation.resume(returning: $0) }
            } catch {
                continuation.resume(throwing: error)
            }
        }
        #expect(exit.status == 3)
        #expect(exit.duration >= 0.1)
    }

    @Test func aMissingExecutableThrows() {
        let command = Command(executable: URL(fileURLWithPath: "/nonexistent/iStation-test-binary"), arguments: [])
        #expect(throws: (any Error).self) {
            try ProcessRunner().run(command) { _ in }
        }
    }
}
