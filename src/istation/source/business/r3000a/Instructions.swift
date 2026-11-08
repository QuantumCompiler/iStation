// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2019 Pedro Cortés
// SPDX-FileCopyrightText: 2026 iStation contributors
// Ported from BluestormDNA/ProjectPSX/ProjectPSX/Core/CPU.cs — Copyright (c) 2019 Pedro Cortés

/// The instruction set: ProjectPSX's main and SPECIAL opcode tables, as switches.
extension R3000A {
    // MARK: - Fields

    @inlinable static func rs(_ w: UInt32) -> UInt32 { (w >> 21) & 0x1F }
    @inlinable static func rt(_ w: UInt32) -> UInt32 { (w >> 16) & 0x1F }
    @inlinable static func rd(_ w: UInt32) -> UInt32 { (w >> 11) & 0x1F }
    @inlinable static func sa(_ w: UInt32) -> UInt32 { (w >> 6) & 0x1F }
    @inlinable static func imm(_ w: UInt32) -> UInt32 { w & 0xFFFF }
    @inlinable static func immS(_ w: UInt32) -> UInt32 { UInt32(bitPattern: Int32(Int16(truncatingIfNeeded: w))) }
    /// The coprocessor number an exception names: the opcode's low two bits.
    @inlinable static func id(_ w: UInt32) -> UInt32 { (w >> 26) & 0x3 }

    // MARK: - Decode

    @inlinable
    func execute(_ w: UInt32) {
        switch w >> 26 {
        case 0x00: special(w)
        case 0x01: bcond(w)
        case 0x02: jump(w)
        case 0x03: setGPR(31, nextPC); jump(w)
        case 0x04: isBranch = true; if reg(Self.rs(w)) == reg(Self.rt(w)) { branch(w) }
        case 0x05: isBranch = true; if reg(Self.rs(w)) != reg(Self.rt(w)) { branch(w) }
        case 0x06: isBranch = true; if Int32(bitPattern: reg(Self.rs(w))) <= 0 { branch(w) }
        case 0x07: isBranch = true; if Int32(bitPattern: reg(Self.rs(w))) > 0 { branch(w) }
        case 0x08: add(reg(Self.rs(w)), Self.immS(w), into: Self.rt(w), w)
        case 0x09: setGPR(Self.rt(w), reg(Self.rs(w)) &+ Self.immS(w))
        case 0x0A: setGPR(Self.rt(w), Int32(bitPattern: reg(Self.rs(w))) < Int32(bitPattern: Self.immS(w)) ? 1 : 0)
        case 0x0B: setGPR(Self.rt(w), reg(Self.rs(w)) < Self.immS(w) ? 1 : 0)
        case 0x0C: setGPR(Self.rt(w), reg(Self.rs(w)) & Self.imm(w))
        case 0x0D: setGPR(Self.rt(w), reg(Self.rs(w)) | Self.imm(w))
        case 0x0E: setGPR(Self.rt(w), reg(Self.rs(w)) ^ Self.imm(w))
        case 0x0F: setGPR(Self.rt(w), Self.imm(w) << 16)
        case 0x10: cop0Instruction(w)
        case 0x11, 0x13: break // COP1 and COP3: no coprocessor; ProjectPSX treats them as NOPs.
        case 0x12: cop2Instruction(w)
        case 0x20: loadByte(w, signed: true)
        case 0x21: loadHalf(w, signed: true)
        case 0x22: loadWordLeft(w)
        case 0x23: loadWord(w)
        case 0x24: loadByte(w, signed: false)
        case 0x25: loadHalf(w, signed: false)
        case 0x26: loadWordRight(w)
        case 0x28: storeByte(w)
        case 0x29: storeHalf(w)
        case 0x2A: storeWordLeft(w)
        case 0x2B: storeWord(w)
        case 0x2E: storeWordRight(w)
        case 0x30, 0x31, 0x33, 0x38, 0x39, 0x3B: break // LWC0/1/3 and SWC0/1/3: NOPs, as in ProjectPSX.
        case 0x32: loadWordToCop2(w)
        case 0x3A: storeWordFromCop2(w)
        default: raise(.reservedInstruction, coprocessor: Self.id(w))
        }
    }

