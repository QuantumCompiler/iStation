// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

// istation-run — the Swift PS1 console from the command line, with TraceKit recording.
//
//   istation-run cpu-check-image <out>          the CPU-check program, as a 512 KB image built here
//   istation-run run --bios <image> [--exe <file>] [--frames <n>] [--instructions <trace>]
//                    [--full-state-interval <n>] [--frame-trace <trace>] [--tty <file>]
//   istation-run diff <left> <right> [--ignore-cycles] [--min-records <n>]
//   istation-run frames <trace>…                 frame traces side by side: one line per frame
//
// Exit status: 0 done (diff: the traces agree), 1 diff found a divergence or a trace too short,
// 2 the arguments or a file were wrong, 3 run's EXE never started (the BIOS didn't reach its shell) —
// with a message on stderr.
//
// The BIOS is the caller's — the user's own dump, or an image built in code — and is never copied.

import BusinessPS1
import BusinessR3000A
import DataTracing
import Foundation

/// Something that knows how many instructions it has seen.
protocol Counting: R3000ATracer {
    var count: UInt64 { get }
}

/// Counts instructions, for a run's instructions per second.
struct Counter: Counting {
    static var isEnabled: Bool { true }
    var count: UInt64 = 0

    mutating func retired(_ instruction: RetiredInstruction) { count &+= 1 }
}

/// Writes TraceKit's instruction records, and a full-state record every `interval` of them.
struct Recorder: Counting {
    static var isEnabled: Bool { true }
    let writer: TraceWriter
    let interval: UInt32
    var count: UInt64 = 0
    var sinceFullState: UInt32 = 0
    var failure: (any Error)?

    mutating func retired(_ instruction: RetiredInstruction) {
        count &+= 1
        guard failure == nil else { return }
        let gpr = UnsafeBufferPointer(start: instruction.gpr, count: 32)
        do {
            try writer.append(InstructionRecord(
                pc: instruction.pc, word: instruction.word, cycles: instruction.cycles,
                registerChecksum: RegisterChecksum.of(gpr: gpr, hi: instruction.hi, lo: instruction.lo,
                                                      sr: instruction.sr, cause: instruction.cause, epc: instruction.epc)
            ))
            guard interval > 0 else { return }
            sinceFullState += 1
            if sinceFullState == interval {
                sinceFullState = 0
                try writer.append(FullStateRecord(cycles: instruction.cycles, pc: instruction.pc, gpr: Array(gpr), hi: instruction.hi,
                                                  lo: instruction.lo, sr: instruction.sr, cause: instruction.cause, epc: instruction.epc))
            }
        } catch {
            failure = error
        }
    }
}

func fail(_ message: String, status: Int32 = 2) -> Never {
    fflush(stdout) // what was printed comes first, apart from the message
    FileHandle.standardError.write(Data(("istation-run: " + message + "\n").utf8))
    exit(status)
}

/// The `--name value` options, each one of `known`: a misspelled one is an error, never ignored.
func options(_ arguments: ArraySlice<String>, known: Set<String>) -> [String: String] {
    var options: [String: String] = [:]
    var rest = arguments
    while let flag = rest.popFirst() {
        guard flag.hasPrefix("--") else { fail("unexpected argument: \(flag)") }
        guard known.contains(String(flag.dropFirst(2))) else { fail("unknown option: \(flag)") }
        if flag == "--ignore-cycles" {
            options[String(flag.dropFirst(2))] = "1"
        } else {
            guard let value = rest.popFirst() else { fail("\(flag) needs a value") }
            options[String(flag.dropFirst(2))] = value
        }
    }
    return options
}

/// A numeric option: its default when absent, and a failure, never a default, when it isn't a whole
/// number of at least 0.
func number<Value: FixedWidthInteger>(_ options: [String: String], _ name: String, default value: Value) -> Value {
    guard let text = options[name] else { return value }
    guard let parsed = Value(text), parsed >= 0 else { fail("--\(name) needs a whole number of at least 0, not \(text)") }
    return parsed
}

func run<Tracer: Counting>(_ options: [String: String], bios: [UInt8], tracer: Tracer) throws -> PS1Machine<Tracer> {
    let machine = try PS1Machine(bios: bios, tracer: tracer, capturesBIOSPutchar: options["tty"] != nil)
    if let path = options["exe"] {
        machine.boot(try PSEXE(bytes: Array(try Data(contentsOf: URL(fileURLWithPath: path)))))
    }
    let frames: Int = number(options, "frames", default: 60)
    let frameWriter = try options["frame-trace"].map {
        try TraceWriter(url: URL(fileURLWithPath: $0), header: TraceHeader(granularity: .frame))
    }
    // Only the console's own time counts toward the rate: a frame record's 2 MB checksum is the tool's.
    var emulation = Duration.zero
    for frame in 0..<frames {
        let start = ContinuousClock.now
        machine.runFrame()
        emulation += ContinuousClock.now - start
        try frameWriter?.append(FrameRecord(
            frame: UInt64(frame),
            ramChecksum: machine.bus.withRAM { ram in var hash = FNV1a64(); hash.add(bytes: ram); return hash.value },
            imageChecksum: 0, audioChecksum: 0
        ))
    }
    try frameWriter?.finish()
    // With an EXE, its TTY starts where it does: the BIOS's own messages aren't the program's output,
    // and an EXE that never started printed nothing.
    if let path = options["tty"] {
        let tty = options["exe"] == nil ? machine.tty : machine.bootIsPending ? "" : machine.ttySinceEXE
        try Data(tty.utf8).write(to: URL(fileURLWithPath: path))
    }
    let instructions = machine.cpu.tracer.count
    let seconds = Double(emulation.components.seconds) + Double(emulation.components.attoseconds) / 1e18
    let rate = seconds > 0 ? Double(instructions) / seconds / 1e6 : 0
    FileHandle.standardError.write(Data("[istation-run] \(frames) frames, \(instructions) instructions, \(machine.cpu.cycles) CPU cycles, \(machine.cycles) system cycles, \(String(format: "%.3f", seconds)) s emulating, \(Int(rate.rounded())) M instructions/s\n".utf8))
    return machine
}

