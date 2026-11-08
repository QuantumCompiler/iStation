// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2019 Pedro Cortés
// SPDX-FileCopyrightText: 2026 iStation contributors
// Ported from BluestormDNA/ProjectPSX/ProjectPSX/Core/CPU.cs — Copyright (c) 2019 Pedro Cortés

/// The R3000A: the PS1's CPU, and the PS2's I/O processor, as an interpreter.
///
/// Ported from ProjectPSX's `CPU.cs` (pinned at `f4dc13aea42d`): its pipeline of fetch, execute,
/// the load-delay slot and write-back; its branch-delay bookkeeping; its COP0. Generic over the bus,
/// coprocessor 2 and tracer it is given, all specialized into the hot path (ADR 0015). Where
/// ProjectPSX and psx-spx disagree, psx-spx decides and the difference is noted beside the code.
public final class R3000A<Bus: R3000ABus, Cop2: Coprocessor2, Tracer: R3000ATracer> {
    public let bus: Bus

    // Every stored `var` is `@exclusivity(unchecked)`: a class's stored properties otherwise get a
    // dynamic exclusivity check on each access, wherever the inlined hot path lands, and in the spike's
    // loop those cost 15× (18 M instructions/s against 256 M). The CPU is driven from one thread.
    @exclusivity(unchecked) public var cop2: Cop2
    @exclusivity(unchecked) public var tracer: Tracer

    /// The address of the next instruction to fetch.
    @exclusivity(unchecked) public var pc: UInt32 = 0xBFC0_0000
    /// The address after it: where a branch writes its target, so the delay slot still runs.
    @exclusivity(unchecked) public var nextPC: UInt32 = 0xBFC0_0004
    @exclusivity(unchecked) public var hi: UInt32 = 0
    @exclusivity(unchecked) public var lo: UInt32 = 0
    /// Cycles taken so far, by the bus's fetch timings.
    @exclusivity(unchecked) public var cycles: UInt64 = 0

    @usableFromInline let gpr: UnsafeMutablePointer<UInt32>
    @usableFromInline let cop0: UnsafeMutablePointer<UInt32>
    /// The address of the instruction executing now.
    @exclusivity(unchecked) @usableFromInline var currentPC: UInt32 = 0
    @exclusivity(unchecked) @usableFromInline var word: UInt32 = 0
    @exclusivity(unchecked) @usableFromInline var isBranch = false
    @exclusivity(unchecked) @usableFromInline var isDelaySlot = false
    @exclusivity(unchecked) @usableFromInline var tookBranch = false
    @exclusivity(unchecked) @usableFromInline var delaySlotTookBranch = false
    /// SR bit 16 (IsC): stores go to the cache, not to memory.
    @exclusivity(unchecked) @usableFromInline var cacheIsolated = false
    @exclusivity(unchecked) @usableFromInline var writeBack = Pending()
    @exclusivity(unchecked) @usableFromInline var memoryLoad = Pending()
    @exclusivity(unchecked) @usableFromInline var delayedLoad = Pending()

    /// A register write waiting for its pipeline stage.
    @usableFromInline
    struct Pending {
        @usableFromInline var register: UInt32 = 0
        @usableFromInline var value: UInt32 = 0
        @inlinable init() {}
    }

    public init(bus: Bus, cop2: Cop2, tracer: Tracer) {
        self.bus = bus
        self.cop2 = cop2
        self.tracer = tracer
        gpr = .allocate(capacity: 32)
        gpr.initialize(repeating: 0, count: 32)
        cop0 = .allocate(capacity: 16)
        cop0.initialize(repeating: 0, count: 16)
        cop0[COP0Register.prid] = 0x2
    }

    deinit {
        gpr.deallocate()
        cop0.deallocate()
    }

    // MARK: - State

    /// General register `index` (0–31); r0 always reads 0.
    public func register(_ index: Int) -> UInt32 { gpr[index] }

    /// Sets a general register directly, outside the pipeline — for loaders and tests.
    public func setRegister(_ index: Int, _ value: UInt32) {
        if index != 0 { gpr[index] = value }
    }

    /// COP0 register `index` (0–15).
    public func cop0Register(_ index: Int) -> UInt32 { cop0[index] }

    /// Sets a COP0 register directly — for loaders and tests. SR's cache-isolation bit takes effect.
    public func setCOP0Register(_ index: Int, _ value: UInt32) {
        cop0[index] = value
        if index == COP0Register.sr { cacheIsolated = value & 0x1_0000 != 0 }
    }

    /// Starts executing at `address`, as after a jump with no delay slot.
    public func jump(to address: UInt32) {
        pc = address
        nextPC = address &+ 4
        isBranch = false
        tookBranch = false
    }

    // MARK: - Running