    @inlinable
    func special(_ w: UInt32) {
        let rs = Self.rs(w), rt = Self.rt(w), rd = Self.rd(w)
        switch w & 0x3F {
        case 0x00: setGPR(rd, reg(rt) << Self.sa(w))
        case 0x02: setGPR(rd, reg(rt) >> Self.sa(w))
        case 0x03: setGPR(rd, UInt32(bitPattern: Int32(bitPattern: reg(rt)) >> Self.sa(w)))
        case 0x04: setGPR(rd, reg(rt) << (reg(rs) & 0x1F))
        case 0x06: setGPR(rd, reg(rt) >> (reg(rs) & 0x1F))
        case 0x07: setGPR(rd, UInt32(bitPattern: Int32(bitPattern: reg(rt)) >> (reg(rs) & 0x1F)))
        case 0x08: jumpRegister(rs)
        case 0x09: setGPR(rd, nextPC); jumpRegister(rs)
        case 0x0C: raise(.syscall, coprocessor: Self.id(w))
        case 0x0D: raise(.breakpoint)
        case 0x10: setGPR(rd, hi)
        case 0x11: hi = reg(rs)
        case 0x12: setGPR(rd, lo)
        case 0x13: lo = reg(rs)
        case 0x18:
            let product = Int64(Int32(bitPattern: reg(rs))) * Int64(Int32(bitPattern: reg(rt)))
            hi = UInt32(truncatingIfNeeded: product >> 32)
            lo = UInt32(truncatingIfNeeded: product)
        case 0x19:
            let product = UInt64(reg(rs)) * UInt64(reg(rt))
            hi = UInt32(truncatingIfNeeded: product >> 32)
            lo = UInt32(truncatingIfNeeded: product)
        case 0x1A: divide(Int32(bitPattern: reg(rs)), Int32(bitPattern: reg(rt)))
        case 0x1B:
            let n = reg(rs), d = reg(rt)
            if d == 0 {
                hi = n
                lo = 0xFFFF_FFFF
            } else {
                hi = n % d
                lo = n / d
            }
        case 0x20: add(reg(rs), reg(rt), into: rd, w)
        case 0x21: setGPR(rd, reg(rs) &+ reg(rt))
        case 0x22:
            let a = reg(rs), b = reg(rt), result = a &- b
            if (result ^ a) & (a ^ b) & 0x8000_0000 != 0 {
                // ProjectPSX checks overflow only with CPU_EXCEPTIONS defined; psx-spx: always.
                raise(.overflow, coprocessor: Self.id(w))
            } else {
                setGPR(rd, result)
            }
        case 0x23: setGPR(rd, reg(rs) &- reg(rt))
        case 0x24: setGPR(rd, reg(rs) & reg(rt))
        case 0x25: setGPR(rd, reg(rs) | reg(rt))
        case 0x26: setGPR(rd, reg(rs) ^ reg(rt))
        case 0x27: setGPR(rd, ~(reg(rs) | reg(rt)))
        case 0x2A: setGPR(rd, Int32(bitPattern: reg(rs)) < Int32(bitPattern: reg(rt)) ? 1 : 0)
        case 0x2B: setGPR(rd, reg(rs) < reg(rt) ? 1 : 0)
        default: raise(.reservedInstruction, coprocessor: Self.id(w))
        }
    }

    // MARK: - Arithmetic

    /// ADD and ADDI: a signed overflow raises Overflow and writes nothing.
    @inlinable
    func add(_ a: UInt32, _ b: UInt32, into register: UInt32, _ w: UInt32) {
        let result = a &+ b
        if (result ^ a) & (result ^ b) & 0x8000_0000 != 0 {
            // ProjectPSX checks overflow only with CPU_EXCEPTIONS defined; psx-spx: always.
            raise(.overflow, coprocessor: Self.id(w))
        } else {
            setGPR(register, result)
        }
    }

