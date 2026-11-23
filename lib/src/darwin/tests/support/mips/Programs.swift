// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

// Programs and memory images built in code from `MIPS`'s encodings, shared by the cores' and the
// session's tests: never Sony's BIOS, never a game.

/// Instruction words as little-endian bytes.
public func bytes(_ words: [UInt32]) -> [UInt8] {
    words.flatMap { word in (0..<4).map { UInt8(truncatingIfNeeded: word >> (8 * UInt32($0))) } }
}

/// A `size`-byte memory image with `program` at its start and zeros after it: a BIOS image, given
/// the BIOS's size.
public func image(of program: [UInt32], size: Int) -> [UInt8] {
    var image = [UInt8](repeating: 0, count: size)
    let code = bytes(program)
    image.replaceSubrange(0..<code.count, with: code)
    return image
}

/// An endless loop that ends a program: `b .` and its delay slot.
public let halt: [UInt32] = [MIPS.beq(zero, zero, -1), MIPS.nop]

/// Writes `text` to the PS1's expansion 2 TTY at 0x1F802023, one `sb` a byte; uses t0 and t1.
public func printing(_ text: String) -> [UInt32] {
    [MIPS.lui(t0, 0x1F80)] + text.utf8.flatMap { [MIPS.ori(t1, zero, Int($0)), MIPS.sb(t1, 0x2023, t0)] }
}

/// Code that stores `words` into memory at `address`, as a BIOS copies its shell to RAM; uses t0 and t1.
public func storing(_ words: [UInt32], at address: UInt32) -> [UInt32] {
    [MIPS.lui(t0, Int(address >> 16)), MIPS.ori(t0, t0, Int(address & 0xFFFF))] + words.enumerated().flatMap { index, word in
        [MIPS.lui(t1, Int(word >> 16)), MIPS.ori(t1, t1, Int(word & 0xFFFF)), MIPS.sw(t1, 4 * index, t0)]
    }
}
