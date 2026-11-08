// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2019 Pedro Cortés
// SPDX-FileCopyrightText: 2026 iStation contributors
// Ported from BluestormDNA/ProjectPSX/ProjectPSX/Core/BUS.cs — Copyright (c) 2019 Pedro Cortés

/// Memory control: the expansion and device delay/size registers (0x1F801000–0x1F801020), RAM_SIZE
/// (0x1F801060) and the cache control register (0xFFFE0130), and the load timings they set.
///
/// ProjectPSX keeps these registers as plain memory and charges no time for a load. The timings here
/// are psx-spx's ("Memory Control": the delay/size bits and COM_DELAY's formula) for the regions those
/// registers govern, and ps1-tests' `access-time` log, recorded on hardware, for the rest.
public struct MemoryControl: Sendable {
    /// 0x1F801000 + 4 × index: EXP1 base, EXP2 base, then the delay/size of DEV0 (EXP1), DEV1 (EXP3),
    /// DEV2 (BIOS), DEV4 (SPU), DEV5 (CD-ROM), DEV8 (EXP2), and COM_DELAY.
    public private(set) var registers: [UInt32]
    /// 0x1F801060: the RAM window. The BIOS sets 0x0B88 (8 MB, the 2 MB mirrored four times).
    public var ramSize: UInt32 = 0x0000_0B88
    /// 0xFFFE0130.
    public var cacheControl: UInt32 = 0

    /// Each governed region's load times, in cycles, by width.
    public private(set) var exp1 = AccessTimes()
    public private(set) var exp2 = AccessTimes()
    public private(set) var exp3 = AccessTimes()
    public private(set) var bios = AccessTimes()
    public private(set) var spu = AccessTimes()
    public private(set) var cdrom = AccessTimes()

    /// A load's whole cost, by width: what ps1-tests' `access-time` measures for one load.
    public struct AccessTimes: Equatable, Sendable {
        public var byte = 1
        public var halfword = 1
        public var word = 1

        public init(byte: Int = 1, halfword: Int = 1, word: Int = 1) {
            self.byte = byte
            self.halfword = halfword
            self.word = word
        }

        @inlinable
        public subscript(width: Int) -> Int { width == 1 ? byte : width == 2 ? halfword : word }
    }

    // The regions no delay register governs, from the hardware log: RAM about 5 cycles a load at every
    // width, the scratchpad 1, the I/O ports 3, the cache control register 1 or 2.
    public static let ram = AccessTimes(byte: 5, halfword: 5, word: 5)
    public static let scratchpad = AccessTimes(byte: 1, halfword: 1, word: 1)
    public static let io = AccessTimes(byte: 3, halfword: 3, word: 3)
    public static let cacheControlTimes = AccessTimes(byte: 1, halfword: 2, word: 2)

    /// The values the BIOS writes at boot (psx-spx's "usually" values). The registers' state before
    /// those writes, the slowest timings, isn't modelled: the BIOS's first stores set them.
    public init() {
        registers = [0x1F00_0000, 0x1F80_2000, 0x0013_243F, 0x0000_3022, 0x0013_243F, 0x2009_31E1, 0x0002_0843, 0x0007_0777, 0x0003_1125]
        recompute()
    }

    /// Register `index` (0–8), as a 32-bit read sees it.
    public func register(_ index: Int) -> UInt32 { registers[index] }

    public mutating func setRegister(_ index: Int, _ value: UInt32) {
        switch index {
        case 0, 1: registers[index] = 0x1F00_0000 | value & 0x00FF_FFFF // bits 24–31 are fixed
        case 8: registers[index] = value & 0xFFFF // COM_DELAY's top half reads 0
        default: registers[index] = value & ~UInt32(0x00E0_0000) // bits 21–23 always read 0
        }
        recompute()
    }

    mutating func recompute() {
        let com = registers[8]
        exp1 = Self.times(delaySize: registers[2], comDelay: com)
        exp3 = Self.times(delaySize: registers[3], comDelay: com)
        bios = Self.times(delaySize: registers[4], comDelay: com)
        spu = Self.times(delaySize: registers[5], comDelay: com)
        cdrom = Self.times(delaySize: registers[6], comDelay: com)
        exp2 = Self.times(delaySize: registers[7], comDelay: com)
    }

    /// psx-spx's formula, which it gives as approximate: the first access and each sequential one,
    /// from the read delay and the COM_DELAY periods the region uses; a load wider than the region's
    /// bus (8 or 16 bits) is one first access and then sequential ones.
    public static func times(delaySize d: UInt32, comDelay c: UInt32) -> AccessTimes {
        let accessTime = Int((d >> 4) & 0xF)
        let com0 = Int(c & 0xF), com2 = Int((c >> 8) & 0xF), com3 = Int((c >> 12) & 0xF)
        var first = 0, sequential = 0, minimum = 0
        if d & 0x100 != 0 {
            first += com0 - 1
            sequential += com0 - 1
        }
        if d & 0x400 != 0 {
            first += com2
            sequential += com2
        }
        if d & 0x800 != 0 { minimum = com3 }
        if first < 6 { first += 1 }
        first += accessTime + 2
        sequential += accessTime + 2
        first = max(first, minimum + 6)
        sequential = max(sequential, minimum + 2)

        let busBytes = d & 0x1000 != 0 ? 2 : 1
        func total(_ width: Int) -> Int { first + sequential * (max(width / busBytes, 1) - 1) }
        return AccessTimes(byte: total(1), halfword: total(2), word: total(4))
    }
}
