// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import Foundation

/// Where two traces first differ, and in which fields.
public struct TraceDivergence: Equatable, Sendable {
    /// The record's position in both traces, counting from 0.
    public let index: Int
    /// The left trace's record there, or nil when the left trace ended first.
    public let left: TraceRecord?
    /// The right trace's record there, or nil when the right trace ended first.
    public let right: TraceRecord?
    /// The differing fields by name — `kind` when the records are of different kinds,
    /// `end of trace` when one trace ended first.
    public let fields: [String]
}

/// The first divergence between two traces: the bug, when one is a port and the other its reference.
public enum TraceDiff {
    /// Compares every field of every record in order. `ignoringCycles` skips cycle counts while
    /// timing is being ported; no gate uses it.
    public static func firstDivergence(_ left: URL, _ right: URL, ignoringCycles: Bool = false) throws -> TraceDivergence? {
        let leftReader = try TraceReader(url: left)
        let rightReader = try TraceReader(url: right)
        guard leftReader.header.granularity == rightReader.header.granularity else { throw TraceError.granularityMismatch }
        var index = 0
        while true {
            let a = try leftReader.next()
            let b = try rightReader.next()
            switch (a, b) {
            case (nil, nil):
                return nil
            case (let a?, let b?):
                let fields = differingFields(a, b, ignoringCycles: ignoringCycles)
                if !fields.isEmpty { return TraceDivergence(index: index, left: a, right: b, fields: fields) }
            default:
                return TraceDivergence(index: index, left: a, right: b, fields: ["end of trace"])
            }
            index += 1
        }
    }

    /// The names of the fields in which two records differ; empty when they match.
    public static func differingFields(_ a: TraceRecord, _ b: TraceRecord, ignoringCycles: Bool = false) -> [String] {
        var fields: [String] = []
        func compare<Value: Equatable>(_ name: String, _ x: Value, _ y: Value) {
            if x != y { fields.append(name) }
        }
        switch (a, b) {
        case (.instruction(let x), .instruction(let y)):
            compare("pc", x.pc, y.pc)
            compare("word", x.word, y.word)
            if !ignoringCycles { compare("cycles", x.cycles, y.cycles) }
            compare("registerChecksum", x.registerChecksum, y.registerChecksum)
        case (.fullState(let x), .fullState(let y)):
            if !ignoringCycles { compare("cycles", x.cycles, y.cycles) }
            compare("pc", x.pc, y.pc)
            for register in 0..<32 { compare("gpr[\(register)]", x.gpr[register], y.gpr[register]) }
            compare("hi", x.hi, y.hi)
            compare("lo", x.lo, y.lo)
            compare("sr", x.sr, y.sr)
            compare("cause", x.cause, y.cause)
            compare("epc", x.epc, y.epc)
        case (.frame(let x), .frame(let y)):
            compare("frame", x.frame, y.frame)
            compare("ramChecksum", x.ramChecksum, y.ramChecksum)
            compare("imageChecksum", x.imageChecksum, y.imageChecksum)
            compare("audioChecksum", x.audioChecksum, y.audioChecksum)
        default:
            fields.append("kind")
        }
        return fields
    }
}