    /// Executes one instruction and returns the cycles its fetch took.
    @inlinable
    @discardableResult
    public func step() -> Int {
        currentPC = pc
        pc = nextPC
        nextPC &+= 4
        isDelaySlot = isBranch
        delaySlotTookBranch = tookBranch
        isBranch = false
        tookBranch = false

        var fetchCycles = 1
        if currentPC & 0x3 != 0 {
            // ProjectPSX checks this only with CPU_EXCEPTIONS defined; psx-spx: always an address error.
            word = 0
            cop0[COP0Register.badVaddr] = currentPC
            raise(.addressErrorLoad)
        } else {
            do {
                let fetch = try bus.fetch(currentPC)
                word = fetch.word
                fetchCycles = fetch.cycles
                if word != 0 { execute(word) }
            } catch {
                // ProjectPSX has no bus errors; psx-spx: an instruction fetch from nothing raises IBE.
                word = 0
                raise(.busErrorInstruction)
            }
        }
        memoryAccess()
        registerWriteBack()
        cycles &+= UInt64(fetchCycles)

        if Tracer.isEnabled {
            tracer.retired(RetiredInstruction(
                pc: currentPC, word: word, cycles: cycles, gpr: UnsafePointer(gpr), hi: hi, lo: lo,
                sr: cop0[COP0Register.sr], cause: cop0[COP0Register.cause], epc: cop0[COP0Register.epc]
            ))
        }
        return fetchCycles
    }

    /// Raises the interrupt exception when the interrupt controller's line is up and SR enables it.
    /// The console calls this between instructions, as ProjectPSX's run loop does.
    @inlinable
    public func handleInterrupts() {
        // ProjectPSX's quirk, kept: an interrupt waits while the next instruction is a COP2 one, so
        // the GTE command isn't lost (its comment names Crash Bandicoot's intro).
        if let next = try? bus.fetch(pc), next.word >> 26 == 0x12 { return }

        if bus.interruptPending {
            cop0[COP0Register.cause] |= 0x400
        } else {
            cop0[COP0Register.cause] &= ~UInt32(0x400)
        }
        let enabled = cop0[COP0Register.sr] & 0x1 == 1
        let mask = (cop0[COP0Register.sr] >> 8) & 0xFF
        let pending = (cop0[COP0Register.cause] >> 8) & 0xFF
        if enabled && mask & pending != 0 {
            raise(.interrupt)
        }
    }

    // MARK: - The pipeline

    @inlinable
    func memoryAccess() {
        // A load delay on the same register as the load before it is lost (ProjectPSX: amidog's tests).
        if delayedLoad.register != memoryLoad.register {
            gpr[Int(memoryLoad.register)] = memoryLoad.value
        }
        memoryLoad = delayedLoad
        delayedLoad.register = 0
    }

    @inlinable
    func registerWriteBack() {
        gpr[Int(writeBack.register)] = writeBack.value
        writeBack.register = 0
        gpr[0] = 0
    }

    @inlinable
    func setGPR(_ register: UInt32, _ value: UInt32) {
        writeBack.register = register
        writeBack.value = value
    }

    @inlinable
    func loadDelayed(_ register: UInt32, _ value: UInt32) {
        delayedLoad.register = register
        delayedLoad.value = value
    }

    @inlinable
    func reg(_ index: UInt32) -> UInt32 { gpr[Int(index)] }

    // MARK: - Exceptions

    /// Enters an exception: pushes SR's mode bits, records CAUSE and EPC (and, in a delay slot,
    /// BD, BT and the jump destination), and jumps to the vector.
    @inlinable
    func raise(_ code: ExceptionCode, coprocessor: UInt32 = 0) {
        let mode = cop0[COP0Register.sr] & 0x3F
        cop0[COP0Register.sr] = (cop0[COP0Register.sr] & ~UInt32(0x3F)) | ((mode << 2) & 0x3F)

        let oldCause = cop0[COP0Register.cause] & 0xFF00
        cop0[COP0Register.cause] = code.rawValue << 2 | oldCause | coprocessor << 28

        if code == .interrupt {
            cop0[COP0Register.epc] = pc
            // ProjectPSX: an interrupt is taken between instructions, so "in a delay slot" means
            // the instruction just executed was a branch.
            isDelaySlot = isBranch
            delaySlotTookBranch = tookBranch
        } else {
            cop0[COP0Register.epc] = currentPC
        }

        if isDelaySlot {
            cop0[COP0Register.epc] &-= 4
            cop0[COP0Register.cause] |= 1 << 31
            cop0[COP0Register.jumpDestination] = pc
            if delaySlotTookBranch { cop0[COP0Register.cause] |= 1 << 30 }
        }

        // psx-spx: SR's BEV (bit 22) selects the vector. ProjectPSX writes `SR & 0x400000 >> 22`,
        // which C# parses as `SR & 1` and so always vectors to RAM.
        pc = cop0[COP0Register.sr] & 0x40_0000 != 0 ? 0xBFC0_0180 : 0x8000_0080
        nextPC = pc &+ 4
    }

    /// True when SR's CU2 bit (30) lets COP2 instructions run.
    @inlinable
    var cop2Usable: Bool { Cop2.isInstalled && cop0[COP0Register.sr] & 0x4000_0000 != 0 }
}
