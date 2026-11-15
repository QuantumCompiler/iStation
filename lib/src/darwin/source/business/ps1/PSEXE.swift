// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2019 Pedro Cortés
// SPDX-FileCopyrightText: 2026 iStation contributors
// Ported from BluestormDNA/ProjectPSX/ProjectPSX/Core/BUS.cs — Copyright (c) 2019 Pedro Cortés

/// Why a file isn't a PS-EXE.
public enum PSEXEError: Error, Equatable, Sendable {
    /// Shorter than the 2 KB header.
    case tooShort
    /// The header doesn't start with "PS-X EXE".
    case notAnEXE
}

/// A PS-X EXE: a 2 KB header, then the code and data it loads into RAM (psx-spx, "CDROM File Formats").
/// ProjectPSX's `loadEXE` reads the start, gp, destination and stack fields; iStation also honours the
/// size field and the memory fill, as psx-spx describes them.
public struct PSEXE: Equatable, Sendable {
    public static let headerSize = 0x800
    static let magic = Array("PS-X EXE".utf8)

    /// Where execution starts.
    public var pc: UInt32
    /// r28's initial value.
    public var gp: UInt32
    /// Where `text` is loaded.
    public var destination: UInt32
    /// A region to zero before starting; a size of 0 is none.
    public var fillStart: UInt32
    public var fillSize: UInt32
    /// r29's and r30's initial value is `stackBase + stackOffset`; a base of 0 leaves them to the loader.
    public var stackBase: UInt32
    public var stackOffset: UInt32
    /// The code and data.
    public var text: [UInt8]

    public init(pc: UInt32, gp: UInt32 = 0, destination: UInt32, text: [UInt8], fillStart: UInt32 = 0, fillSize: UInt32 = 0,
                stackBase: UInt32 = 0, stackOffset: UInt32 = 0) {
        self.pc = pc
        self.gp = gp
        self.destination = destination
        self.text = text
        self.fillStart = fillStart
        self.fillSize = fillSize
        self.stackBase = stackBase
        self.stackOffset = stackOffset
    }

    /// Reads an EXE file's bytes. The header's size is trusted only as far as the file goes.
    public init(bytes: [UInt8]) throws(PSEXEError) {
        guard bytes.count >= Self.headerSize else { throw .tooShort }
        guard Array(bytes[0..<8]) == Self.magic else { throw .notAnEXE }
        func word(_ offset: Int) -> UInt32 {
            UInt32(bytes[offset]) | UInt32(bytes[offset + 1]) << 8 | UInt32(bytes[offset + 2]) << 16 | UInt32(bytes[offset + 3]) << 24
        }
        // psx-spx: the header's size decides what loads; ProjectPSX copies the whole file after the header.
        let size = min(Int(word(0x1C)), bytes.count - Self.headerSize)
        self.init(
            pc: word(0x10), gp: word(0x14), destination: word(0x18),
            text: Array(bytes[Self.headerSize..<(Self.headerSize + size)]),
            fillStart: word(0x28), fillSize: word(0x2C), stackBase: word(0x30), stackOffset: word(0x34)
        )
    }

    /// The file's bytes: the header, then `text` padded to a multiple of 2 KB, as the format asks.
    public var bytes: [UInt8] {
        let padded = (text.count + Self.headerSize - 1) / Self.headerSize * Self.headerSize
        var bytes = [UInt8](repeating: 0, count: Self.headerSize + padded)
        bytes.replaceSubrange(0..<8, with: Self.magic)
        func put(_ value: UInt32, at offset: Int) {
            for byte in 0..<4 { bytes[offset + byte] = UInt8(truncatingIfNeeded: value >> (8 * UInt32(byte))) }
        }
        put(pc, at: 0x10)
        put(gp, at: 0x14)
        put(destination, at: 0x18)
        put(UInt32(padded), at: 0x1C)
        put(fillStart, at: 0x28)
        put(fillSize, at: 0x2C)
        put(stackBase, at: 0x30)
        put(stackOffset, at: 0x34)
        bytes.replaceSubrange(Self.headerSize..<(Self.headerSize + text.count), with: text)
        return bytes
    }
}
