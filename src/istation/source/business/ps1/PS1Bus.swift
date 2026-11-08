// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2019 Pedro Cortés
// SPDX-FileCopyrightText: 2026 iStation contributors
// Ported from BluestormDNA/ProjectPSX/ProjectPSX/Core/BUS.cs — Copyright (c) 2019 Pedro Cortés

import BusinessR3000A

/// The PS1's memory map, as the R3000A sees it (psx-spx, "Memory Map"): 2 MB of RAM mirrored through
/// the window RAM_SIZE sets (the BIOS's 8 MB), the 1 KB scratchpad, the I/O ports, the three
/// expansion regions, the 512 KB BIOS ROM and the cache control register, each through KUSEG, KSEG0
/// and KSEG1 as ProjectPSX masks them. RAM and BIOS fetches and RAM loads and stores take the inlined
/// fast path.
///
/// Where it departs from ProjectPSX (psx-spx decides):
/// - What psx-spx leaves unmapped or locked is a bus error: past RAM_SIZE's banks, past the three
///   expansions' sizes, the gaps in the I/O region and in KSEG2, and between and beyond the regions.
///   ProjectPSX has no bus errors: it mirrors RAM through everything below 0x1F000000, its expansion
///   ROM through expansion 1, reads its memory-control bytes for 0x1F800400–0x1F80103F and a
///   nearby device for the other I/O gaps, mirrors the BIOS through 0x1F804000–0x1FC7FFFF, and reads
///   all ones from 0x1FC80000 up.
/// - The scratchpad isn't in KSEG1, and holds no code.
/// - A load costs its region's access time (`MemoryControl`), charged to the devices' clock;
///   ProjectPSX charges loads nothing and runs its devices three times faster to compensate.
/// - A fetch outside RAM and the BIOS reads that region; ProjectPSX reads the BIOS for any of them.
public final class PS1Bus: R3000ABus {
    public static let ramSize = 0x20_0000
    public static let biosSize = 0x8_0000

    @usableFromInline let ram: UnsafeMutableRawPointer
    @usableFromInline let bios: UnsafeMutableRawPointer
    let scratchpad: UnsafeMutableRawPointer

    public let interrupts = InterruptController()
    public let timers = Timers()
    public let gpu = GPU()
    public let cdrom = CDROMStub()
    public let spu = SPUStub()
    public let mdec = MDECStub()
    public let ports = PortsStub()
    public let expansion2 = Expansion2()
    public let dma: DMA
    // The stored `var`s are unchecked: every load past RAM reads them, and the dynamic check would
    // cost each one (ADR 0015 §4).
    /// The memory control registers and the timings and sizes they set.
    @exclusivity(unchecked) public internal(set) var memoryControl = MemoryControl()

    /// Load cycles beyond each instruction's own, until the console takes them for the devices' clock.
    @exclusivity(unchecked) @usableFromInline var stallCycles = 0

    /// RAM's window: /RAS0's bank, which RAM_SIZE sizes, the 2 MB mirrored through it.
    @exclusivity(unchecked) @usableFromInline var ramWindow: UInt32 = 0x0080_0000
    /// Where /RAS1's bank ends; it follows `ramWindow` while RAM_SIZE enables it.
    @exclusivity(unchecked) var ramBank1End: UInt32 = 0x0080_0000

    /// A bus over `bios`, which the console has checked is 512 KB.
    init(bios image: [UInt8]) {
        ram = .allocate(byteCount: Self.ramSize, alignment: 4)
        ram.initializeMemory(as: UInt8.self, repeating: 0, count: Self.ramSize)
        let rom = UnsafeMutableRawPointer.allocate(byteCount: Self.biosSize, alignment: 4)
        rom.initializeMemory(as: UInt8.self, repeating: 0, count: Self.biosSize)
        image.withUnsafeBytes { rom.copyMemory(from: $0.baseAddress!, byteCount: min($0.count, Self.biosSize)) }
        bios = rom
        scratchpad = .allocate(byteCount: 0x400, alignment: 4)
        scratchpad.initializeMemory(as: UInt8.self, repeating: 0, count: 0x400)
        dma = DMA(ram: ram, gpu: gpu, spu: spu)
        mapRAM()
    }

    deinit {
        ram.deallocate()
        bios.deallocate()
        scratchpad.deallocate()
    }

    /// The physical address: KSEG0 and KSEG1 fold onto the first 512 MB; KUSEG and KSEG2 pass through.
    @inlinable
    static func physical(_ address: UInt32) -> UInt32 {
        switch address >> 29 {
        case 4: address & 0x7FFF_FFFF
        case 5: address & 0x1FFF_FFFF
        default: address
        }
    }

