// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2019 Pedro Cortés
// SPDX-FileCopyrightText: 2026 iStation contributors
// Ported from BluestormDNA/ProjectPSX/ProjectPSX/Devices/GPU/GPU.cs — Copyright (c) 2019 Pedro Cortés

/// The GPU's timing and status, without drawing (v0.1.0 draws): the scanline and frame counters that
/// raise the vertical blank, GPUSTAT, and the GP1 display commands. GP0 commands are accepted and
/// dropped; GPUREAD reads 0.
public final class GPU {
    /// Video cycles per scanline and scanlines per frame: NTSC, 3413 × 263 (psx-spx, "GPU Timings").
    public private(set) var horizontalTiming = 3413
    public private(set) var verticalTiming = 263
    public private(set) var scanline = 0
    /// Video cycles into the scanline, times 7: the video clock is the CPU's × 11/7, kept exactly.
    /// ProjectPSX divides on every tick and drops the remainder.
    var videoCyclesTimes7 = 0

    var interlaceField = true
    var reverse = false
    var textureDisabled = false
    var horizontalResolution1: UInt32 = 0
    var horizontalResolution2: UInt32 = 0
    var verticalResolution480 = false
    var isPAL = false
    var is24Bit = false
    var verticalInterlace = false
    var displayDisabled = true
    var interruptRequested = false
    var dmaDirection: UInt32 = 0
    var oddLine = false
    var displayModeBits: UInt32 = 0xFFFF_FFFF
    var displayX1: UInt32 = 0x200
    var displayX2: UInt32 = 0xC00
    var displayY1: UInt32 = 0x010
    var displayY2: UInt32 = 0x100
    /// Not modelled until GP0 is (v0.1.0): the GPU is always ready.
    let readyForCommand = true
    let readyToSendVRAM = false
    let readyForDMABlock = true

    static let dotDividers = [10, 8, 5, 4, 7]

    public init() {}

    /// Advances by `cycles` of the CPU clock; true when a frame ends, at the vertical blank.
    func tick(_ cycles: Int) -> Bool {
        videoCyclesTimes7 += cycles * 11
        var frameEnded = false
        while videoCyclesTimes7 >= horizontalTiming * 7 {
            videoCyclesTimes7 -= horizontalTiming * 7
            scanline += 1
            if !verticalResolution480 { oddLine = scanline & 0x1 != 0 }
            if scanline >= verticalTiming {
                scanline = 0
                if verticalInterlace && verticalResolution480 {
                    oddLine.toggle()
                    interlaceField = !oddLine
                }
                frameEnded = true
            }
        }
        return frameEnded
    }

    /// The dot clock's divider and the blanks, for timers 0 and 1.
    var videoSync: VideoSync {
        let videoCycles = UInt32(videoCyclesTimes7 / 7)
        return VideoSync(
            dotDivider: Self.dotDividers[Int(horizontalResolution2 << 2 | horizontalResolution1)],
            hblank: videoCycles < displayX1 || videoCycles > displayX2,
            vblank: UInt32(scanline) < displayY1 || UInt32(scanline) > displayY2
        )
    }

    /// GPUSTAT, 0x1F801814 (psx-spx's bit layout; the drawing bits 0–12 stay 0 until GP0 is modelled).
    public var status: UInt32 {
        var status: UInt32 = 0
        status |= (interlaceField ? 1 : 0) << 13
        status |= (reverse ? 1 : 0) << 14
        status |= (textureDisabled ? 1 : 0) << 15
        status |= horizontalResolution2 << 16
        status |= horizontalResolution1 << 17
        status |= (verticalResolution480 ? 1 : 0) << 19
        status |= (isPAL ? 1 : 0) << 20
        status |= (is24Bit ? 1 : 0) << 21
        status |= (verticalInterlace ? 1 : 0) << 22
        status |= (displayDisabled ? 1 : 0) << 23
        status |= (interruptRequested ? 1 : 0) << 24
        status |= (dmaRequest ? 1 : 0) << 25
        status |= (readyForCommand ? 1 : 0) << 26
        status |= (readyToSendVRAM ? 1 : 0) << 27
        status |= (readyForDMABlock ? 1 : 0) << 28
        status |= dmaDirection << 29
        status |= (oddLine ? 1 : 0) << 31
        return status
    }

    var dmaRequest: Bool {
        switch dmaDirection {
        case 0: false
        case 1, 2: readyForDMABlock
        default: readyToSendVRAM
        }
    }

    /// A word for GP0 (0x1F801810): dropped until v0.1.0 draws.
    func writeGP0(_ value: UInt32) {}

    /// GPUREAD (0x1F801810).
    func read() -> UInt32 { 0 }

    /// A GP1 command (0x1F801814): the display commands.
    func writeGP1(_ value: UInt32) {
        switch value >> 24 {
        case 0x00: reset()
        case 0x02: interruptRequested = false
        case 0x03: displayDisabled = value & 0x1 != 0
        case 0x04: dmaDirection = value & 0x3
        case 0x06:
            displayX1 = value & 0xFFF
            displayX2 = (value >> 12) & 0xFFF
        case 0x07:
            displayY1 = value & 0x3FF
            displayY2 = (value >> 10) & 0x3FF
        case 0x08: setDisplayMode(value)
        default: break
        }
    }

    /// GP1(00h): psx-spx's reset, after which GPUSTAT reads 0x14802000.
    func reset() {
        interruptRequested = false
        displayDisabled = true
        dmaDirection = 0
        displayX1 = 0x200
        displayX2 = 0xC00
        displayY1 = 0x010
        displayY2 = 0x100
        setDisplayMode(0)
        interlaceField = true
    }

    func setDisplayMode(_ value: UInt32) {
        let bits = value & 0xFF_FFFF
        guard bits != displayModeBits else { return }
        displayModeBits = bits
        horizontalResolution1 = value & 0x3
        verticalResolution480 = value & 0x4 != 0
        isPAL = value & 0x8 != 0
        is24Bit = value & 0x10 != 0
        verticalInterlace = value & 0x20 != 0
        horizontalResolution2 = (value & 0x40) >> 6
        reverse = value & 0x80 != 0
        interlaceField = verticalInterlace
        // The console runs NTSC only (the user's call, 2026-11-07); a PAL mode still counts PAL lines.
        horizontalTiming = isPAL ? 3406 : 3413
        verticalTiming = isPAL ? 314 : 263
    }
}
