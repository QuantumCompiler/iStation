// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2019 Pedro Cortés
// SPDX-FileCopyrightText: 2026 iStation contributors
// Ported from BluestormDNA/ProjectPSX/ProjectPSX/Core/BUS.cs — Copyright (c) 2019 Pedro Cortés

/// Memory control: the expansion and device delay/size registers (0x1F801000–0x1F801020), RAM_SIZE
/// (0x1F801060) and the cache control register (0xFFFE0130), and the load timings and region sizes
/// they set.
///
/// ProjectPSX keeps these registers as plain memory, charges no time for a load and sizes no region.
/// The timings here are psx-spx's ("Memory Control": the delay/size bits and COM_DELAY's formula) for
/// the regions those registers govern, and ps1-tests' `access-time` log, recorded on hardware, for the
/// rest; the read-backs and sizes are psx-spx's too.
public struct MemoryControl: Sendable {
    /// 0x1F801000 + 4 × index: EXP1 base, EXP2 base, then the delay/size of DEV0 (EXP1), DEV1 (EXP3),
    /// DEV2 (BIOS), DEV4 (SPU), DEV5 (CD-ROM), DEV8 (EXP2), and COM_DELAY.
    public private(set) var registers: [UInt32]
    /// 0x1F801060: the RAM window, through its bank bits 8–11 (`ramBank0Size`, `ramBank1Size`). The
    /// BIOS sets 0x0B88 (one 8 MB bank: the 2 MB mirrored four times).
    public var ramSize: UInt32 = 0x0000_0B88
    /// 0xFFFE0130, as a load reads it.
    public private(set) var cacheControl: UInt32 = 0

    /// Each governed region's load times, in cycles, by width.
    public private(set) var exp1 = AccessTimes()
    public private(set) var exp2 = AccessTimes()
    public private(set) var exp3 = AccessTimes()
    public private(set) var bios = AccessTimes()
    public private(set) var spu = AccessTimes()
    public private(set) var cdrom = AccessTimes()

    /// The bytes expansion 1 answers from its base: 1 << DEV0's size bits, up to 8 MB (psx-spx: an
    /// access that starts past them is a bus error).
    public private(set) var exp1Size: UInt32 = 0
    /// Expansion 2's bytes: 1 << DEV8's size bits, up to 8 KB.
    public private(set) var exp2Size: UInt32 = 0
    /// Expansion 3's bytes: 1 << DEV1's size bits, up to 2 MB.
    public private(set) var exp3Size: UInt32 = 0

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

    /// The values the BIOS writes at boot (psx-spx's "usually" values), as they read back. The
    /// registers' state before those writes, the slowest timings, isn't modelled: the BIOS's first
    /// stores set them.
    public init() {
        let written: [UInt32] = [0x1F00_0000, 0x1F80_2000, 0x0013_243F, 0x0000_3022, 0x0013_243F, 0x2009_31E1, 0x0002_0843, 0x0007_0777, 0x0003_1125]
        registers = written.indices.map { Self.readBack($0, written[$0]) }
        recompute()
    }

    /// Register `index` (0–8), as a 32-bit read sees it; any other index reads 0.
    public func register(_ index: Int) -> UInt32 { registers.indices.contains(index) ? registers[index] : 0 }

    /// Writes register `index` (0–8); any other index is ignored.
    public mutating func setRegister(_ index: Int, _ value: UInt32) {
        guard registers.indices.contains(index) else { return }
        registers[index] = Self.readBack(index, value)
        recompute()
    }

    /// What register `index` keeps of `value` (psx-spx's fixed bits).
    static func readBack(_ index: Int, _ value: UInt32) -> UInt32 {
        switch index {
        case 0, 1: 0x1F00_0000 | value & 0x00FF_FFFF // bits 24–31 are fixed
        case 8: value & 0xFFFF // COM_DELAY's top half reads 0, its usual 0x31125 included
        // Bits 21–23 always read 0, and bit 28, the address-error flag, is cleared by writing 1 and
        // never set here: no address error is modelled.
        default: value & ~UInt32(0x10E0_0000)
        }
    }

    /// psx-spx: bits 6 and 10 always read 0.
    public mutating func setCacheControl(_ value: UInt32) {
        cacheControl = value & ~UInt32(0x440)
    }

    /// /RAS0's bank, where the 2 MB of RAM sit, mirrored through a 4 or 8 MB bank: psx-spx's 1 MB <<
    /// (bit 9 << 1 | bit 11), so 8 MB for the BIOS's 0x0B88 and 2 MB for SetMem(2)'s 0x0888. A 1 MB
    /// bank shows the first 1 MB here; psx-spx doesn't say which.
    public var ramBank0Size: UInt32 { 0x10_0000 << ((ramSize >> 8) & 0x2 | (ramSize >> 11) & 0x1) }

    /// /RAS1's bank, which follows /RAS0's while bit 10 enables it (else 0: psx-spx's bus fault): 1 MB
    /// << (bit 8 << 1 | bit 11).
    public var ramBank1Size: UInt32 {
        ramSize & 0x400 == 0 ? 0 : 0x10_0000 << ((ramSize >> 7) & 0x2 | (ramSize >> 11) & 0x1)
    }

    mutating func recompute() {
        let com = registers[8]
        exp1 = Self.times(delaySize: registers[2], comDelay: com)
        exp3 = Self.times(delaySize: registers[3], comDelay: com)
        bios = Self.times(delaySize: registers[4], comDelay: com)
        spu = Self.times(delaySize: registers[5], comDelay: com)
        cdrom = Self.times(delaySize: registers[6], comDelay: com)
        exp2 = Self.times(delaySize: registers[7], comDelay: com)
        // psx-spx's largest sizes, DEV0's 8 MB, DEV8's 8 KB and DEV1's 2 MB, cap a larger setting,
        // which on hardware overlaps the next region and crashes.
        exp1Size = Self.size(delaySize: registers[2], maximumBits: 23)
        exp2Size = Self.size(delaySize: registers[7], maximumBits: 13)
        exp3Size = Self.size(delaySize: registers[3], maximumBits: 21)
    }

    /// The memory window bits 16–20 select: 1 << N bytes.
    static func size(delaySize d: UInt32, maximumBits: UInt32) -> UInt32 {
        1 << min((d >> 16) & 0x1F, maximumBits)
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