    /// `MemoryControl.ram`'s 5 cycles, less the load's own: a literal, so the hot path reads no global.
    @inlinable static var ramStall: Int { 4 }

    /// Re-derives RAM's banks from RAM_SIZE.
    func mapRAM() {
        ramWindow = memoryControl.ramBank0Size
        ramBank1End = ramWindow + memoryControl.ramBank1Size
    }

    @inlinable
    func ramWord(_ physical: UInt32) -> UInt32 {
        UInt32(littleEndian: ram.load(fromByteOffset: Int(physical & 0x1F_FFFC), as: UInt32.self))
    }

    // MARK: - R3000ABus

    /// A fetch from RAM takes 1 cycle and from the BIOS 20, ProjectPSX's timings, so the two traces'
    /// cycle counts stay comparable.
    @inlinable
    public func fetch(_ address: UInt32) throws(BusError) -> Fetch {
        let physical = Self.physical(address)
        if physical < ramWindow { return Fetch(word: ramWord(physical), cycles: 1) }
        if physical &- 0x1FC0_0000 < UInt32(Self.biosSize) {
            return Fetch(word: UInt32(littleEndian: bios.load(fromByteOffset: Int(physical & 0x7_FFFC), as: UInt32.self)), cycles: 20)
        }
        return try slowFetch(address, physical)
    }

    @inlinable
    public func load8(_ address: UInt32) throws(BusError) -> UInt8 {
        let physical = Self.physical(address)
        if physical < ramWindow {
            stallCycles &+= Self.ramStall
            return ram.load(fromByteOffset: Int(physical & 0x1F_FFFF), as: UInt8.self)
        }
        return UInt8(truncatingIfNeeded: try slowLoad(address, physical, width: 1))
    }

    @inlinable
    public func load16(_ address: UInt32) throws(BusError) -> UInt16 {
        let physical = Self.physical(address)
        if physical < ramWindow {
            stallCycles &+= Self.ramStall
            return UInt16(littleEndian: ram.load(fromByteOffset: Int(physical & 0x1F_FFFE), as: UInt16.self))
        }
        return UInt16(truncatingIfNeeded: try slowLoad(address, physical, width: 2))
    }

    @inlinable
    public func load32(_ address: UInt32) throws(BusError) -> UInt32 {
        let physical = Self.physical(address)
        if physical < ramWindow {
            stallCycles &+= Self.ramStall
            return ramWord(physical)
        }
        return try slowLoad(address, physical, width: 4)
    }

    // Stores cost nothing: the CPU's write buffer absorbs them.

    @inlinable
    public func store8(_ address: UInt32, _ value: UInt32) throws(BusError) {
        let physical = Self.physical(address)
        if physical < ramWindow {
            ram.storeBytes(of: UInt8(truncatingIfNeeded: value), toByteOffset: Int(physical & 0x1F_FFFF), as: UInt8.self)
            return
        }
        try slowStore(address, physical, value, width: 1)
    }

    @inlinable
    public func store16(_ address: UInt32, _ value: UInt32) throws(BusError) {
        let physical = Self.physical(address)
        if physical < ramWindow {
            ram.storeBytes(of: UInt16(truncatingIfNeeded: value).littleEndian, toByteOffset: Int(physical & 0x1F_FFFE), as: UInt16.self)
            return
        }
        try slowStore(address, physical, value, width: 2)
    }

    @inlinable
    public func store32(_ address: UInt32, _ value: UInt32) throws(BusError) {
        let physical = Self.physical(address)
        if physical < ramWindow {
            ram.storeBytes(of: value.littleEndian, toByteOffset: Int(physical & 0x1F_FFFC), as: UInt32.self)
            return
        }
        try slowStore(address, physical, value, width: 4)
    }

    public var interruptPending: Bool { interrupts.isPending }

    /// RAM, the BIOS and the scratchpad answer; every device register, and nothing, is nil.
    public func peek32(_ address: UInt32) -> UInt32? {
        let physical = Self.physical(address) & ~3
        if physical < ramWindow { return ramWord(physical) }
        if physical &- 0x1FC0_0000 < UInt32(Self.biosSize) {
            return UInt32(littleEndian: bios.load(fromByteOffset: Int(physical & 0x7_FFFC), as: UInt32.self))
        }
        if physical &- 0x1F80_0000 < 0x400 && address >> 29 != 5 {
            return UInt32(littleEndian: scratchpad.load(fromByteOffset: Int(physical & 0x3FC), as: UInt32.self))
        }
        return nil
    }

