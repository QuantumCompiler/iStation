import Foundation

/// What a trace records: one record per instruction, or one per frame.
public enum TraceGranularity: UInt8, Sendable {
    case instruction = 1
    case frame = 2
}

/// A trace file's 16-byte header (reference/trace-formats.md).
public struct TraceHeader: Equatable, Sendable {
    public static let magic: [UInt8] = Array("ISTR".utf8)
    public static let version: UInt16 = 1
    static let size = 16

    public var granularity: TraceGranularity
    /// Instruction traces: a full-state record after every this many instruction records; 0 for none.
    public var fullStateInterval: UInt32

    public init(granularity: TraceGranularity, fullStateInterval: UInt32 = 0) {
        self.granularity = granularity
        self.fullStateInterval = fullStateInterval
    }
}

/// One record of any kind.
public enum TraceRecord: Equatable, Sendable {
    case instruction(InstructionRecord)
    case fullState(FullStateRecord)
    case frame(FrameRecord)
}

public enum TraceError: Error, Equatable {
    /// The file is empty, too short for a header, or doesn't start with "ISTR".
    case notATrace
    case unsupportedVersion(UInt16)
    /// A record starting at this byte offset runs past the end of the file.
    case truncated(offset: Int)
    /// A record tag that isn't 0x01, 0x02 or 0x03, at this byte offset.
    case unknownRecord(tag: UInt8, offset: Int)
    /// Two traces compared or reduced together record at different granularities.
    case granularityMismatch
    case cannotCreate(path: String)
}

// MARK: - Encoding

extension TraceHeader {
    func encode(into bytes: inout [UInt8]) {
        bytes += Self.magic
        bytes.appendLittleEndian(Self.version)
        bytes.append(granularity.rawValue)
        bytes.append(0)
        bytes.appendLittleEndian(fullStateInterval)
        bytes.appendLittleEndian(UInt32(0))
    }
}

extension TraceRecord {
    /// The record's bytes: its tag, then its payload, little-endian.
    func encode(into bytes: inout [UInt8]) {
        switch self {
        case .instruction(let record):
            bytes.append(InstructionRecord.tag)
            bytes.appendLittleEndian(record.pc)
            bytes.appendLittleEndian(record.word)
            bytes.appendLittleEndian(record.cycles)
            bytes.appendLittleEndian(record.registerChecksum)
        case .fullState(let record):
            bytes.append(FullStateRecord.tag)
            bytes.appendLittleEndian(record.cycles)
            bytes.appendLittleEndian(record.pc)
            for register in record.gpr { bytes.appendLittleEndian(register) }
            for word in [record.hi, record.lo, record.sr, record.cause, record.epc] { bytes.appendLittleEndian(word) }
        case .frame(let record):
            bytes.append(FrameRecord.tag)
            bytes.appendLittleEndian(record.frame)
            bytes.appendLittleEndian(record.ramChecksum)
            bytes.appendLittleEndian(record.imageChecksum)
            bytes.appendLittleEndian(record.audioChecksum)
        }
    }
}

extension Array where Element == UInt8 {
    mutating func appendLittleEndian<Integer: FixedWidthInteger>(_ value: Integer) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}

// MARK: - Writing

/// Writes a trace file through a 1 MB buffer. Call `finish()` to flush and close it.
public final class TraceWriter {
    public let header: TraceHeader
    /// Records appended so far.
    public private(set) var recordCount = 0

    private let handle: FileHandle
    private var buffer: [UInt8] = []
    private static let flushThreshold = 1 << 20

    public init(url: URL, header: TraceHeader) throws {
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
            throw TraceError.cannotCreate(path: url.path)
        }
        handle = try FileHandle(forWritingTo: url)
        self.header = header
        buffer.reserveCapacity(Self.flushThreshold + 256)
        header.encode(into: &buffer)
    }

    public func append(_ record: InstructionRecord) throws {
        buffer.append(InstructionRecord.tag)
        buffer.appendLittleEndian(record.pc)
        buffer.appendLittleEndian(record.word)
        buffer.appendLittleEndian(record.cycles)
        buffer.appendLittleEndian(record.registerChecksum)
        try recorded()
    }

    public func append(_ record: FullStateRecord) throws {
        TraceRecord.fullState(record).encode(into: &buffer)
        try recorded()
    }

    public func append(_ record: FrameRecord) throws {
        TraceRecord.frame(record).encode(into: &buffer)
        try recorded()
    }

    public func append(_ record: TraceRecord) throws {
        record.encode(into: &buffer)
        try recorded()
    }

    /// Writes what is buffered and closes the file.
    public func finish() throws {
        try flush()
        try handle.close()
    }

    private func recorded() throws {
        recordCount += 1
        if buffer.count >= Self.flushThreshold { try flush() }
    }

    private func flush() throws {
        guard !buffer.isEmpty else { return }
        try buffer.withUnsafeBytes { try handle.write(contentsOf: $0) }
        buffer.removeAll(keepingCapacity: true)
    }
}

