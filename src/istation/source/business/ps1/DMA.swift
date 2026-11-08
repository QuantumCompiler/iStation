// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2019 Pedro Cortés
// SPDX-FileCopyrightText: 2026 iStation contributors
// Ported from BluestormDNA/ProjectPSX/ProjectPSX/Devices/DMA/DmaChannel.cs — Copyright (c) 2019 Pedro Cortés

/// The DMA controller, 0x1F801080–0x1F8010FF: seven channels (MDEC in, MDEC out, GPU, CD-ROM, SPU,
/// PIO, OTC), DPCR and DICR. Ported from ProjectPSX's `DMA.cs`, `DmaChannel.cs` and
/// `InterruptChannel.cs`: a transfer completes at once, except sync mode 1, which moves one block per
/// tick (GPU-from-RAM and MDEC in: up to 0x10000 words a tick). Only OTC (the ordering-table clear)
/// writes real data; the device channels move words to and from the stubs until their devices exist.
///
/// Where it departs from ProjectPSX (psx-spx decides):
/// - Words move one at a time between RAM and the device; ProjectPSX hands the device a span of RAM.
///   Nothing guest-sized is ever allocated.
/// - No store or tick moves more than 0x10000 words on a channel; ProjectPSX moves GPU-from-RAM's and
///   MDEC in's every block at once, up to 2³² words.
/// - A transfer walks memory by CHCR's step, −4 included, with a 24-bit address that writes nothing
///   past RAM's 8 MB window; ProjectPSX always counts up and folds every address into RAM.
/// - MADR and BCR end as psx-spx says: sync mode 0 keeps MADR, sync mode 1 leaves it at the end
///   address with BA counted down to 0, and sync mode 2 leaves the end marker.
/// - A block size or count of 0 means 0x10000; ProjectPSX does so only for sync mode 0.
/// - Not modelled, as in ProjectPSX: DICR's bus error flag (bit 15 on a transfer past RAM), and its
///   bits 0–6, which ask for an interrupt per block.
public final class DMA {
    /// One channel's registers.
    public struct Channel: Sendable {
        public internal(set) var base: UInt32 = 0
        public internal(set) var blockSize: UInt32 = 0
        public internal(set) var blockCount: UInt32 = 0
        var toRAM = true
        var step: UInt32 = 4
        var chopping: UInt32 = 0
        var syncMode: UInt32 = 0
        var choppingDMAWindow: UInt32 = 0
        var choppingCPUWindow: UInt32 = 0
        var enabled = false
        var trigger = false
        var unknown29: UInt32 = 0
        var unknown30: UInt32 = 0
        /// Sync mode 1's blocks still to move, up to 0x10000.
        var pendingBlocks: UInt32 = 0

        /// Sync mode 0 starts on its trigger bit; the others on the enable bit alone.
        var isActive: Bool { syncMode == 0 ? enabled && trigger : enabled }

        var control: UInt32 {
            var value: UInt32 = toRAM ? 0 : 1
            value |= (step == 4 ? 0 : 1) << 1
            value |= chopping << 8 | syncMode << 9 | choppingDMAWindow << 16 | choppingCPUWindow << 20
            value |= (enabled ? 1 : 0) << 24 | (trigger ? 1 : 0) << 28 | unknown29 << 29 | unknown30 << 30
            return value
        }

        mutating func setControl(_ value: UInt32) {
            toRAM = value & 0x1 == 0
            step = (value >> 1) & 0x1 == 0 ? 4 : UInt32(bitPattern: -4)
            chopping = (value >> 8) & 0x1
            syncMode = (value >> 9) & 0x3
            choppingDMAWindow = (value >> 16) & 0x7
            choppingCPUWindow = (value >> 20) & 0x7
            enabled = (value >> 24) & 0x1 != 0
            trigger = (value >> 28) & 0x1 != 0
            unknown29 = (value >> 29) & 0x1
            unknown30 = (value >> 30) & 0x1
            if !enabled { pendingBlocks = 0 }
        }
    }