    // MARK: - The console's side

    /// The load cycles charged since the last call, and none after it.
    @inlinable
    func takeStallCycles() -> Int {
        defer { stallCycles = 0 }
        return stallCycles
    }

    /// Advances the devices by `cycles`; true when a frame ended (the vertical blank).
    @usableFromInline
    func tick(_ cycles: Int) -> Bool {
        let frameEnded = gpu.tick(cycles)
        if frameEnded { interrupts.request(.vblank) }
        if dma.tick() { interrupts.request(.dma) }
        timers.sync(gpu.videoSync)
        if timers.tick(0, cycles) { interrupts.request(.timer0) }
        if timers.tick(1, cycles) { interrupts.request(.timer1) }
        if timers.tick(2, cycles) { interrupts.request(.timer2) }
        return frameEnded
    }

    /// Copies `bytes` into RAM from `address` on, wrapping at its end: for loaders.
    public func copyToRAM(_ bytes: [UInt8], at address: UInt32) {
        for (index, byte) in bytes.enumerated() {
            ram.storeBytes(of: byte, toByteOffset: Int((address &+ UInt32(truncatingIfNeeded: index)) & 0x1F_FFFF), as: UInt8.self)
        }
    }

    /// Guest RAM's 2 MB, read-only and without a load's cost: for traces and tools.
    public func withRAM<Result>(_ body: (UnsafeRawBufferPointer) throws -> Result) rethrows -> Result {
        try body(UnsafeRawBufferPointer(start: ram, count: Self.ramSize))
    }

    /// Zeroes `count` bytes of RAM from `address` on, wrapping at its end.
    public func zeroRAM(at address: UInt32, count: UInt32) {
        // Past 2 MB the wrap only zeroes again: a header's huge fill costs no more than all of RAM.
        for index in 0..<min(count, UInt32(Self.ramSize)) {
            ram.storeBytes(of: 0, toByteOffset: Int((address &+ index) & 0x1F_FFFF), as: UInt8.self)
        }
    }

    // MARK: - Everything but RAM

    @usableFromInline
    func slowFetch(_ address: UInt32, _ physical: UInt32) throws(BusError) -> Fetch {
        // psx-spx: the scratchpad holds data only.
        if physical &- 0x1F80_0000 < 0x400 { throw BusError() }
        let (word, cycles) = try read(address, physical, width: 4)
        return Fetch(word: word, cycles: cycles)
    }

    @usableFromInline
    func slowLoad(_ address: UInt32, _ physical: UInt32, width: Int) throws(BusError) -> UInt32 {
        let (value, cycles) = try read(address, physical, width: width)
        stallCycles &+= cycles - 1
        return value
    }

    static func allOnes(_ width: Int) -> UInt32 { width == 4 ? 0xFFFF_FFFF : (1 << UInt32(width * 8)) - 1 }

    /// ProjectPSX's second TTY port, kept: it answers past expansion 2's usual 128 bytes, which psx-spx
    /// locks.
    static let ttyPort: UInt32 = 0x1F80_2080

