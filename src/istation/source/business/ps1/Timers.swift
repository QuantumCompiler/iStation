// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2019 Pedro Cortés
// SPDX-FileCopyrightText: 2026 iStation contributors
// Ported from BluestormDNA/ProjectPSX/ProjectPSX/Devices/TIMERS.cs — Copyright (c) 2019 Pedro Cortés

/// What the GPU tells the timers each tick: its dot-clock divider and whether it is in a blank.
public struct VideoSync: Equatable, Sendable {
    public var dotDivider: Int
    public var hblank: Bool
    public var vblank: Bool

    public init(dotDivider: Int, hblank: Bool, vblank: Bool) {
        self.dotDivider = dotDivider
        self.hblank = hblank
        self.vblank = vblank
    }
}

/// The three root counters at 0x1F801100 + 0x10 × n: value, mode and target, each 16 bits in a
/// 32-bit slot (psx-spx, "Timers"). ProjectPSX's counting, kept as it is; its author marks it for
/// rework, and SwanStation's trace (3d) will say where.
public final class Timers {
    public private(set) var timers = [Timer(number: 0), Timer(number: 1), Timer(number: 2)]

    public init() {}

    func read(_ offset: UInt32) -> UInt32 {
        let number = Int(offset >> 4)
        guard number < 3 else { return 0xFFFF_FFFF }
        return timers[number].read(offset & 0xF)
    }

    func write(_ offset: UInt32, _ value: UInt32) {
        let number = Int(offset >> 4)
        guard number < 3 else { return }
        timers[number].write(offset & 0xF, value)
    }

    /// Advances timer `number` by `cycles` of the system clock; true when it requests its interrupt.
    func tick(_ number: Int, _ cycles: Int) -> Bool {
        timers[number].tick(cycles)
    }

    func sync(_ video: VideoSync) {
        timers[0].sync(video)
        timers[1].sync(video)
    }

    /// One root counter.
    public struct Timer: Sendable {
        let number: Int
        public private(set) var counter: UInt32 = 0
        public private(set) var target: UInt32 = 0

        var syncEnable: UInt32 = 0
        var syncMode: UInt32 = 0
        var resetOnTarget: UInt32 = 0
        var irqOnTarget: UInt32 = 0
        var irqOnFFFF: UInt32 = 0
        var irqRepeat: UInt32 = 0
        var irqToggle: UInt32 = 0
        var clockSource: UInt32 = 0
        var interruptRequest: UInt32 = 0
        var reachedTarget: UInt32 = 0
        var reachedFFFF: UInt32 = 0

        var video = VideoSync(dotDivider: 1, hblank: false, vblank: false)
        var previous = VideoSync(dotDivider: 1, hblank: false, vblank: false)
        var alreadyFired = false
        var cycles = 0

        init(number: Int) {
            self.number = number
        }

        mutating func write(_ register: UInt32, _ value: UInt32) {
            switch register {
            case 0x0: counter = value & 0xFFFF
            case 0x4: setMode(value)
            // psx-spx: the target is 16 bits; ProjectPSX keeps all 32.
            case 0x8: target = value & 0xFFFF
            default: break
            }
        }

        /// Reading the mode clears its two "reached" flags.
        mutating func read(_ register: UInt32) -> UInt32 {
            switch register {
            case 0x0: return counter
            case 0x4: return readMode()
            case 0x8: return target
            default: return 0
            }
        }

        mutating func sync(_ video: VideoSync) {
            previous = self.video
            self.video = video
        }

        mutating func tick(_ elapsed: Int) -> Bool {
            cycles += elapsed
            switch number {
            case 0:
                if syncEnable == 1 {
                    switch syncMode {
                    case 0: if video.hblank { return false }
                    case 1: if video.hblank { counter = 0 }
                    case 2:
                        if video.hblank { counter = 0 }
                        if !video.hblank { return false }
                    default:
                        if !previous.hblank && video.hblank { syncEnable = 0 } else { return false }
                    }
                }
                if clockSource == 0 || clockSource == 2 {
                    counter &+= UInt32(UInt16(truncatingIfNeeded: cycles))
                } else {
                    counter &+= UInt32(UInt16(truncatingIfNeeded: cycles * 11 / 7 / video.dotDivider)) // the dot clock
                }
                cycles = 0
                return handleIRQ()
            case 1:
                if syncEnable == 1 {
                    switch syncMode {
                    case 0: if video.vblank { return false }
                    case 1: if video.vblank { counter = 0 }
                    case 2:
                        if video.vblank { counter = 0 }
                        if !video.vblank { return false }
                    default:
                        if !previous.vblank && video.vblank { syncEnable = 0 } else { return false }
                    }
                }
                if clockSource == 0 || clockSource == 2 {
                    counter &+= UInt32(UInt16(truncatingIfNeeded: cycles))
                    cycles = 0
                } else if !previous.hblank && video.hblank {
                    counter &+= 1 // counts horizontal blanks; ProjectPSX lets `cycles` grow meanwhile
                }
                return handleIRQ()
            default:
                // ProjectPSX's condition, as written: sync modes 0 and 3 stop the counter.
                if syncEnable == 1 && syncMode == 0 || syncMode == 3 { return false }
                if clockSource == 0 || clockSource == 1 {
                    counter &+= UInt32(UInt16(truncatingIfNeeded: cycles))
                    cycles = 0
                } else {
                    counter &+= UInt32(UInt16(truncatingIfNeeded: cycles / 8)) // the system clock / 8
                    cycles %= 8
                }
                return handleIRQ()
            }
        }

        mutating func handleIRQ() -> Bool {
            var irq = false
            if counter >= target {
                reachedTarget = 1
                if resetOnTarget == 1 { counter = 0 }
                if irqOnTarget == 1 { irq = true }
            }
            if counter >= 0xFFFF {
                reachedFFFF = 1
                if irqOnFFFF == 1 { irq = true }
            }
            counter &= 0xFFFF
            guard irq else { return false }

            if irqToggle == 0 {
                interruptRequest = 0 // pulse: bit 10 goes low briefly
            } else {
                interruptRequest = (interruptRequest + 1) & 0x1
            }
            let trigger = interruptRequest == 0
            if irqRepeat == 0 { // once
                guard !alreadyFired && trigger else { return false }
                alreadyFired = true
            }
            interruptRequest = 1
            return trigger
        }

        mutating func setMode(_ value: UInt32) {
            syncEnable = value & 0x1
            syncMode = (value >> 1) & 0x3
            resetOnTarget = (value >> 3) & 0x1
            irqOnTarget = (value >> 4) & 0x1
            irqOnFFFF = (value >> 5) & 0x1
            irqRepeat = (value >> 6) & 0x1
            irqToggle = (value >> 7) & 0x1
            clockSource = (value >> 8) & 0x3
            interruptRequest = 1
            alreadyFired = false
            counter = 0
        }

        mutating func readMode() -> UInt32 {
            let mode = syncEnable | syncMode << 1 | resetOnTarget << 3 | irqOnTarget << 4 | irqOnFFFF << 5
                | irqRepeat << 6 | irqToggle << 7 | clockSource << 8 | interruptRequest << 10
                | reachedTarget << 11 | reachedFFFF << 12
            reachedTarget = 0
            reachedFFFF = 0
            return mode
        }
    }
}