// MARK: - Reading

/// Reads a trace file one record at a time, through a 1 MB buffer. A truncated or foreign file is
/// a thrown `TraceError`, never a trap.
public final class TraceReader {
    public let header: TraceHeader

    private let handle: FileHandle
    private var buffer: [UInt8] = []
    /// The next unread byte in `buffer`.
    private var position = 0
    /// The file offset of `buffer[0]`.
    private var bufferOffset = 0
    private var atEnd = false
    private static let chunkSize = 1 << 20

    public init(url: URL) throws {
        handle = try FileHandle(forReadingFrom: url)
        var bytes: [UInt8] = []
        while bytes.count < TraceHeader.size, let chunk = try handle.read(upToCount: Self.chunkSize), !chunk.isEmpty {
            bytes += chunk
        }
        guard bytes.count >= TraceHeader.size, Array(bytes[0..<4]) == TraceHeader.magic else {
            try? handle.close()
            throw TraceError.notATrace
        }
        buffer = bytes
        let version = UInt16(bytes[4]) | UInt16(bytes[5]) << 8
        guard version == TraceHeader.version else {
            try? handle.close()
            throw TraceError.unsupportedVersion(version)
        }
        guard let granularity = TraceGranularity(rawValue: bytes[6]) else {
            try? handle.close()
            throw TraceError.notATrace
        }
        header = TraceHeader(granularity: granularity, fullStateInterval: Self.load(UInt32.self, from: bytes, at: 8))
        position = TraceHeader.size
    }

    deinit {
        try? handle.close()
    }

    /// The next record, or nil at the end of the file.
    public func next() throws -> TraceRecord? {
        try fill(atLeast: 1)
        guard available > 0 else { return nil }
        let offset = bufferOffset + position
        let tag = buffer[position]
        let payloadSize: Int
        switch tag {
        case InstructionRecord.tag: payloadSize = InstructionRecord.payloadSize
        case FullStateRecord.tag: payloadSize = FullStateRecord.payloadSize
        case FrameRecord.tag: payloadSize = FrameRecord.payloadSize
        default: throw TraceError.unknownRecord(tag: tag, offset: offset)
        }
        try fill(atLeast: 1 + payloadSize)
        guard available >= 1 + payloadSize else { throw TraceError.truncated(offset: offset) }
        let start = position + 1
        position += 1 + payloadSize
        switch tag {
        case InstructionRecord.tag:
            return .instruction(InstructionRecord(
                pc: load(UInt32.self, at: start), word: load(UInt32.self, at: start + 4),
                cycles: load(UInt64.self, at: start + 8), registerChecksum: load(UInt64.self, at: start + 16)
            ))
        case FullStateRecord.tag:
            let gpr = (0..<32).map { load(UInt32.self, at: start + 12 + $0 * 4) }
            let tail = start + 12 + 128
            return .fullState(FullStateRecord(
                cycles: load(UInt64.self, at: start), pc: load(UInt32.self, at: start + 8), gpr: gpr,
                hi: load(UInt32.self, at: tail), lo: load(UInt32.self, at: tail + 4), sr: load(UInt32.self, at: tail + 8),
                cause: load(UInt32.self, at: tail + 12), epc: load(UInt32.self, at: tail + 16)
            ))
        default:
            return .frame(FrameRecord(
                frame: load(UInt64.self, at: start), ramChecksum: load(UInt64.self, at: start + 8),
                imageChecksum: load(UInt64.self, at: start + 16), audioChecksum: load(UInt64.self, at: start + 24)
            ))
        }
    }

    /// Every remaining record. For tests and small traces; large ones are read with `next()`.
    public func readAll() throws -> [TraceRecord] {
        var records: [TraceRecord] = []
        while let record = try next() { records.append(record) }
        return records
    }

    private var available: Int { buffer.count - position }

    private func fill(atLeast count: Int) throws {
        guard available < count, !atEnd else { return }
        buffer.removeFirst(position)
        bufferOffset += position
        position = 0
        while buffer.count < count, !atEnd {
            if let chunk = try handle.read(upToCount: Self.chunkSize), !chunk.isEmpty {
                buffer += chunk
            } else {
                atEnd = true
            }
        }
    }

    private func load<Integer: FixedWidthInteger>(_ type: Integer.Type, at index: Int) -> Integer {
        Self.load(type, from: buffer, at: index)
    }

    private static func load<Integer: FixedWidthInteger>(_ type: Integer.Type, from bytes: [UInt8], at index: Int) -> Integer {
        bytes.withUnsafeBytes { Integer(littleEndian: $0.loadUnaligned(fromByteOffset: index, as: Integer.self)) }
    }
}