    // Every stored `var` is `@exclusivity(unchecked)`: the console ticks the DMA every slice, and a
    // checked access costs each read (ADR 0015 §4).

    @exclusivity(unchecked) public private(set) var channels = [Channel](repeating: Channel(), count: 7)
    /// DPCR: each channel's priority and master enable.
    @exclusivity(unchecked) public private(set) var control: UInt32 = 0x0765_4321
    // DICR's fields.
    @exclusivity(unchecked) var unknownLow: UInt32 = 0
    @exclusivity(unchecked) var forceIRQ = false
    @exclusivity(unchecked) var irqEnable: UInt32 = 0
    @exclusivity(unchecked) var masterEnable = false
    @exclusivity(unchecked) var irqFlags: UInt32 = 0
    @exclusivity(unchecked) var masterFlag = false
    /// DICR's bit 31 rose since the last tick.
    @exclusivity(unchecked) var edge = false

    let ram: UnsafeMutableRawPointer
    let gpu: GPU
    let spu: SPUStub

    init(ram: UnsafeMutableRawPointer, gpu: GPU, spu: SPUStub) {
        self.ram = ram
        self.gpu = gpu
        self.spu = spu
        // psx-spx: OTC's bit 1 (step −4) is always 1, from power-on too; ProjectPSX gets it from its read
        // mask, which this file applies on the write instead.
        channels[6].setControl(0x2)
    }

    // MARK: - Registers

    /// DICR, 0x1F8010F4. Bits 0–5 are read/write on hardware (ps1-tests' io-access-bitwidth: 0x78
    /// written reads 0x38), though psx-spx lists 0–6; ProjectPSX drops them.
    public var interrupt: UInt32 {
        unknownLow | (forceIRQ ? 1 : 0) << 15 | irqEnable << 16 | (masterEnable ? 1 : 0) << 23
            | irqFlags << 24 | (masterFlag ? 1 : 0) << 31
    }

    func read(_ offset: UInt32) -> UInt32 {
        let channel = Int(offset >> 4), register = offset & 0xF
        if channel == 7 {
            switch register {
            case 0: return control
            case 4: return interrupt
            default: return 0xFFFF_FFFF
            }
        }
        switch register {
        case 0: return channels[channel].base
        case 4: return channels[channel].blockCount << 16 | channels[channel].blockSize
        // psx-spx: 0x1F8010xC mirrors CHCR, read and write; ProjectPSX reads it as 0 and drops writes.
        case 8, 0xC: return channels[channel].control
        default: return 0
        }
    }

    func write(_ offset: UInt32, _ value: UInt32) {
        let channel = Int(offset >> 4), register = offset & 0xF
        if channel == 7 {
            switch register {
            case 0: control = value
            case 4: writeInterrupt(value)
            default: break
            }
            return
        }
        switch register {
        case 0: channels[channel].base = value & 0xFF_FFFF
        case 4:
            channels[channel].blockCount = value >> 16
            channels[channel].blockSize = value & 0xFFFF
        case 8, 0xC:
            // psx-spx: OTC's CHCR keeps only bits 24, 28 and 30, and its bit 1 (step −4) is fixed;
            // ProjectPSX stores every field and masks only the read, which also drops bit 24.
            channels[channel].setControl(channel == 6 ? value & 0x5100_0000 | 0x2 : value)
            start(channel)
        default: break
        }
    }

    func writeInterrupt(_ value: UInt32) {
        unknownLow = value & 0x3F
        forceIRQ = (value >> 15) & 0x1 != 0
        irqEnable = (value >> 16) & 0x7F
        masterEnable = (value >> 23) & 0x1 != 0
        irqFlags &= ~((value >> 24) & 0x7F) // writing 1 acknowledges
        updateMasterFlag()
    }

