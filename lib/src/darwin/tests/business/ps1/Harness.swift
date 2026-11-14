// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessPS1
import BusinessR3000A
import SupportMIPS

/// Instruction words as little-endian bytes.
func bytes(_ words: [UInt32]) -> [UInt8] {
    words.flatMap { word in (0..<4).map { UInt8(truncatingIfNeeded: word >> (8 * UInt32($0))) } }
}

/// A 512 KB BIOS image built in code — never Sony's — with `program` at the reset vector: by default
/// an endless loop.
func makeBIOS(_ program: [UInt32] = [MIPS.beq(zero, zero, -1), MIPS.nop]) -> [UInt8] {
    var image = [UInt8](repeating: 0, count: PS1Bus.biosSize)
    let code = bytes(program)
    image.replaceSubrange(0..<code.count, with: code)
    return image
}

func makeMachine(bios: [UInt8] = makeBIOS(), capturesBIOSPutchar: Bool = false) -> PS1Machine<NoTracer> {
    try! PS1Machine(bios: bios, tracer: NoTracer(), capturesBIOSPutchar: capturesBIOSPutchar)
}

/// Where test programs load: the PS-EXE convention.
let programOrigin: UInt32 = 0x8001_0000

/// A PS-EXE of `program`, loaded and started at `programOrigin`.
func makeEXE(_ program: [UInt32]) -> PSEXE {
    PSEXE(pc: programOrigin, destination: programOrigin, text: bytes(program))
}

/// Counts retired instructions.
struct CountingTracer: R3000ATracer {
    static var isEnabled: Bool { true }
    var count = 0
    mutating func retired(_ instruction: RetiredInstruction) { count += 1 }
}

/// An endless loop that ends the program: `b .` and its delay slot.
let halt: [UInt32] = [MIPS.beq(zero, zero, -1), MIPS.nop]

/// Writes `text` to expansion 2's TTY, one `sb` a byte; uses t0 and t1.
func printing(_ text: String) -> [UInt32] {
    [MIPS.lui(t0, 0x1F80)] + text.utf8.flatMap { [MIPS.ori(t1, zero, Int($0)), MIPS.sb(t1, 0x2023, t0)] }
}
