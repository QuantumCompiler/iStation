import Foundation

/// One window of a trace: the records before `endIndex`, from the previous checkpoint on, reduced
/// to one checksum.
public struct Checkpoint: Equatable, Sendable {
    /// The index one past the window's last record.
    public let endIndex: UInt64
    /// FNV-1a 64 over the window's records' bytes, tags included.
    public let checksum: UInt64
}

/// A whole trace reduced to a few kilobytes, small enough to commit as a test fixture: any change
/// to any record changes its window's checksum (reference/trace-formats.md).
public struct CheckpointFile: Equatable, Sendable {
    public static let magic: [UInt8] = Array("ISCK".utf8)
    public static let version: UInt16 = 1

    public let granularity: TraceGranularity
    /// Records per window; the last window may be shorter.
    public let window: UInt32
    public let recordCount: UInt64
    public let checkpoints: [Checkpoint]
}

public enum Checkpoints {
    /// Reads a trace and reduces it to one checkpoint per `window` records.
    public static func reduce(_ trace: URL, window: UInt32) throws -> CheckpointFile {
        precondition(window > 0, "a window holds at least one record")
        let reader = try TraceReader(url: trace)
        var checkpoints: [Checkpoint] = []
        var checksum = FNV1a64()
        var count: UInt64 = 0
        var bytes: [UInt8] = []
        bytes.reserveCapacity(1 + FullStateRecord.payloadSize)
        while let record = try reader.next() {
            bytes.removeAll(keepingCapacity: true)
            record.encode(into: &bytes)
            checksum.add(bytes: bytes)
            count += 1
            if count % UInt64(window) == 0 {
                checkpoints.append(Checkpoint(endIndex: count, checksum: checksum.value))
                checksum = FNV1a64()
            }
        }
        if count % UInt64(window) != 0 {
            checkpoints.append(Checkpoint(endIndex: count, checksum: checksum.value))
        }
        return CheckpointFile(granularity: reader.header.granularity, window: window, recordCount: count, checkpoints: checkpoints)
    }

    /// The index of the first window in which two reductions differ, or nil when they match.
    public static func firstDivergentWindow(_ a: CheckpointFile, _ b: CheckpointFile) throws -> Int? {
        guard a.granularity == b.granularity else { throw TraceError.granularityMismatch }
        precondition(a.window == b.window, "compare reductions made with the same window")
        for index in 0..<max(a.checkpoints.count, b.checkpoints.count) {
            guard index < a.checkpoints.count, index < b.checkpoints.count, a.checkpoints[index] == b.checkpoints[index] else {
                return index
            }
        }
        return nil
    }

    public static func write(_ file: CheckpointFile, to url: URL) throws {
        var bytes = CheckpointFile.magic
        bytes.appendLittleEndian(CheckpointFile.version)
        bytes.append(file.granularity.rawValue)
        bytes.append(0)
        bytes.appendLittleEndian(file.window)
        bytes.appendLittleEndian(file.recordCount)
        bytes.appendLittleEndian(UInt32(file.checkpoints.count))
        for checkpoint in file.checkpoints {
            bytes.appendLittleEndian(checkpoint.endIndex)
            bytes.appendLittleEndian(checkpoint.checksum)
        }
        try Data(bytes).write(to: url, options: .atomic)
    }

    public static func read(_ url: URL) throws -> CheckpointFile {
        let bytes = [UInt8](try Data(contentsOf: url))
        guard bytes.count >= 24, Array(bytes[0..<4]) == CheckpointFile.magic else { throw TraceError.notATrace }
        func load<Integer: FixedWidthInteger>(_ type: Integer.Type, _ index: Int) -> Integer {
            bytes.withUnsafeBytes { Integer(littleEndian: $0.loadUnaligned(fromByteOffset: index, as: Integer.self)) }
        }
        let version: UInt16 = load(UInt16.self, 4)
        guard version == CheckpointFile.version else { throw TraceError.unsupportedVersion(version) }
        guard let granularity = TraceGranularity(rawValue: bytes[6]) else { throw TraceError.notATrace }
        let count = Int(load(UInt32.self, 20))
        guard bytes.count == 24 + count * 16 else { throw TraceError.truncated(offset: bytes.count) }
        let checkpoints = (0..<count).map { entry in
            Checkpoint(endIndex: load(UInt64.self, 24 + entry * 16), checksum: load(UInt64.self, 24 + entry * 16 + 8))
        }
        return CheckpointFile(granularity: granularity, window: load(UInt32.self, 8), recordCount: load(UInt64.self, 12), checkpoints: checkpoints)
    }
}