    /// DIV: division by zero and 0x80000000 / -1 give the results psx-spx documents.
    @inlinable
    func divide(_ n: Int32, _ d: Int32) {
        if d == 0 {
            hi = UInt32(bitPattern: n)
            lo = n >= 0 ? 0xFFFF_FFFF : 1
        } else if n == Int32.min && d == -1 {
            hi = 0
            lo = 0x8000_0000
        } else {
            hi = UInt32(bitPattern: n % d)
            lo = UInt32(bitPattern: n / d)
        }
    }

    // MARK: - Branches and jumps

    @inlinable
    func branch(_ w: UInt32) {
        tookBranch = true
        nextPC = pc &+ (Self.immS(w) << 2)
    }

    @inlinable
    func jump(_ w: UInt32) {
        isBranch = true
        tookBranch = true
        nextPC = (nextPC & 0xF000_0000) | ((w & 0x3FF_FFFF) << 2)
    }

    @inlinable
    func jumpRegister(_ rs: UInt32) {
        isBranch = true
        tookBranch = true
        nextPC = reg(rs)
    }

    /// BLTZ, BGEZ, BLTZAL, BGEZAL — and the encodings between them, as ProjectPSX decodes them.
    @inlinable
    func bcond(_ w: UInt32) {
        isBranch = true
        let op = Self.rt(w)
        let link = op & 0x1E == 0x10
        let taken = Int32(bitPattern: reg(Self.rs(w)) ^ (op << 31)) < 0
        // ProjectPSX writes r31 directly, not through write-back; kept until SwanStation's trace (3d)
        // says which wins over a load pending into r31.
        if link { gpr[31] = nextPC }
        if taken { branch(w) }
    }

    // MARK: - Loads
    //
    // ProjectPSX checks alignment only with CPU_EXCEPTIONS defined and has no bus errors or user mode;
    // psx-spx: a misaligned access is always an address error, so is one outside KUSEG in user mode
    // (`heldBack`), and an access to nothing is a bus error (DBE).
    //
    // ProjectPSX reads 32 bits for a byte or halfword load and truncates; here the bus gets the load's
    // own width, as a device sees it: psx-spx's DEV8 region answers only 8-bit reads, and on hardware
    // an Expansion 3 halfword read isn't the low half of its word read (ps1-tests' io-access-bitwidth).

    @inlinable
    func address(_ w: UInt32) -> UInt32 { reg(Self.rs(w)) &+ Self.immS(w) }

    /// An address error: BadVaddr names the address (psx-spx).
    @inlinable
    func addressError(_ code: ExceptionCode, at address: UInt32, _ w: UInt32) {
        cop0[COP0Register.badVaddr] = address
        raise(code, coprocessor: Self.id(w))
    }

    /// While `accessGuarded`: true when a load or store must not reach the bus. In user mode, outside
    /// KUSEG, it is an address error, raised here, isolated cache or not, as psx-spx makes no exception
    /// for isolation and LWL and LWR raise it too; otherwise, with the cache isolated, it is ignored,
    /// as in ProjectPSX.
    @inlinable
    func heldBack(_ address: UInt32, _ error: ExceptionCode, _ w: UInt32) -> Bool {
        if userMode && address & 0x8000_0000 != 0 {
            addressError(error, at: address, w)
            return true
        }
        return cacheIsolated
    }

    @inlinable
    func loadByte(_ w: UInt32, signed: Bool) {
        let address = address(w)
        if accessGuarded, heldBack(address, .addressErrorLoad, w) { return }
        do {
            let value = try bus.load8(address)
            loadDelayed(Self.rt(w), signed ? UInt32(bitPattern: Int32(Int8(bitPattern: value))) : UInt32(value))
        } catch {
            raise(.busErrorData)
        }
    }

