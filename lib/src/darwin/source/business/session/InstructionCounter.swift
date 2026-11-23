// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

#if PERSONAL_BUILD
import BusinessR3000A

/// Counts the instructions a personal build's console retires, as `istation-run`'s `Counter` does, for
/// the snapshot's instructions run. A concrete type, so the core's call per instruction is one add.
struct InstructionCounter: R3000ATracer {
    static var isEnabled: Bool { true }

    /// Instructions retired since power-on.
    var count: UInt64 = 0

    mutating func retired(_ instruction: RetiredInstruction) { count &+= 1 }
}
#endif