/// An EXE given to `run` never started: the BIOS didn't reach its shell in the frames run.
func neverStarted(_ options: [String: String]) -> Never {
    fail("the EXE never started: the BIOS didn't reach its shell in \(options["frames"] ?? "60") frames", status: 3)
}

/// Records in a trace, streamed: a boot's trace runs to gigabytes.
func count(_ path: String) throws -> Int {
    let reader = try TraceReader(url: URL(fileURLWithPath: path))
    var count = 0
    while try reader.next() != nil { count += 1 }
    return count
}

let arguments = CommandLine.arguments.dropFirst()
do {
    switch arguments.first {
    case "cpu-check-image":
        guard let path = arguments.dropFirst().first else { fail("usage: istation-run cpu-check-image <out>") }
        try Data(CPUCheck.image).write(to: URL(fileURLWithPath: path))

    case "run":
        let options = options(arguments.dropFirst(), known: ["bios", "exe", "frames", "instructions", "full-state-interval", "frame-trace", "tty"])
        guard let biosPath = options["bios"] else { fail("usage: istation-run run --bios <image> …") }
        let bios = Array(try Data(contentsOf: URL(fileURLWithPath: biosPath)))
        if let path = options["instructions"] {
            let interval: UInt32 = number(options, "full-state-interval", default: 0)
            let writer = try TraceWriter(url: URL(fileURLWithPath: path), header: TraceHeader(granularity: .instruction, fullStateInterval: interval))
            let machine = try run(options, bios: bios, tracer: Recorder(writer: writer, interval: interval))
            if let failure = machine.cpu.tracer.failure { throw failure }
            try writer.finish()
            if machine.bootIsPending { neverStarted(options) }
        } else {
            if try run(options, bios: bios, tracer: Counter()).bootIsPending { neverStarted(options) }
        }

    case "diff":
        let rest = Array(arguments.dropFirst())
        guard rest.count >= 2 else { fail("usage: istation-run diff <left> <right> [--ignore-cycles] [--min-records <n>]") }
        let flags = options(rest.dropFirst(2), known: ["ignore-cycles", "min-records"])
        let ignoringCycles = flags["ignore-cycles"] != nil
        let minimum: Int = number(flags, "min-records", default: 0)
        let left = try count(rest[0]), right = try count(rest[1])
        // Agreeing to the shorter trace's end proves nothing if it barely started.
        if min(left, right) < minimum {
            print("too short: \(left) and \(right) records, fewer than \(minimum)")
            exit(1)
        }
        if let divergence = try TraceDiff.firstDivergence(URL(fileURLWithPath: rest[0]), URL(fileURLWithPath: rest[1]), ignoringCycles: ignoringCycles) {
            let end = divergence.index == min(left, right) && left != right
            print("\(end ? "agree to the shorter's end" : "first divergence") at record \(divergence.index) of \(left) and \(right): \(divergence.fields.joined(separator: ", "))")
            print("  left:  \(divergence.left.map { "\($0)" } ?? "—")")
            print("  right: \(divergence.right.map { "\($0)" } ?? "—")")
            exit(end ? 0 : 1)
        }
        print("identical: \(left) records")

    case "frames":
        // One line per frame: its number, then each trace's RAM checksum in hex — "-" past a trace's end,
        // "?" where it can't be read (each named on stderr) — so one bad trace never hides the others.
        let paths = Array(arguments.dropFirst())
        guard !paths.isEmpty else { fail("usage: istation-run frames <trace>…") }
        var unreadable = false
        func unreadableTrace(_ path: String, _ why: Any) -> TraceReader? {
            FileHandle.standardError.write(Data("istation-run: \(path) can't be read: \(why)\n".utf8))
            unreadable = true
            return nil
        }
        var readers: [TraceReader?] = paths.map { path in
            do { return try TraceReader(url: URL(fileURLWithPath: path)) } catch { return unreadableTrace(path, error) }
        }
        var ended = [Bool](repeating: false, count: paths.count)
        print((["frame"] + paths.map { URL(fileURLWithPath: $0).lastPathComponent }).joined(separator: "\t"))
        var frame = 0
        while true {
            var columns: [String] = []
            for index in paths.indices {
                guard let reader = readers[index] else { columns.append("?"); continue }
                guard !ended[index] else { columns.append("-"); continue }
                do {
                    switch try reader.next() {
                    case .frame(let record)?: columns.append(String(format: "%016llx", record.ramChecksum))
                    case nil:
                        ended[index] = true
                        columns.append("-")
                    case let other?:
                        readers[index] = unreadableTrace(paths[index], "not a frame trace: \(other)")
                        columns.append("?")
                    }
                } catch {
                    readers[index] = unreadableTrace(paths[index], error)
                    columns.append("?")
                }
            }
            if columns.allSatisfy({ $0 == "-" || $0 == "?" }) { break }
            print(([String(frame)] + columns).joined(separator: "\t"))
            frame += 1
        }
        if unreadable { exit(2) }

    default:
        fail("usage: istation-run cpu-check-image <out> | run --bios <image> … | diff <left> <right> [--ignore-cycles] [--min-records <n>] | frames <trace>…")
    }
} catch {
    fail("\(error)")
}
