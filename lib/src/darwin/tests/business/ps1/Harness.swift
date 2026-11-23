// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import BusinessPS1
import BusinessR3000A
import SupportMIPS

// `bytes`, `image(of:size:)`, `halt`, `printing` and `storing` are SupportMIPS's, shared with the
// session's tests.

/// A 512 KB BIOS image built in code — never Sony's — with `program` at the reset vector: by default
/// an endless loop.
func makeBIOS(_ program: [UInt32] = halt) -> [UInt8] {
    image(of: program, size: PS1Bus.biosSize)
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
