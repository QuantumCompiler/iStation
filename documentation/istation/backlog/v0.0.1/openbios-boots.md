# Gate: OpenBIOS boots — BIOS and PS-EXE loading, TTY output, open fixtures; the trace identical to SwanStation's

**What / why.** v0.0.1's gate (the user's call, 2026-11-07): OpenBIOS boots to its shell in the Swift core with an instruction trace identical to SwanStation's, and ps1-tests' `cpu/cop` and `cpu/code-in-io` pass. This item adds what the gate still needs — loading a BIOS image and a PS-EXE, capturing TTY output, the open fixtures — and the hermetic test that proves it.

Measured, not guessed (2026-11-07):
- SwanStation side-loads a PS-EXE by patching the BIOS to jump to it once its kernel is ready (`src/core/bios.cpp:157`, `PatchBIOSForEXE`, from `system.cpp:1238`), and recognizes OpenBIOS by the text `OpenBIOS` at offset `0x78` (`bios.cpp:124–126`).
- Its TTY is the writes to expansion region 2 at offsets `0x23` and `0x80` (`bus.cpp:684–705`).
- ps1-tests' `cpu/` folder holds four tests: `access-time` and `io-access-bitwidth` need memory timing and device registers (moved to v0.1.0); `cop` and `code-in-io` report `pass - …` lines over TTY, and each ships a `psx.log` recorded on a real PS1 (495 and 247 bytes). Its programs ship only in its 2021 release `build-158` (`tests.zip`, 6.6 MB) and leave the stack pointer at 0, so the loader sets one.
- The repository's check fails on any `.bin` file (`ProjectRulesTests.noGameOrFirmwareFiles`), and OpenBIOS is `openbios.bin` — so the check gains an allow-list here, with the first fixture.

**Core constraint(s).** No Sony files (⚠ in CLAUDE.md; [ADR 0010](../../adrs/cores-are-ports-of-open-references.md) §6): only open fixtures, each beside its licence, through the allow-list; the user's own BIOS is never a fixture. Ported code from its reference only, with headers (the loader ports `bios.cpp` and `system.cpp`). Tests hermetic: the gate runs inside `swift test`, with no C++ build, no network and nothing outside a `Sandbox`. The real home untouched.

**Seam + files.**
- `src/istation/source/business/ps1/`: `BIOSImage.swift` (a 512 KB image from a URL; OpenBIOS recognized by its marker), `PSEXE.swift` (the `PS-X EXE` header, validated as SwanStation does; text, data and BSS; PC, GP and SP — SP defaults when the header's is 0), the EXE patch ported from `PatchBIOSForEXE`, and `TTY.swift` (expansion-region-2 writes into lines).
- Fixtures under `src/istation/tests/business/ps1/Fixtures/`, read by path from the test, each with its licence: `openbios/openbios.bin` and `LICENSE.txt` (MIT, PCSX-Redux's OpenBIOS as SwanStation's pinned `dep/openbios` carries it); `ps1-tests/cop.exe`, `code-in-io.exe`, their `psx.log` files and `LICENSE` (MIT, release `build-158`); `openbios-boot.checkpoints` and `openbios-boot.tty.txt` made by 2b's tool from the pinned commit.
- `src/istation/tests/architecture/ProjectRulesTests.swift`: the allow-list — exact paths, each passing only when a licence file sits beside it.
- `src/istation/tests/business/ps1/GateTests.swift`: boots OpenBIOS and compares checkpoints and TTY; runs both ps1-tests programs and compares their TTY with `psx.log`; reports instructions per second.
- Docs: ADR 0010's Enforcement (the allow-list exists), CLAUDE.md's no-Sony-files invariant, ROADMAP's tick, MILESTONES.

**Reference.** SwanStation `src/core/bios.cpp`, `system.cpp` (`LoadEXE`, `LoadEXEToRAM`) and `bus.cpp`'s EXP2 path, at the pinned commit. [ps1-tests](https://github.com/JaCzekanski/ps1-tests) `cpu/cop` and `cpu/code-in-io` (sources and `psx.log`). [PCSX-Redux](https://github.com/pcsx-redux/pcsx-redux)'s OpenBIOS.

**Decisions made** (dated):
- 2026-11-07: the gate is OpenBIOS booting to its shell with a trace identical to SwanStation's, plus ps1-tests' `cop` and `code-in-io`; `access-time` and `io-access-bitwidth` move to v0.1.0 (the user's call).
- 2026-11-07: open fixtures are committed beside their licences through an allow-list (the re-vision's default, taken; ADR 0010 §6).

**Open calls:**
- [default: "to its shell" is the instruction count at which OpenBIOS's TTY output ends in 2b's reference run; the gate runs exactly that many instructions] Where the boot ends.
- [default: the gate compares checkpoints (2a), not the full trace, so `swift test` stays fast and the fixture small; a mismatch is chased with the full traces from 2b's tool] What the hermetic test compares.

**Guardrail(s).** The gate test itself: the checkpoints, the TTY and both `psx.log` files must match, every `swift test`. The allow-list fails on a planted unlicensed `.bin`, and on a listed path whose licence file is removed.

**Acceptance criteria:**
- [ ] OpenBIOS boots to its shell in `BusinessPS1`; every checkpoint equals SwanStation's, cycles included, and its TTY equals the reference's.
- [ ] ps1-tests' `cop` and `code-in-io` print exactly their `psx.log`.
- [ ] The allow-list admits exactly the open fixtures, each beside its licence; no Sony file is in the repository.
- [ ] Instructions per second for the boot are recorded in MILESTONES (ADR 0012's enforcement from here on).
- [ ] Shipping this item empties v0.0.1's table.

**Scope note.** v0.0.1, track 2, last: gated on 2b (the reference's checkpoints and TTY) and 2d (the console). Out of scope: anything drawn on screen (v0.1.0), the user's own BIOS (v0.2.0's Settings line), the other two ps1-tests CPU programs (v0.1.0).
