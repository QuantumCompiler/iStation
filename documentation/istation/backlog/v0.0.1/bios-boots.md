# Gate: the BIOS boots — ps1-tests' CPU tests pass, and the guest-state trace matches SwanStation's

**What / why.** v0.0.1's PS1 milestone (the user's brief, 2026-11-07): the R3000A interpreter, the memory map and the BIOS boot, passing ps1-tests' CPU tests, with a guest-state trace that matches SwanStation's. ProjectPSX needs a real BIOS, and OpenBIOS is not used ([ADR 0013](../../adrs/shipped-code-derives-only-from-permissive-references.md) §6), so the gate runs in a personal build with the user's own BIOS dump — the user's run.

Checked 2026-11-07: ps1-tests (MIT) has four CPU tests — `access-time`, `code-in-io`, `cop` and `io-access-bitwidth`. `cop` and `code-in-io` report `pass - …` lines over TTY and ship a `psx.log` recorded on a real PS1 (495 and 247 bytes); the programs themselves ship only in the 2021 release `build-158` (`tests.zip`, 6.6 MB) and leave the stack pointer at 0.

**Core constraint(s).** No Sony files: the BIOS is passed by path in a personal run and never copied into the repository; ps1-tests' programs are fetched from their release into a git-ignored folder (⚠ in CLAUDE.md). GPL emulators are black boxes: the comparison uses only 3d's recorded guest state. Release builds carry no tools: the runner is personal-only.

**Seam + files.**
- A personal-build runner (in the macOS app's personal routine or a small tool beside 3d's): boots the BIOS, or the BIOS then a PS-EXE, in `BusinessPS1` with TraceKit recording, and prints the TTY.
- `tools/ps1-tests/fetch.sh`: downloads release `build-158` into a git-ignored folder, beside its MIT licence.
- `tools/gate/run.sh`: runs the boot and the four CPU tests, diffs per-frame traces against SwanStation's and per-instruction traces against ProjectPSX's (3d), compares each test's TTY with its `psx.log` where one exists, and writes a report.
- MILESTONES: the report's numbers.

**Reference.** [ps1-tests](https://github.com/JaCzekanski/ps1-tests) `cpu/` (sources and `psx.log`, MIT). 3c's formats and diff; 3d's tools.

**Decisions made** (dated):
- 2026-11-07: the milestone is the brief's — all of ps1-tests' CPU tests and a trace matching SwanStation's — replacing Milestone C's narrower bar (the user's brief).
- 2026-11-07: OpenBIOS is not used, as a binary either, so the boot needs the user's BIOS (the default, taken; ADR 0013 §6).
- 2026-11-07: "boots" means the BIOS reaches its shell, measured as the frame where SwanStation's recorded RAM stops changing in the boot sequence's pattern for 60 frames; the gate compares every frame up to it (the default, confirmed by the user).
- 2026-11-07: for `access-time` and `io-access-bitwidth`, which ship no `psx.log`, SwanStation's TTY in 3d's run is the expected output (the default, confirmed by the user).
- 2026-11-07: the gate's run with the user's BIOS is prepared with exact steps and made later (the user's call).

**Open calls:** none — all answered 2026-11-07.

**Guardrail(s).** The report is the guardrail: every frame up to the boot's end matches SwanStation's checksums, every test's TTY matches its expected output, and any per-instruction divergence from ProjectPSX is either fixed or listed as a known ProjectPSX error with psx-spx's evidence. Hermetic tests in 3e and 3f keep running in `swift test`.

**Acceptance criteria:**
- [ ] In a personal build with the user's BIOS (the user's run), the BIOS boots to its shell with per-frame guest state matching SwanStation's.
- [ ] ps1-tests' `access-time`, `code-in-io`, `cop` and `io-access-bitwidth` print their expected output.
- [ ] Every divergence from ProjectPSX's per-instruction trace is fixed or listed with psx-spx's evidence.
- [ ] Instructions per second for the boot are recorded in MILESTONES (ADR 0015's enforcement from here on).
- [ ] Shipping this item empties v0.0.1's table.

**Scope note.** v0.0.1, track 3, last: gated on 3d (the reference's and the oracle's traces) and 3f (the console). Out of scope: anything drawn on screen (v0.1.0) and games (v0.2.0).