    @inlinable
    func loadHalf(_ w: UInt32, signed: Bool) {
        let address = address(w)
        if accessGuarded, heldBack(address, .addressErrorLoad, w) { return }
        guard address & 0x1 == 0 else {
            addressError(.addressErrorLoad, at: address, w)
            return
        }
        do {
            let value = try bus.load16(address)
            loadDelayed(Self.rt(w), signed ? UInt32(bitPattern: Int32(Int16(bitPattern: value))) : UInt32(value))
        } catch {
            raise(.busErrorData)
        }
    }

    @inlinable
    func loadWord(_ w: UInt32) {
        let address = address(w)
        if accessGuarded, heldBack(address, .addressErrorLoad, w) { return }
        guard address & 0x3 == 0 else {
            addressError(.addressErrorLoad, at: address, w)
            return
        }
        do {
            loadDelayed(Self.rt(w), try bus.load32(address))
        } catch {
            raise(.busErrorData)
        }
    }

    /// LWL and LWR merge into the value a load in the delay slot before them is still bringing.
    @inlinable
    func pendingValue(of register: UInt32) -> UInt32 {
        register == memoryLoad.register ? memoryLoad.value : reg(register)
    }

    // ProjectPSX's, kept until SwanStation's trace (3d) decides: LWL and LWR ignore cache isolation,
    // though psx-spx sends every isolated load to the cache.
    @inlinable
    func loadWordLeft(_ w: UInt32) {
        let address = address(w)
        if accessGuarded, userMode, address & 0x8000_0000 != 0 {
            addressError(.addressErrorLoad, at: address, w)
            return
        }
        do {
            let aligned = try bus.load32(address & 0xFFFF_FFFC)
            let shift = (address & 0x3) << 3
            let mask = UInt32(0x00FF_FFFF) >> shift
            loadDelayed(Self.rt(w), (pendingValue(of: Self.rt(w)) & mask) | (aligned << (24 - shift)))
        } catch {
            raise(.busErrorData)
        }
    }

    @inlinable
    func loadWordRight(_ w: UInt32) {
        let address = address(w)
        if accessGuarded, userMode, address & 0x8000_0000 != 0 {
            addressError(.addressErrorLoad, at: address, w)
            return
        }
        do {
            let aligned = try bus.load32(address & 0xFFFF_FFFC)
            let shift = (address & 0x3) << 3
            let mask = UInt32(0xFFFF_FF00) << (24 - shift)
            loadDelayed(Self.rt(w), (pendingValue(of: Self.rt(w)) & mask) | (aligned >> shift))
        } catch {
            raise(.busErrorData)
        }
    }

    // MARK: - Stores

    @inlinable
    func storeByte(_ w: UInt32) {
        let address = address(w)
        if accessGuarded, heldBack(address, .addressErrorStore, w) { return }
        do {
            try bus.store8(address, reg(Self.rt(w)))
        } catch {
            raise(.busErrorData)
        }
    }

    @inlinable
    func storeHalf(_ w: UInt32) {
        let address = address(w)
        if accessGuarded, heldBack(address, .addressErrorStore, w) { return }
        guard address & 0x1 == 0 else {
            addressError(.addressErrorStore, at: address, w)
            return
        }
        do {
            try bus.store16(address, reg(Self.rt(w)))
        } catch {
            raise(.busErrorData)
        }
    }

    @inlinable
    func storeWord(_ w: UInt32) {
        let address = address(w)
        if accessGuarded, heldBack(address, .addressErrorStore, w) { return }
        guard address & 0x3 == 0 else {
            addressError(.addressErrorStore, at: address, w)
            return
        }
        do {
            try bus.store32(address, reg(Self.rt(w)))
        } catch {
            raise(.busErrorData)
        }
    }

    @inlinable
    func storeWordLeft(_ w: UInt32) {
        // ProjectPSX lets SWL and SWR through while the cache is isolated; psx-spx: an isolated store
        // reaches only the cache, so they are held back like the other stores.
        let address = address(w)
        if accessGuarded, heldBack(address, .addressErrorStore, w) { return }
        let shift = (address & 0x3) << 3
        do {
            try storeLanes(address & 0xFFFF_FFFC, reg(Self.rt(w)) >> (24 - shift), keeping: UInt32(0xFFFF_FF00) << shift)
        } catch {
            raise(.busErrorData)
        }
    }

