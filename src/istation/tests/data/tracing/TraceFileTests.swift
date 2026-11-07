import DataTracing
import Foundation
import SupportSandbox
import Testing

/// Pins reference/trace-formats.md: both encodings byte for byte, the round trip, and bad input.
@Suite struct TraceFileTests {
    private func write(_ records: [TraceRecord], header: TraceHeader, in sandbox: Sandbox, name: String = "t.trace") throws -> URL {
        let url = sandbox.url(name)
        let writer = try TraceWriter(url: url, header: header)
        for record in records { try writer.append(record) }
        try writer.finish()
        return url
    }

    @Test func anInstructionTraceIsPinnedByteForByte() throws {
        let sandbox = try Sandbox()
        let record = InstructionRecord(pc: 0xBFC0_0000, word: 0x3C08_0013, cycles: 0x0102_0304_0506_0708, registerChecksum: 0x1122_3344_5566_7788)
        let url = try write([.instruction(record)], header: TraceHeader(granularity: .instruction, fullStateInterval: 1000), in: sandbox)
        let expected: [UInt8] = [
            0x49, 0x53, 0x54, 0x52, 0x01, 0x00, 0x01, 0x00, 0xE8, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // header
            0x01, // tag
            0x00, 0x00, 0xC0, 0xBF, 0x13, 0x00, 0x08, 0x3C, // pc, word
            0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01, // cycles
            0x88, 0x77, 0x66, 0x55, 0x44, 0x33, 0x22, 0x11, // register checksum
        ]
        #expect([UInt8](try Data(contentsOf: url)) == expected)
    }

    @Test func aFrameTraceIsPinnedByteForByte() throws {
        let sandbox = try Sandbox()
        let record = FrameRecord(frame: 2, ramChecksum: 0xAA, imageChecksum: 0, audioChecksum: 0x0100)
        let url = try write([.frame(record)], header: TraceHeader(granularity: .frame), in: sandbox)
        let bytes = [UInt8](try Data(contentsOf: url))
        #expect(bytes.count == 16 + 1 + 32)
        #expect(Array(bytes[0..<8]) == [0x49, 0x53, 0x54, 0x52, 0x01, 0x00, 0x02, 0x00])
        #expect(Array(bytes[16..<33]) == [0x03, 0x02, 0, 0, 0, 0, 0, 0, 0, 0xAA, 0, 0, 0, 0, 0, 0, 0])
        #expect(Array(bytes[41..<49]) == [0x00, 0x01, 0, 0, 0, 0, 0, 0])
    }

    @Test func aFullStateRecordIs160BytesAfterItsTag() throws {
        let sandbox = try Sandbox()
        let state = FullStateRecord(cycles: 7, pc: 0x8001_0000, gpr: Array(0..<32), hi: 1, lo: 2, sr: 3, cause: 4, epc: 5)
        let url = try write([.fullState(state)], header: TraceHeader(granularity: .instruction), in: sandbox)
        let bytes = [UInt8](try Data(contentsOf: url))
        #expect(bytes.count == 16 + 1 + 160)
        #expect(bytes[16] == 0x02)
        #expect(Array(bytes[17..<29]) == [7, 0, 0, 0, 0, 0, 0, 0, 0x00, 0x00, 0x01, 0x80])
        #expect(Array(bytes[29..<33]) == [0, 0, 0, 0])         // gpr[0]
        #expect(Array(bytes[153..<157]) == [31, 0, 0, 0])      // gpr[31]
        #expect(Array(bytes[173..<177]) == [5, 0, 0, 0])       // epc, last
    }

    @Test func recordsRoundTripInOrder() throws {
        let sandbox = try Sandbox()
        let records: [TraceRecord] = [
            .instruction(InstructionRecord(pc: 0xBFC0_0000, word: 0x3C08_0013, cycles: 1, registerChecksum: 9)),
            .fullState(FullStateRecord(cycles: 2, pc: 4, gpr: Array(repeating: 0xDEAD_BEEF, count: 32), hi: 5, lo: 6, sr: 7, cause: 8, epc: 9)),
            .instruction(InstructionRecord(pc: 0xBFC0_0004, word: 0x3508_243F, cycles: 3, registerChecksum: 10)),
        ]
        let url = try write(records, header: TraceHeader(granularity: .instruction, fullStateInterval: 1), in: sandbox)
        let reader = try TraceReader(url: url)
        #expect(reader.header == TraceHeader(granularity: .instruction, fullStateInterval: 1))
        #expect(try reader.readAll() == records)
    }

    @Test func manyRecordsCrossTheBufferBoundary() throws {
        let sandbox = try Sandbox()
        let records = (0..<100_000).map { TraceRecord.instruction(InstructionRecord(pc: UInt32($0) * 4, word: UInt32($0), cycles: UInt64($0), registerChecksum: UInt64($0) &* 31)) }
        let url = try write(records, header: TraceHeader(granularity: .instruction), in: sandbox)
        #expect(try TraceReader(url: url).readAll() == records)
    }

    @Test func aTruncatedRecordIsAnErrorNamingItsOffset() throws {
        let sandbox = try Sandbox()
        let url = try write([.frame(FrameRecord(frame: 0, ramChecksum: 1, imageChecksum: 2, audioChecksum: 3))], header: TraceHeader(granularity: .frame), in: sandbox)
        var bytes = try Data(contentsOf: url)
        bytes.removeLast()
        try bytes.write(to: url)
        let reader = try TraceReader(url: url)
        #expect(throws: TraceError.truncated(offset: 16)) { try reader.next() }
    }

    @Test func foreignFilesAreRefused() throws {
        let sandbox = try Sandbox()
        let empty = try sandbox.write(Data(), to: "empty.trace")
        let text = try sandbox.write("not a trace at all, honestly", to: "text.trace")
        #expect(throws: TraceError.notATrace) { try TraceReader(url: empty) }
        #expect(throws: TraceError.notATrace) { try TraceReader(url: text) }
    }

    @Test func aNewerVersionAndAnUnknownTagAreRefused() throws {
        let sandbox = try Sandbox()
        let newer = try sandbox.write(Data([0x49, 0x53, 0x54, 0x52, 0x02, 0x00, 0x01, 0x00] + Array(repeating: 0, count: 8)), to: "newer.trace")
        #expect(throws: TraceError.unsupportedVersion(2)) { try TraceReader(url: newer) }
        let unknown = try sandbox.write(Data([0x49, 0x53, 0x54, 0x52, 0x01, 0x00, 0x01, 0x00] + Array(repeating: 0, count: 8) + [0x7F]), to: "unknown.trace")
        let reader = try TraceReader(url: unknown)
        #expect(throws: TraceError.unknownRecord(tag: 0x7F, offset: 16)) { try reader.next() }
    }
}
