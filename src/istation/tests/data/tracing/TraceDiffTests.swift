import DataTracing
import Foundation
import SupportSandbox
import Testing

@Suite struct TraceDiffTests {
    private func trace(_ records: [TraceRecord], _ name: String, in sandbox: Sandbox, granularity: TraceGranularity = .instruction) throws -> URL {
        let url = sandbox.url(name)
        let writer = try TraceWriter(url: url, header: TraceHeader(granularity: granularity))
        for record in records { try writer.append(record) }
        try writer.finish()
        return url
    }

    private func instructions(_ count: Int) -> [InstructionRecord] {
        (0..<count).map { InstructionRecord(pc: 0xBFC0_0000 + UInt32($0) * 4, word: UInt32($0), cycles: UInt64($0), registerChecksum: UInt64($0)) }
    }

    @Test func identicalTracesDoNotDiverge() throws {
        let sandbox = try Sandbox()
        let records = instructions(10).map(TraceRecord.instruction)
        #expect(try TraceDiff.firstDivergence(trace(records, "a", in: sandbox), trace(records, "b", in: sandbox)) == nil)
    }

    @Test func theFirstDivergenceNamesItsRecordAndFields() throws {
        let sandbox = try Sandbox()
        let left = instructions(10)
        var right = left
        right[3].registerChecksum = 999
        right[3].cycles = 1234
        right[7].pc = 0
        let divergence = try #require(try TraceDiff.firstDivergence(
            trace(left.map(TraceRecord.instruction), "a", in: sandbox), trace(right.map(TraceRecord.instruction), "b", in: sandbox)
        ))
        #expect(divergence.index == 3)
        #expect(divergence.fields == ["cycles", "registerChecksum"])
        #expect(divergence.left == .instruction(left[3]))
        #expect(divergence.right == .instruction(right[3]))
    }

    @Test func cyclesCanBeIgnoredWhileTimingIsPorted() throws {
        let sandbox = try Sandbox()
        let left = instructions(5)
        var right = left
        right[2].cycles += 3
        let a = try trace(left.map(TraceRecord.instruction), "a", in: sandbox)
        let b = try trace(right.map(TraceRecord.instruction), "b", in: sandbox)
        #expect(try TraceDiff.firstDivergence(a, b, ignoringCycles: true) == nil)
        #expect(try TraceDiff.firstDivergence(a, b)?.fields == ["cycles"])
    }

    @Test func aShorterTraceDivergesWhereItEnds() throws {
        let sandbox = try Sandbox()
        let records = instructions(6).map(TraceRecord.instruction)
        let divergence = try TraceDiff.firstDivergence(trace(records, "a", in: sandbox), trace(Array(records.prefix(4)), "b", in: sandbox))
        #expect(divergence?.index == 4)
        #expect(divergence?.right == nil)
        #expect(divergence?.fields == ["end of trace"])
    }

    @Test func differentKindsAndRegistersAreNamed() {
        let state = FullStateRecord(cycles: 0, pc: 0, gpr: Array(repeating: 0, count: 32), hi: 0, lo: 0, sr: 0, cause: 0, epc: 0)
        var changed = state
        changed.gpr[29] = 0x801F_FFF0
        changed.epc = 4
        #expect(TraceDiff.differingFields(.fullState(state), .fullState(changed)) == ["gpr[29]", "epc"])
        #expect(TraceDiff.differingFields(.fullState(state), .frame(FrameRecord(frame: 0, ramChecksum: 0, imageChecksum: 0, audioChecksum: 0))) == ["kind"])
    }

    @Test func tracesOfDifferentGranularitiesAreNotCompared() throws {
        let sandbox = try Sandbox()
        let a = try trace([], "a", in: sandbox, granularity: .instruction)
        let b = try trace([], "b", in: sandbox, granularity: .frame)
        #expect(throws: TraceError.granularityMismatch) { try TraceDiff.firstDivergence(a, b) }
    }
}