    @inlinable
    func storeWordRight(_ w: UInt32) {
        let address = address(w)
        if accessGuarded, heldBack(address, .addressErrorStore, w) { return }
        let shift = (address & 0x3) << 3
        do {
            try storeLanes(address & 0xFFFF_FFFC, reg(Self.rt(w)) << shift, keeping: UInt32(0x00FF_FFFF) >> (24 - shift))
        } catch {
            raise(.busErrorData)
        }
    }

    /// SWL's and SWR's write: only the store's byte lanes change. Memory's other bytes are merged from a
    /// peek; a device gets each of the store's bytes. ProjectPSX loads the whole word first, which
    /// charges a load's time and can trigger a device's read side effects.
    @inlinable
    func storeLanes(_ aligned: UInt32, _ value: UInt32, keeping kept: UInt32) throws(BusError) {
        if let word = bus.peek32(aligned) {
            try bus.store32(aligned, (word & kept) | value)
            return
        }
        for lane: UInt32 in 0..<4 where (kept >> (lane * 8)) & 0xFF == 0 {
            try bus.store8(aligned + lane, value >> (lane * 8))
        }
    }

    // MARK: - COP0

    @inlinable
    func cop0Instruction(_ w: UInt32) {
        switch Self.rs(w) {
        case 0b0_0000: moveFromCOP0(w)
        case 0b0_0100: moveToCOP0(w)
        // psx-spx: BC0F and BC0T aren't supported and raise Coprocessor Unusable; ProjectPSX raises
        // Reserved Instruction.
        case 0b0_1000 where Self.rt(w) <= 1: raise(.coprocessorUnusable, coprocessor: 0)
        // psx-spx: RFE (10h) is the only COP0 command, and TLBR, TLBWI, TLBWR and TLBP are Reserved
        // Instructions; ProjectPSX runs every command as RFE.
        case 0b1_0000 where w & 0x3F == 0x10: returnFromException()
        default: raise(.reservedInstruction, coprocessor: Self.id(w))
        }
    }

    /// The COP0 registers the PS1 has (psx-spx): 3, 5–9 and 11–15. 0–2, 4 and 10 are N/A; 16–31 garbage.
    @inlinable
    static func isCOP0Register(_ register: UInt32) -> Bool {
        register == 3 || (5...9).contains(register) || (11...15).contains(register)
    }

    @inlinable
    func moveFromCOP0(_ w: UInt32) {
        let register = Self.rd(w)
        if Self.isCOP0Register(register) {
            guard cop0Usable else {
                raise(.coprocessorUnusable, coprocessor: 0)
                return
            }
            lastCOP0Read = cop0[Int(register)]
            loadDelayed(Self.rt(w), lastCOP0Read)
        } else if register >= 16 {
            // psx-spx: 16–31 read garbage, without an exception even in user mode, usually the value of
            // the real register read just before; ProjectPSX raises Reserved Instruction.
            loadDelayed(Self.rt(w), lastCOP0Read)
        } else {
            raise(.reservedInstruction, coprocessor: Self.id(w))
        }
    }