    /// A read of `width` bytes and what it costs.
    func read(_ address: UInt32, _ physical: UInt32, width: Int) throws(BusError) -> (UInt32, Int) {
        switch physical {
        case ..<0x1F00_0000:
            // Past RAM's window, which the fast path reads: an enabled /RAS1 bank, empty on a retail
            // console, reads all ones as the empty expansions do (psx-spx doesn't say); the rest is
            // psx-spx's unmapped RAM.
            guard physical < ramBank1End else { throw BusError() }
            return (Self.allOnes(width), MemoryControl.ram[width])
        case 0x1F00_0000..<0x1F80_0000:
            // Expansion 1: nothing attached, as far as DEV0's size reaches.
            guard physical - 0x1F00_0000 < memoryControl.exp1Size else { throw BusError() }
            return (Self.allOnes(width), memoryControl.exp1[width])
        case 0x1F80_0000..<0x1F80_0400:
            guard address >> 29 != 5 else { throw BusError() }
            let offset = Int(physical & 0x3FF)
            let value: UInt32 = switch width {
            case 1: UInt32(scratchpad.load(fromByteOffset: offset, as: UInt8.self))
            case 2: UInt32(UInt16(littleEndian: scratchpad.load(fromByteOffset: offset & ~1, as: UInt16.self)))
            default: UInt32(littleEndian: scratchpad.load(fromByteOffset: offset & ~3, as: UInt32.self))
            }
            return (value, MemoryControl.scratchpad[width])
        case 0x1F80_1000..<0x1F80_2000:
            return try readIO(physical - 0x1F80_1000, width: width)
        case 0x1F80_2000..<0x1F80_4000:
            guard physical - 0x1F80_2000 < memoryControl.exp2Size || physical & ~3 == Self.ttyPort else { throw BusError() }
            return (Self.allOnes(width), memoryControl.exp2[width])
        case 0x1FA0_0000..<0x1FC0_0000:
            // Expansion 3: nothing attached, as far as DEV1's size reaches; ProjectPSX reads a BIOS
            // mirror through all of it. The bound is on the access's first byte, as for the other
            // expansions: under DEV1's usual 1 byte the hardware log reads a whole word at 0x1FA00000.
            guard physical - 0x1FA0_0000 < memoryControl.exp3Size else { throw BusError() }
            return (Self.allOnes(width), memoryControl.exp3[width])
        case 0x1FC0_0000..<0x1FC8_0000:
            let offset = Int(physical & 0x7_FFFF)
            let value: UInt32 = switch width {
            case 1: UInt32(bios.load(fromByteOffset: offset, as: UInt8.self))
            case 2: UInt32(UInt16(littleEndian: bios.load(fromByteOffset: offset & ~1, as: UInt16.self)))
            default: UInt32(littleEndian: bios.load(fromByteOffset: offset & ~3, as: UInt32.self))
            }
            return (value, memoryControl.bios[width])
        case 0xFFFE_0130:
            return (memoryControl.cacheControl, MemoryControl.cacheControlTimes[width])
        case 0xFFFE_0000..<0xFFFE_0020, 0xFFFE_0100..<0xFFFE_0140:
            // psx-spx's unlocked garbage around cache control, which usually reads 0 (ProjectPSX reads
            // all ones); the rest of KSEG2 is locked.
            return (0, 1)
        default:
            throw BusError()
        }
    }

    func readIO(_ offset: UInt32, width: Int) throws(BusError) -> (UInt32, Int) {
        switch offset {
        case 0x800..<0x804:
            // An 8-bit port: a wider load reads it again for each byte (psx-spx: no auto-increment).
            let byte = UInt32(cdrom.read(offset - 0x800))
            return (width == 1 ? byte : width == 2 ? byte * 0x0101 : byte * 0x0101_0101, memoryControl.cdrom[width])
        case 0xC00..<0x1000:
            // 16-bit registers: a word load reads two (psx-spx); ProjectPSX's SPU answers one.
            let register = (offset - 0xC00) & ~UInt32(width == 4 ? 3 : 1)
            let value: UInt32 = switch width {
            case 1: (UInt32(spu.read(register)) >> ((offset & 1) * 8)) & 0xFF
            case 2: UInt32(spu.read(register))
            default: UInt32(spu.read(register)) | UInt32(spu.read(register + 2)) << 16
            }
            return (value, memoryControl.spu[width])
        default:
            // A narrow load reads its byte lane of the 32-bit slot (psx-spx: ports read at any width);
            // ProjectPSX hands the device the unaligned address, which mostly answers 0 or all ones.
            let word = try readIO32(offset & ~3) >> ((offset & 3) * 8)
            return (width == 4 ? word : word & Self.allOnes(width), MemoryControl.io[width])
        }
    }

    /// The 32-bit slot at `offset`. psx-spx's locked gaps are bus errors; its garbage halves read what
    /// the slot's register gives.
    func readIO32(_ offset: UInt32) throws(BusError) -> UInt32 {
        switch offset {
        case 0x000..<0x024: memoryControl.register(Int(offset >> 2))
        case 0x040..<0x060: ports.read(offset - 0x40)
        case 0x060: memoryControl.ramSize
        case 0x070..<0x078: interrupts.read(offset - 0x70)
        case 0x080..<0x100: dma.read(offset - 0x80)
        case 0x100..<0x140: timers.read(offset - 0x100)
        case 0x810: gpu.read()
        case 0x814: gpu.status
        case 0x820, 0x824: mdec.read(offset - 0x820)
        default: throw BusError()
        }
    }

