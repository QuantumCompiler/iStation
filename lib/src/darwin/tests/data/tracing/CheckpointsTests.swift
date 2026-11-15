// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import DataTracing
import Foundation
import SupportSandbox
import Testing

@Suite struct CheckpointsTests {
    private func trace(_ count: Int, changing changed: Int? = nil, in sandbox: Sandbox, name: String) throws -> URL {
        let url = sandbox.url(name)
        let writer = try TraceWriter(url: url, header: TraceHeader(granularity: .instruction))
        for index in 0..<count {
            let checksum = index == changed ? 0xBAD : UInt64(index)
            try writer.append(InstructionRecord(pc: UInt32(index) * 4, word: 0, cycles: UInt64(index), registerChecksum: checksum))
        }
        try writer.finish()
        return url
    }

    @Test func aTraceReducesToOneCheckpointPerWindow() throws {
        let sandbox = try Sandbox()
        let reduced = try Checkpoints.reduce(trace(1_050, in: sandbox, name: "a"), window: 100)
        #expect(reduced.recordCount == 1_050)
        #expect(reduced.checkpoints.count == 11)
        #expect(reduced.checkpoints.map(\.endIndex).prefix(2) == [100, 200])
        #expect(reduced.checkpoints.last?.endIndex == 1_050)
    }

    @Test func oneChangedRecordChangesOnlyItsWindow() throws {
        let sandbox = try Sandbox()
        let clean = try Checkpoints.reduce(trace(1_000, in: sandbox, name: "a"), window: 100)
        let changed = try Checkpoints.reduce(trace(1_000, changing: 437, in: sandbox, name: "b"), window: 100)
        #expect(try Checkpoints.firstDivergentWindow(clean, changed) == 4)
        let differing = zip(clean.checkpoints, changed.checkpoints).filter { $0 != $1 }.count
        #expect(differing == 1)
        #expect(try Checkpoints.firstDivergentWindow(clean, clean) == nil)
    }

    @Test func checkpointsRoundTripAndStaySmall() throws {
        let sandbox = try Sandbox()
        let reduced = try Checkpoints.reduce(trace(100_000, in: sandbox, name: "a"), window: 512)
        let url = sandbox.url("a.checkpoints")
        try Checkpoints.write(reduced, to: url)
        #expect(try Checkpoints.read(url) == reduced)
        #expect(try Data(contentsOf: url).count == 24 + reduced.checkpoints.count * 16) // 196 windows: 3,160 bytes
    }

    @Test func aTruncatedCheckpointFileIsRefused() throws {
        let sandbox = try Sandbox()
        let url = sandbox.url("c")
        try Checkpoints.write(Checkpoints.reduce(trace(300, in: sandbox, name: "a"), window: 100), to: url)
        var bytes = try Data(contentsOf: url)
        bytes.removeLast(3)
        try bytes.write(to: url)
        #expect(throws: TraceError.self) { try Checkpoints.read(url) }
    }
}
