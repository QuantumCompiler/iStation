import DataTracing
import Foundation
import SupportSandbox
import Testing

/// Writes and reads 100 million instruction records (2.5 GB) and prints the rates. Off by default;
/// run with `ISTATION_BENCHMARK=1 swift test -c release --filter ThroughputTests`.
@Suite struct ThroughputTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["ISTATION_BENCHMARK"] != nil))
    func oneHundredMillionInstructionRecords() throws {
        let sandbox = try Sandbox()
        let url = sandbox.url("throughput.trace")
        let count = 100_000_000
        let clock = ContinuousClock()
        let writeTime = try clock.measure {
            let writer = try TraceWriter(url: url, header: TraceHeader(granularity: .instruction))
            for index in 0..<count {
                try writer.append(InstructionRecord(pc: UInt32(truncatingIfNeeded: index) &* 4, word: UInt32(truncatingIfNeeded: index), cycles: UInt64(index), registerChecksum: UInt64(index)))
            }
            try writer.finish()
        }
        var read = 0
        let readTime = try clock.measure {
            let reader = try TraceReader(url: url)
            while try reader.next() != nil { read += 1 }
        }
        let bytes = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int ?? 0
        print("ThroughputTests: \(count) records, \(bytes) bytes; write \(writeTime), read \(readTime)")
        #expect(read == count)
    }
}
