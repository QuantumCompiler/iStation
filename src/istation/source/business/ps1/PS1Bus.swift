// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2019 Pedro Cortés
// SPDX-FileCopyrightText: 2026 iStation contributors
// Ported from BluestormDNA/ProjectPSX/ProjectPSX/Core/BUS.cs — Copyright (c) 2019 Pedro Cortés

import BusinessR3000A

/// The PS1's memory map, as the R3000A sees it (psx-spx, "Memory Map"): 2 MB of RAM mirrored through
/// the BIOS's 8 MB window, the 1 KB scratchpad, the I/O ports, the three expansion regions, the
/// 512 KB BIOS ROM and the cache control register, each through KUSEG, KSEG0 and KSEG1 as ProjectPSX
/// masks them. RAM and BIOS fetches and RAM loads and stores take the inlined fast path.
///
/// Where it departs from ProjectPSX (psx-spx decides):
/// - An address nothing answers is a bus error; ProjectPSX logs it and reads all ones.
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
    public internal(set) var memoryControl = MemoryControl()

    /// Load cycles beyond each instruction's own, until the console takes them for the devices' clock.
    /// Not a checked `var`: the dynamic check would cost every load (ADR 0015 §4).
    @exclusivity(unchecked) @usableFromInline var stallCycles = 0

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

    /// RAM's 8 MB window: the 2 MB mirrored four times.
    @inlinable static var ramWindow: UInt32 { 0x0080_0000 }
    /// `MemoryControl.ram`'s 5 cycles, less the load's own: a literal, so the hot path reads no global.
    @inlinable static var ramStall: Int { 4 }

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
        if physical < Self.ramWindow { return Fetch(word: ramWord(physical), cycles: 1) }
        if physical &- 0x1FC0_0000 < UInt32(Self.biosSize) {
            return Fetch(word: UInt32(littleEndian: bios.load(fromByteOffset: Int(physical & 0x7_FFFC), as: UInt32.self)), cycles: 20)
        }
        return try slowFetch(address, physical)
    }

    @inlinable
    public func load8(_ address: UInt32) throws(BusError) -> UInt8 {
        let physical = Self.physical(address)
        if physical < Self.ramWindow {
            stallCycles &+= Self.ramStall
            return ram.load(fromByteOffset: Int(physical & 0x1F_FFFF), as: UInt8.self)
        }
        return UInt8(truncatingIfNeeded: try slowLoad(address, physical, width: 1))
    }

    @inlinable
    public func load16(_ address: UInt32) throws(BusError) -> UInt16 {
        let physical = Self.physical(address)
        if physical < Self.ramWindow {
            stallCycles &+= Self.ramStall
            return UInt16(littleEndian: ram.load(fromByteOffset: Int(physical & 0x1F_FFFE), as: UInt16.self))
        }
        return UInt16(truncatingIfNeeded: try slowLoad(address, physical, width: 2))
    }

    @inlinable
    public func load32(_ address: UInt32) throws(BusError) -> UInt32 {
        let physical = Self.physical(address)
        if physical < Self.ramWindow {
            stallCycles &+= Self.ramStall
            return ramWord(physical)
        }
        return try slowLoad(address, physical, width: 4)
    }

    // Stores cost nothing: the CPU's write buffer absorbs them.

    @inlinable
    public func store8(_ address: UInt32, _ value: UInt32) throws(BusError) {
        let physical = Self.physical(address)
        if physical < Self.ramWindow {
            ram.storeBytes(of: UInt8(truncatingIfNeeded: value), toByteOffset: Int(physical & 0x1F_FFFF), as: UInt8.self)
            return
        }
        try slowStore(address, physical, value, width: 1)
    }

    @inlinable
    public func store16(_ address: UInt32, _ value: UInt32) throws(BusError) {
        let physical = Self.physical(address)
        if physical < Self.ramWindow {
            ram.storeBytes(of: UInt16(truncatingIfNeeded: value).littleEndian, toByteOffset: Int(physical & 0x1F_FFFE), as: UInt16.self)
            return
        }
        try slowStore(address, physical, value, width: 2)
    }

    @inlinable
    public func store32(_ address: UInt32, _ value: UInt32) throws(BusError) {
        let physical = Self.physical(address)
        if physical < Self.ramWindow {
            ram.storeBytes(of: value.littleEndian, toByteOffset: Int(physical & 0x1F_FFFC), as: UInt32.self)
            return
        }
        try slowStore(address, physical, value, width: 4)
    }

    public var interruptPending: Bool { interrupts.isPending }

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

    /// Zeroes `count` bytes of RAM from `address` on, wrapping at its end.
    public func zeroRAM(at address: UInt32, count: UInt32) {
        for index in 0..<count {
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

    /// A read of `width` bytes and what it costs.
    func read(_ address: UInt32, _ physical: UInt32, width: Int) throws(BusError) -> (UInt32, Int) {
        switch physical {
        case 0x1F00_0000..<0x1F80_0000:
            return (Self.allOnes(width), memoryControl.exp1[width]) // expansion 1: nothing attached
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
            return readIO(physical - 0x1F80_1000, width: width)
        case 0x1F80_2000..<0x1F80_4000:
            return (Self.allOnes(width), memoryControl.exp2[width])
        case 0x1FA0_0000..<0x1FC0_0000:
            return (Self.allOnes(width), memoryControl.exp3[width]) // expansion 3: nothing attached
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
        case 0xFFFE_0000..<0xFFFE_0200:
            return (0, 1) // the CPU's other control registers
        default:
            throw BusError()
        }
    }

    func readIO(_ offset: UInt32, width: Int) -> (UInt32, Int) {
        switch offset {
        case 0x800..<0x804:
            // An 8-bit port: a wider load reads it again for each byte (psx-spx: no auto-increment).
            let byte = UInt32(cdrom.read(offset - 0x800))
            return (width == 1 ? byte : width == 2 ? byte * 0x0101 : byte * 0x0101_0101, memoryControl.cdrom[width])
        case 0xC00..<0x1000:
            // 16-bit registers: a word load reads two.
            let register = (offset - 0xC00) & ~1
            let value: UInt32 = switch width {
            case 1: (UInt32(spu.read(register)) >> ((offset & 1) * 8)) & 0xFF
            case 2: UInt32(spu.read(register))
            default: UInt32(spu.read(register)) | UInt32(spu.read(register + 2)) << 16
            }
            return (value, memoryControl.spu[width])
        default:
            let word = readIO32(offset & ~3) >> ((offset & 3) * 8)
            return (width == 4 ? word : word & Self.allOnes(width), MemoryControl.io[width])
        }
    }

    func readIO32(_ offset: UInt32) -> UInt32 {
        switch offset {
        case 0x000..<0x024: memoryControl.register(Int(offset >> 2))
        case 0x040..<0x060: ports.read(offset - 0x40)
        case 0x060: memoryControl.ramSize
        case 0x070..<0x080: interrupts.read(offset - 0x70)
        case 0x080..<0x100: dma.read(offset - 0x80)
        case 0x100..<0x140: timers.read(offset - 0x100)
        case 0x810: gpu.read()
        case 0x814: gpu.status
        case 0x820, 0x824: mdec.read(offset - 0x820)
        default: 0
        }
    }

    @usableFromInline
    func slowStore(_ address: UInt32, _ physical: UInt32, _ value: UInt32, width: Int) throws(BusError) {
        switch physical {
        case 0x1F00_0000..<0x1F80_0000, 0x1FA0_0000..<0x1FC0_0000:
            break // expansions 1 and 3: nothing attached
        case 0x1F80_0000..<0x1F80_0400:
            guard address >> 29 != 5 else { throw BusError() }
            let offset = Int(physical & 0x3FF)
            switch width {
            case 1: scratchpad.storeBytes(of: UInt8(truncatingIfNeeded: value), toByteOffset: offset, as: UInt8.self)
            case 2: scratchpad.storeBytes(of: UInt16(truncatingIfNeeded: value).littleEndian, toByteOffset: offset & ~1, as: UInt16.self)
            default: scratchpad.storeBytes(of: value.littleEndian, toByteOffset: offset & ~3, as: UInt32.self)
            }
        case 0x1F80_1000..<0x1F80_2000:
            writeIO(physical - 0x1F80_1000, value, width: width)
        case 0x1F80_2000..<0x1F80_4000:
            expansion2.write(physical, UInt8(truncatingIfNeeded: value))
        case 0x1FC0_0000..<0x1FC8_0000:
            break // the BIOS is ROM
        case 0xFFFE_0130:
            memoryControl.cacheControl = value
        case 0xFFFE_0000..<0xFFFE_0200:
            break
        default:
            throw BusError()
        }
    }

    func writeIO(_ offset: UInt32, _ value: UInt32, width: Int) {
        switch offset {
        case 0x800..<0x804:
            // An 8-bit port: each byte of a wider store goes to the same port, lowest first.
            for byte in 0..<UInt32(width) { cdrom.write(offset - 0x800, UInt8(truncatingIfNeeded: value >> (byte * 8))) }
        case 0xC00..<0x1000:
            // 16-bit registers: a byte or halfword store writes the source's low halfword, a word two.
            let register = (offset - 0xC00) & ~1
            spu.write(register, UInt16(truncatingIfNeeded: value))
            if width == 4 { spu.write(register + 2, UInt16(truncatingIfNeeded: value >> 16)) }
        case 0x040..<0x060:
            let register = (offset - 0x40) & ~1
            ports.write(register, UInt16(truncatingIfNeeded: value))
            if width == 4 { ports.write(register + 2, UInt16(truncatingIfNeeded: value >> 16)) }
        default:
            // A 32-bit port sees a narrow store's whole source register, shifted to the store's byte
            // lane (ps1-tests' io-access-bitwidth shows the aligned case on hardware).
            writeIO32(offset & ~3, value << ((offset & 3) * 8))
        }
    }

    func writeIO32(_ offset: UInt32, _ value: UInt32) {
        switch offset {
        case 0x000..<0x024: memoryControl.setRegister(Int(offset >> 2), value)
        case 0x060: memoryControl.ramSize = value
        case 0x070..<0x080: interrupts.write(offset - 0x70, value)
        case 0x080..<0x100: dma.write(offset - 0x80, value)
        case 0x100..<0x140: timers.write(offset - 0x100, value)
        case 0x810: gpu.writeGP0(value)
        case 0x814: gpu.writeGP1(value)
        case 0x820, 0x824: mdec.write(offset - 0x820, value)
        default: break
        }
    }
}
