// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2019 Pedro Cortés
// SPDX-FileCopyrightText: 2026 iStation contributors
// Ported from BluestormDNA/ProjectPSX/ProjectPSX/Devices/DMA/DmaChannel.cs — Copyright (c) 2019 Pedro Cortés

/// The DMA controller, 0x1F801080–0x1F8010FF: seven channels (MDEC in, MDEC out, GPU, CD-ROM, SPU,
/// PIO, OTC), DPCR and DICR. Ported from ProjectPSX's `DMA.cs`, `DmaChannel.cs` and
/// `InterruptChannel.cs`: a transfer completes at once, except sync mode 1, which moves one block per
/// tick. Only OTC (the ordering-table clear) writes real data; the device channels move words to and
/// from the stubs until their devices exist.
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

    public private(set) var channels = [Channel](repeating: Channel(), count: 7)
    /// DPCR: each channel's priority and master enable.
    public private(set) var control: UInt32 = 0x0765_4321
    // DICR's fields.
    var unknownLow: UInt32 = 0
    var forceIRQ = false
    var irqEnable: UInt32 = 0
    var masterEnable = false
    var irqFlags: UInt32 = 0
    var masterFlag = false
    var edge = false

    let ram: UnsafeMutableRawPointer
    let gpu: GPU
    let spu: SPUStub

    init(ram: UnsafeMutableRawPointer, gpu: GPU, spu: SPUStub) {
        self.ram = ram
        self.gpu = gpu
        self.spu = spu
    }

    // MARK: - Registers

    /// DICR, 0x1F8010F4. psx-spx: bits 0–5 are read/write; ProjectPSX drops them.
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
        // OTC's control register reads only its start bits and a fixed bit 1 (ProjectPSX's mask).
        case 8: return channel == 6 ? channels[channel].control & 0x5000_0002 | 0x2 : channels[channel].control
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
        case 8:
            channels[channel].setControl(value)
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
        masterFlag = updatedMasterFlag
    }

    var updatedMasterFlag: Bool { forceIRQ || masterEnable && irqEnable & irqFlags != 0 }

    // MARK: - Transfers

    func isMasterEnabled(_ channel: Int) -> Bool { (control >> (3 + 4 * UInt32(channel))) & 0x1 != 0 }

    func start(_ channel: Int) {
        guard channels[channel].isActive, isMasterEnabled(channel) else { return }
        switch channels[channel].syncMode {
        case 0:
            let size = channels[channel].blockSize
            copyBlock(channel, size == 0 ? 0x1_0000 : size)
            finish(channel)
        case 1:
            // ProjectPSX's shortcut, kept: GPU-from-RAM and MDEC-in move every block at once.
            if channel == 2 && !channels[channel].toRAM || channel == 0 {
                copyBlock(channel, channels[channel].blockSize * channels[channel].blockCount)
                finish(channel)
                return
            }
            channels[channel].trigger = false
            channels[channel].pendingBlocks = channels[channel].blockCount
            transferBlockIfPending(channel)
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
        // A channel's flag is set on completion only if its enable bit is.
        if irqEnable & (1 << UInt32(channel)) != 0 { irqFlags |= 1 << UInt32(channel) }
        masterFlag = updatedMasterFlag
        edge = edge || masterFlag
    }

    func transferBlockIfPending(_ channel: Int) {
        guard channels[channel].pendingBlocks > 0 else { return }
        channels[channel].pendingBlocks -= 1
        copyBlock(channel, channels[channel].blockSize)
        if channels[channel].pendingBlocks == 0 { finish(channel) }
    }

    /// Moves pending blocks; true on DICR's master flag rising, which requests the DMA interrupt.
    func tick() -> Bool {
        for channel in 0..<7 { transferBlockIfPending(channel) }
        defer { edge = false }
        return edge
    }

    @inline(__always)
    func ramWord(_ address: UInt32) -> UInt32 {
        ram.load(fromByteOffset: Int(address & 0x1F_FFFC), as: UInt32.self).littleEndian
    }

    @inline(__always)
    func setRAMWord(_ address: UInt32, _ value: UInt32) {
        ram.storeBytes(of: value.littleEndian, toByteOffset: Int(address & 0x1F_FFFC), as: UInt32.self)
    }

    func copyBlock(_ channel: Int, _ size: UInt32) {
        var address = channels[channel].base
        if channels[channel].toRAM {
            switch channel {
            case 6:
                // OTC: a linked list running down from the base, its last entry the end marker.
                // psx-spx's entries are 24 bits; ProjectPSX writes the address unmasked.
                for _ in 0..<(size == 0 ? 0 : size - 1) {
                    setRAMWord(address, (address &- 4) & 0xFF_FFFF)
                    address &-= 4
                }
                setRAMWord(address, 0xFF_FFFF)
            case 2:
                for _ in 0..<size {
                    setRAMWord(address, gpu.read())
                    address &+= 4
                }
            case 1, 3, 4:
                // MDEC out, CD-ROM, SPU: no data until their devices exist.
                for _ in 0..<size {
                    setRAMWord(address, 0)
                    address &+= 4
                }
            default:
                break
            }
        } else {
            var words = [UInt32]()
            words.reserveCapacity(Int(size))
            var source = address & 0x1F_FFFC
            for _ in 0..<size {
                words.append(ramWord(source))
                source &+= 4
            }
            switch channel {
            case 2: for word in words { gpu.writeGP0(word) }
            case 4: words.withUnsafeBufferPointer { spu.receive($0) }
            default: break // MDEC in, until v0.2.0
            }
        }
        channels[channel].base = channels[channel].base &+ channels[channel].step &* size
    }

    /// GPU sync mode 2: a linked list of packets in RAM, each header's top byte its length in words.
    func linkedList(_ channel: Int) {
        var header: UInt32 = 0
        var hardStop: UInt32 = 0xFFFF // ProjectPSX's guard against endless lists
        while header & 0x80_0000 == 0 && hardStop != 0 {
            hardStop -= 1
            let base = channels[channel].base
            header = ramWord(base)
            let size = header >> 24
            if size > 0 {
                var address = (base &+ 4) & 0x1F_FFFC
                channels[channel].base = address
                for _ in 0..<size {
                    gpu.writeGP0(ramWord(address))
                    address &+= 4
                }
            }
            if channels[channel].base == header & 0x1F_FFFC { break } // a list that points at itself
            channels[channel].base = header & 0x1F_FFFC
        }
    }
}