    /// Recomputes DICR's bit 31 as psx-spx gives it, b15 or (b23 and any flag), on every write and
    /// completion; its 0-to-1 transition requests the DMA interrupt. ProjectPSX also ANDs the flags
    /// with their enables (nocash's older formula), and requests the interrupt on every completion while
    /// bit 31 is set and on no write.
    func updateMasterFlag() {
        let wasSet = masterFlag
        masterFlag = forceIRQ || masterEnable && irqFlags != 0
        if masterFlag && !wasSet { edge = true }
    }

    // MARK: - Transfers

    func isMasterEnabled(_ channel: Int) -> Bool { (control >> (3 + 4 * UInt32(channel))) & 0x1 != 0 }

    /// A BCR field's count: psx-spx's 1–0xFFFF, with 0 meaning 0x10000. ProjectPSX reads 0 as 0x10000
    /// only in sync mode 0, so a sync mode 1 count of 0 never finished.
    static func count(_ field: UInt32) -> Int { field == 0 ? 0x1_0000 : Int(field) }

    func start(_ channel: Int) {
        guard channels[channel].isActive, isMasterEnabled(channel) else { return }
        switch channels[channel].syncMode {
        case 0:
            let end = transfer(channel, words: Self.count(channels[channel].blockSize))
            // psx-spx: sync mode 0 moves MADR, and counts BC down to 0, only with chopping on;
            // ProjectPSX always moves MADR.
            if channels[channel].chopping != 0 {
                channels[channel].base = end
                channels[channel].blockSize = 0
            }
            finish(channel)
        case 1:
            channels[channel].trigger = false
            channels[channel].pendingBlocks = UInt32(Self.count(channels[channel].blockCount))
            transferBlocksIfPending(channel)
        case 2:
            linkedList(channel)
            finish(channel)
        default:
            break
        }
    }

    func finish(_ channel: Int) {
        channels[channel].enabled = false
        channels[channel].trigger = false
        // psx-spx: a completion sets its channel's flag only if both its enable bit and the master
        // enable (bit 23) are set; ProjectPSX checks the channel's bit alone.
        let bit: UInt32 = 1 << UInt32(channel)
        if masterEnable && irqEnable & bit != 0 { irqFlags |= bit }
        updateMasterFlag()
    }

    /// The most words a channel moves in one store or one tick: one block's most. It bounds the host's
    /// work for any guest store, which could otherwise ask for 0x10000 × 0x10000 words at once.
    static var wordBudget: Int { 0x1_0000 }

    /// Moves sync mode 1's next blocks: one, or on GPU-from-RAM and MDEC in as many as `wordBudget`
    /// holds. ProjectPSX moves those two channels' every block at once; here a transfer of more than
    /// 0x10000 words takes a tick per 0x10000, so a store can't hold the host for 2³² words.
    func transferBlocksIfPending(_ channel: Int) {
        let pending = channels[channel].pendingBlocks
        guard pending > 0 else { return }
        let blockWords = Self.count(channels[channel].blockSize)
        var blocks: UInt32 = 1
        if channel == 2 && !channels[channel].toRAM || channel == 0 {
            blocks = min(pending, UInt32(Self.wordBudget / blockWords)) // a block is 1–0x10000 words
        }
        channels[channel].base = transfer(channel, words: blockWords * Int(blocks))
        channels[channel].pendingBlocks = pending - blocks
        // psx-spx: MADR ends each block at the next one's start, and BA counts down to 0; ProjectPSX
        // leaves BCR as written.
        channels[channel].blockCount = (pending - blocks) & 0xFFFF
        if pending == blocks { finish(channel) }
    }

    /// Moves pending blocks; true when DICR's bit 31 rose since the last tick, which requests the DMA
    /// interrupt.
    func tick() -> Bool {
        for channel in 0..<7 { transferBlocksIfPending(channel) }
        defer { edge = false }
        return edge
    }

    // MARK: - Moving words

