// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2019 Pedro Cortés
// SPDX-FileCopyrightText: 2026 iStation contributors
// Ported from BluestormDNA/ProjectPSX/ProjectPSX/Devices/GPU/GPU.cs — Copyright (c) 2019 Pedro Cortés

/// The GPU's timing and status, without drawing (v0.1.0 draws): the scanline and frame counters that
/// raise the vertical blank, GPUSTAT, and the GP1 display commands. GP0 commands are accepted and
/// dropped; GPUREAD reads 0.
public final class GPU {
    // Every stored `var` is `@exclusivity(unchecked)`: the console ticks the GPU and reads its sync every
    // slice, and a checked access costs each of them (ADR 0015 §4).

    /// Video cycles per scanline and scanlines per field without interlace: NTSC, 3413 × 263 (psx-spx,
    /// "GPU Timings"). An interlaced field is 262.5 lines, counted as 263 and 262 in turn.
    @exclusivity(unchecked) public private(set) var horizontalTiming = 3413
    @exclusivity(unchecked) public private(set) var verticalTiming = 263
    @exclusivity(unchecked) public private(set) var scanline = 0
    /// Time into the scanline, in a unit that makes both clocks whole (`cpuCycleLength`,
    /// `videoCycleLength`), so no time is lost. ProjectPSX divides on every tick and drops the remainder.
    @exclusivity(unchecked) var lineTime = 0
    /// Whether this interlaced field is the shorter of the pair. ProjectPSX counts every field whole.
    @exclusivity(unchecked) var shortField = false

    @exclusivity(unchecked) var interlaceField = true
    @exclusivity(unchecked) var reverse = false
    @exclusivity(unchecked) var textureDisabled = false
    @exclusivity(unchecked) var horizontalResolution1: UInt32 = 0
    @exclusivity(unchecked) var horizontalResolution2: UInt32 = 0
    /// The dot clock's divider for the horizontal resolution, kept with it.
    @exclusivity(unchecked) var dotDivider = 10
    @exclusivity(unchecked) var verticalResolution480 = false
    @exclusivity(unchecked) var isPAL = false
    @exclusivity(unchecked) var is24Bit = false
    @exclusivity(unchecked) var verticalInterlace = false
    @exclusivity(unchecked) var displayDisabled = true
    @exclusivity(unchecked) var interruptRequested = false
    @exclusivity(unchecked) var dmaDirection: UInt32 = 0
    @exclusivity(unchecked) var oddLine = false
    @exclusivity(unchecked) var displayModeBits: UInt32 = 0xFFFF_FFFF
    @exclusivity(unchecked) var displayX1: UInt32 = 0x200
    @exclusivity(unchecked) var displayX2: UInt32 = 0xC00
    @exclusivity(unchecked) var displayY1: UInt32 = 0x010
    @exclusivity(unchecked) var displayY2: UInt32 = 0x100
    /// Not modelled until GP0 is (v0.1.0): the GPU is always ready.
    let readyForCommand = true
    let readyToSendVRAM = false
    let readyForDMABlock = true

    public init() {}

    // MARK: - Timing

    /// A CPU cycle and a video cycle in one unit: an NTSC console's 53.693175 MHz video clock against
    /// its 33.8688 MHz CPU clock (psx-spx, "GPU Timings"), 715909:451584 in lowest terms. ProjectPSX
    /// uses nocash's 11/7, which psx-spx gives for the PSone/PAL clock; a console runs its region's.
    static var cpuCycleLength: Int { 715_909 }
    static var videoCycleLength: Int { 451_584 }

    /// `cycles` of the CPU clock as whole video cycles, rounded down. Split in two so that no count a
    /// timer can save up overflows.
    static func videoCycles(_ cycles: Int) -> Int {
        let whole = cycles / videoCycleLength, rest = cycles % videoCycleLength
        return whole &* cpuCycleLength &+ rest &* cpuCycleLength / videoCycleLength
    }

    /// Advances by `cycles` of the CPU clock; true when a field ends, which raises the vertical blank.
    ///
    /// The interrupt comes at the field's end whatever GP1(07h)'s Y2 holds, as in ProjectPSX; psx-spx
    /// implies it follows Y2 (a Y2 past the field stops it). Kept until SwanStation's frame comparison
    /// (3g) says where it lands: the console counts frames by the same return value, so moving it needs
    /// the bus to separate the two.
    func tick(_ cycles: Int) -> Bool {
        lineTime &+= cycles &* Self.cpuCycleLength
        let lineLength = horizontalTiming &* Self.videoCycleLength
        var fieldEnded = false
        while lineTime >= lineLength {
            lineTime &-= lineLength
            scanline += 1
            if !verticalResolution480 { oddLine = scanline & 0x1 != 0 }
            if scanline >= fieldLines {
                scanline = 0
                shortField = verticalInterlace && !shortField
                if verticalInterlace && verticalResolution480 {
                    oddLine.toggle()
                    interlaceField = !oddLine
                } else if verticalInterlace {
                    // psx-spx: bit 13 is the field whenever interlace is on, 240 lines included, where
                    // `oddLine` follows the scanline instead; ProjectPSX drives it only at 480 lines.
                    interlaceField.toggle()
                }
                fieldEnded = true
            }
        }
        return fieldEnded
    }

    /// The current field's scanlines: psx-spx's 263 (NTSC) or 314 (PAL), and with interlace 262.5 or
    /// 312.5, as a longer and a shorter field in turn. ProjectPSX counts 263 or 314 either way.
    var fieldLines: Int {
        guard verticalInterlace else { return verticalTiming }
        return (isPAL ? 313 : 263) - (shortField ? 1 : 0)
    }

    /// Outside the display's vertical range: the timers' vertical blank, and GPUSTAT's bit 31 reads 0.
    var inVerticalBlank: Bool { UInt32(scanline) < displayY1 || UInt32(scanline) > displayY2 }

    /// The dot clock's divider and the blanks, for timers 0 and 1.
    var videoSync: VideoSync {
        let videoCycles = UInt32(truncatingIfNeeded: lineTime / Self.videoCycleLength)
        return VideoSync(
            dotDivider: dotDivider,
            hblank: videoCycles < displayX1 || videoCycles > displayX2,
            vblank: inVerticalBlank
        )
    }

    // MARK: - Registers

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
        // psx-spx: bit 31 is always 0 in the vertical blank; ProjectPSX reports the line's parity there too.
        status |= (oddLine && !inVerticalBlank ? 1 : 0) << 31
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
        // psx-spx: GP1(40h–FFh) mirror GP1(00h–3Fh); ProjectPSX logs them and waits for console input.
        switch (value >> 24) & 0x3F {
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
        // psx-spx: HDS2 means 368 pixels, divider 7, whatever HDS1 holds; ProjectPSX indexes its
        // five-entry table with both and runs past its end.
        dotDivider = switch (horizontalResolution2, horizontalResolution1) {
        case (1, _): 7
        case (_, 0): 10
        case (_, 1): 8
        case (_, 2): 5
        default: 4
        }
        // psx-spx: bit 13 reads 1 while interlace is off, on the v2 GPU that GPUSTAT's 0x14802000 at
        // power-on implies, and `tick` flips it field by field while interlace is on, at 240 lines or
        // 480. ProjectPSX sets it to the interlace bit, so a mode without interlace reads 0.
        interlaceField = true
        // The console runs NTSC only (the user's call, 2026-11-07); a PAL mode still counts PAL lines.
        horizontalTiming = isPAL ? 3406 : 3413
        verticalTiming = isPAL ? 314 : 263
    }
}