    @usableFromInline
    func slowStore(_ address: UInt32, _ physical: UInt32, _ value: UInt32, width: Int) throws(BusError) {
        switch physical {
        case ..<0x1F00_0000:
            guard physical < ramBank1End else { throw BusError() } // an empty /RAS1 bank drops it
        case 0x1F00_0000..<0x1F80_0000:
            guard physical - 0x1F00_0000 < memoryControl.exp1Size else { throw BusError() } // nothing attached
        case 0x1FA0_0000..<0x1FC0_0000:
            guard physical - 0x1FA0_0000 < memoryControl.exp3Size else { throw BusError() } // nothing attached
        case 0x1F80_0000..<0x1F80_0400:
            guard address >> 29 != 5 else { throw BusError() }
            let offset = Int(physical & 0x3FF)
            switch width {
            case 1: scratchpad.storeBytes(of: UInt8(truncatingIfNeeded: value), toByteOffset: offset, as: UInt8.self)
            case 2: scratchpad.storeBytes(of: UInt16(truncatingIfNeeded: value).littleEndian, toByteOffset: offset & ~1, as: UInt16.self)
            default: scratchpad.storeBytes(of: value.littleEndian, toByteOffset: offset & ~3, as: UInt32.self)
            }
        case 0x1F80_1000..<0x1F80_2000:
            try writeIO(physical - 0x1F80_1000, value, width: width)
        case 0x1F80_2000..<0x1F80_4000:
            guard physical - 0x1F80_2000 < memoryControl.exp2Size || physical & ~3 == Self.ttyPort else { throw BusError() }
            expansion2.write(physical, UInt8(truncatingIfNeeded: value))
        case 0x1FC0_0000..<0x1FC8_0000:
            break // the BIOS is ROM
        case 0xFFFE_0130:
            memoryControl.setCacheControl(value)
        case 0xFFFE_0000..<0xFFFE_0020, 0xFFFE_0100..<0xFFFE_0140:
            break // psx-spx's garbage: a store has no effect
        default:
            throw BusError()
        }
    }

    func writeIO(_ offset: UInt32, _ value: UInt32, width: Int) throws(BusError) {
        switch offset {
        case 0x800..<0x804:
            // An 8-bit port: each byte of a wider store goes to the same port, lowest first.
            for byte in 0..<UInt32(width) { cdrom.write(offset - 0x800, UInt8(truncatingIfNeeded: value >> (byte * 8))) }
        case 0xC00..<0x1000:
            // psx-spx's (i16): a byte store to an odd address is ignored (ProjectPSX's SPU has no odd
            // registers either).
            if width == 1 && offset & 1 != 0 { return }
            // 16-bit registers: a byte or halfword store writes the source's low halfword, a word two
            // (psx-spx); ProjectPSX's word store writes one.
            let register = (offset - 0xC00) & ~UInt32(width == 4 ? 3 : 1)
            spu.write(register, UInt16(truncatingIfNeeded: value))
            if width == 4 { spu.write(register + 2, UInt16(truncatingIfNeeded: value >> 16)) }
        case 0x040..<0x060:
            // 16-bit registers. psx-spx: a byte store writes the source's low halfword, shifted left 8
            // at an odd address (w16), and a word store only its low halfword (CROP), as the
            // io-access-bitwidth log shows. ProjectPSX's JOYPAD ignores an odd byte, and its SIO1
            // memory takes every byte stored.
            ports.write((offset - 0x40) & ~1, UInt16(truncatingIfNeeded: value << ((offset & 1) * 8)))
        case 0x084..<0x0F0 where offset & 0xC == 0x4 && width != 4:
            // A channel's BCR takes a narrow store in its own byte lanes, like memory (psx-spx: DMAx.LEN
            // is OK at every width). ProjectPSX writes one at BCR+0 as the whole register and ignores
            // the other lanes.
            let shift = (offset & 3) * 8, mask = Self.allOnes(width) << shift, register = (offset & ~3) - 0x80
            dma.write(register, dma.read(register) & ~mask | (value << shift) & mask)
        default:
            // A 32-bit port sees a narrow store's whole source register, shifted to the store's byte
            // lane (psx-spx's (w32); ps1-tests' io-access-bitwidth shows the aligned case on hardware).
            // So a halfword store to DICR+2 clears its force-IRQ bit, which ProjectPSX keeps there.
            try writeIO32(offset & ~3, value << ((offset & 3) * 8))
        }
    }

    func writeIO32(_ offset: UInt32, _ value: UInt32) throws(BusError) {
        switch offset {
        case 0x000..<0x024: memoryControl.setRegister(Int(offset >> 2), value)
        case 0x060:
            memoryControl.ramSize = value
            mapRAM()
        case 0x070..<0x078: interrupts.write(offset - 0x70, value)
        case 0x080..<0x100: dma.write(offset - 0x80, value)
        case 0x100..<0x140: timers.write(offset - 0x100, value)
        case 0x810: gpu.writeGP0(value)
        case 0x814: gpu.writeGP1(value)
        case 0x820, 0x824: mdec.write(offset - 0x820, value)
        default: throw BusError() // psx-spx's locked gaps
        }
    }
}