    /// A word from RAM at a 24-bit address, folded into its 2 MB as ProjectPSX does; psx-spx doesn't
    /// say what a read past RAM's 8 MB window returns.
    @inline(__always)
    func ramWord(_ address: UInt32) -> UInt32 {
        UInt32(littleEndian: ram.load(fromByteOffset: Int(address & 0x1F_FFFC), as: UInt32.self))
    }

    /// A word to RAM at a 24-bit address: its 8 MB window mirrors the 2 MB, and past it nothing is
    /// written (psx-spx, as when OTC counts down past 0); ProjectPSX folds it into RAM.
    @inline(__always)
    func setRAMWord(_ address: UInt32, _ value: UInt32) {
        guard address < 0x80_0000 else { return }
        ram.storeBytes(of: value.littleEndian, toByteOffset: Int(address & 0x1F_FFFC), as: UInt32.self)
    }

    /// Moves `count` words between RAM and the channel's device, one at a time, from MADR in CHCR's
    /// direction and step; returns the address after the last word, word-aligned in 24 bits (psx-spx).
    /// ProjectPSX hands the device a span of RAM, always counting up; here nothing guest-sized is built.
    func transfer(_ channel: Int, words count: Int) -> UInt32 {
        let step = channels[channel].step
        var address = channels[channel].base & 0xFF_FFFC
        guard count > 0 else { return address }
        @inline(__always) func advance() { address = (address &+ step) & 0xFF_FFFC }
        if channels[channel].toRAM {
            switch channel {
            case 6:
                // OTC: a linked list running down from the base, its last entry the end marker. psx-spx's
                // entries are 24 bits; ProjectPSX writes the address unmasked.
                for _ in 1..<count {
                    let previous = address
                    advance()
                    setRAMWord(previous, address)
                }
                setRAMWord(address, 0xFF_FFFF)
                advance()
            case 2:
                for _ in 0..<count {
                    setRAMWord(address, gpu.read())
                    advance()
                }
            case 1, 3, 4:
                // MDEC out, CD-ROM, SPU: no data until their devices exist.
                for _ in 0..<count {
                    setRAMWord(address, 0)
                    advance()
                }
            default:
                address = (address &+ step &* UInt32(truncatingIfNeeded: count)) & 0xFF_FFFC
            }
        } else {
            switch channel {
            case 2:
                for _ in 0..<count {
                    gpu.writeGP0(ramWord(address))
                    advance()
                }
            case 4:
                for _ in 0..<count {
                    let word = ramWord(address)
                    withUnsafePointer(to: word) { spu.receive(UnsafeBufferPointer(start: $0, count: 1)) }
                    advance()
                }
            default:
                // MDEC in (until v0.2.0) reads nothing: only the address moves.
                address = (address &+ step &* UInt32(truncatingIfNeeded: count)) & 0xFF_FFFC
            }
        }
        return address
    }

    /// GPU sync mode 2: a linked list of packets in RAM, each header's top byte its length in words.
    func linkedList(_ channel: Int) {
        var address = channels[channel].base
        var hardStop = 0xFFFF // ProjectPSX's guard against endless lists
        while hardStop > 0 {
            hardStop -= 1
            let header = ramWord(address)
            var current = address
            let size = header >> 24
            if size > 0 {
                current = (address &+ 4) & 0x1F_FFFC
                var word = current
                for _ in 0..<size {
                    gpu.writeGP0(ramWord(word))
                    word = (word &+ 4) & 0x1F_FFFC
                }
            }
            if header & 0x80_0000 != 0 {
                // psx-spx: MADR ends holding the end marker; ProjectPSX folds it into RAM, 0x1FFFFC.
                channels[channel].base = header & 0xFF_FFFF
                return
            }
            if current == header & 0x1F_FFFC { // a list that points at itself
                address = current
                break
            }
            address = header & 0x1F_FFFC
        }
        channels[channel].base = address
    }
}