    @inlinable
    func moveToCOP0(_ w: UInt32) {
        // psx-spx: 0–2, 4 and 10 don't exist and 16–31 are garbage, so a write changes nothing.
        // ProjectPSX stores it, and for 16–31 indexes past its 16-word array.
        let register = Self.rd(w)
        guard Self.isCOP0Register(register) else { return }
        guard cop0Usable else {
            raise(.coprocessorUnusable, coprocessor: 0)
            return
        }
        let value = reg(Self.rt(w))
        switch Int(register) {
        case COP0Register.cause:
            // Only the software-interrupt bits, 8 and 9, are writable.
            cop0[COP0Register.cause] = (cop0[COP0Register.cause] & ~UInt32(0x300)) | (value & 0x300)
        case COP0Register.sr:
            let wasEnabled = cop0[COP0Register.sr] & 0x1 == 1
            cop0[COP0Register.sr] = value
            statusChanged()
            // Enabling interrupts with a software interrupt pending takes it at once.
            let mask = (value >> 8) & 0x3
            let pending = (cop0[COP0Register.cause] >> 8) & 0x3
            if !wasEnabled && value & 0x1 == 1 && mask & pending != 0 {
                // ProjectPSX's: EPC names the instruction after the next one, which never runs; kept
                // until SwanStation's trace (3d) says otherwise.
                pc = nextPC
                raise(.interrupt, coprocessor: Self.id(w))
            }
        case 7:
            // DCIC: psx-spx's bits 6–11 and 16–22 are unused and always read zero; ProjectPSX stores
            // every bit.
            cop0[7] = value & 0xFF80_F03F
        case 3, 5, 9, 11:
            cop0[Int(register)] = value // BPC, BDA, BDAM, BPCM
        default:
            break // psx-spx: TAR, BadVaddr, EPC and PRID are read-only; ProjectPSX writes them.
        }
    }

    /// RFE pops SR's mode stack: bits 2–5 move down to 0–3; bits 4–5 stay.
    @inlinable
    func returnFromException() {
        guard cop0Usable else {
            raise(.coprocessorUnusable, coprocessor: 0)
            return
        }
        let mode = cop0[COP0Register.sr] & 0x3F
        cop0[COP0Register.sr] = (cop0[COP0Register.sr] & ~UInt32(0xF)) | (mode >> 2)
        statusChanged()
    }

    // MARK: - COP2

    @inlinable
    func cop2Instruction(_ w: UInt32) {
        // psx-spx: COP2 needs SR's CU2; ProjectPSX doesn't check it. With no coprocessor 2 (the IOP),
        // every COP2 instruction is Coprocessor Unusable.
        guard cop2Usable else {
            raise(.coprocessorUnusable, coprocessor: 2)
            return
        }
        let rs = Self.rs(w)
        if rs & 0x10 != 0 {
            cop2.execute(w)
            return
        }
        switch rs {
        case 0b0_0000: loadDelayed(Self.rt(w), cop2.readData(Self.rd(w)))
        case 0b0_0010: loadDelayed(Self.rt(w), cop2.readControl(Self.rd(w)))
        case 0b0_0100: cop2.writeData(Self.rd(w), reg(Self.rt(w)))
        case 0b0_0110: cop2.writeControl(Self.rd(w), reg(Self.rt(w)))
        default: raise(.reservedInstruction, coprocessor: Self.id(w))
        }
    }

    @inlinable
    func loadWordToCop2(_ w: UInt32) {
        guard cop2Usable else {
            raise(.coprocessorUnusable, coprocessor: 2)
            return
        }
        // ProjectPSX lets LWC2 and SWC2 through while the cache is isolated; psx-spx: an isolated load
        // or store reaches only the cache, so they are held back like the others.
        let address = address(w)
        if accessGuarded, heldBack(address, .addressErrorLoad, w) { return }
        guard address & 0x3 == 0 else {
            addressError(.addressErrorLoad, at: address, w)
            return
        }
        do {
            cop2.writeData(Self.rt(w), try bus.load32(address))
        } catch {
            raise(.busErrorData)
        }
    }

    @inlinable
    func storeWordFromCop2(_ w: UInt32) {
        guard cop2Usable else {
            raise(.coprocessorUnusable, coprocessor: 2)
            return
        }
        let address = address(w)
        if accessGuarded, heldBack(address, .addressErrorStore, w) { return }
        guard address & 0x3 == 0 else {
            // ProjectPSX raises the load's address error here; psx-spx: a store's.
            addressError(.addressErrorStore, at: address, w)
            return
        }
        do {
            try bus.store32(address, cop2.readData(Self.rt(w)))
        } catch {
            raise(.busErrorData)
        }
    }
}
