# ADR 0013 — Shipped code derives only from permissive references; GPL emulators are black-box oracles

**Status:** Accepted · **Date:** 2026-11-07 · Supersedes [ADR 0010](cores-are-ports-of-open-references.md)

## Context

[ADR 0010](cores-are-ports-of-open-references.md) made iStation's cores GPLv3 ports of SwanStation and PCSX2. The same day the user replaced that plan with the brief "PS1 and PS2 emulators in Swift (App Store-eligible)": putting GPL code on the App Store is legally contested — Apple's terms add restrictions the GPL forbids — and the project doesn't own the copyright needed to grant an exception. So shipped code must derive only from permissively licensed sources.

Checked on GitHub, 2026-11-07 ([Milestone D](../assistant/MILESTONES.md#milestone-d--the-app-store-re-vision)):

| Role | Project | Licence |
|---|---|---|
| PS1 reference | [ProjectPSX](https://github.com/BluestormDNA/ProjectPSX) | MIT (C#, .NET 10; a core library, a cross-platform OpenTK frontend, a Windows-only WinForms frontend) |
| PS2 reference | [Play!](https://github.com/jpd002/Play-), Play--Framework, Play--CodeGen, Nuanceur | BSD, two-clause wording, © Jean-Philip Desjardins |
| PS2 dependencies | Play-Dependencies | no licence of its own: each library carries its own; includes `unrarsrc-5.2.5` |
| PS1 oracle | SwanStation | GPLv3 — run only |
| PS2 oracle | PCSX2 | GPLv3 — run only |

Before this brief, while the GPL plans stood, this session read parts of SwanStation's, PCSX2's and the current DuckStation's source (2026-10-31 for the launcher's flags; 2026-11-07 for the port). Details from that reading are redacted from the docs by this record's rule.

## Decision

1. **Shipped code derives only from permissively licensed sources**: PS1 from ProjectPSX (MIT), PS2 from Play! and its own libraries (BSD), plus iStation's own code (MIT, [ADR 0014](own-code-is-mit-and-derived-code-keeps-its-notice.md)) and public hardware documentation (psx-spx, ps2tek).
2. **GPL emulators are black boxes.** The source of SwanStation, PCSX2, DuckStation, PCSX-Redux (including its OpenBIOS), Beetle PSX/Mednafen, PCSX-ReARMed, Avocado and RPCS3 is never opened, read or copied, and their disassembled or decompiled code is never transcribed. They may be built from their public repositories unmodified and run; their built-in debugger, trace and logging features are preferred; otherwise LLDB or Frida record guest-visible state only — guest CPU registers, guest memory, VRAM, audio samples. `revula_disassemble` and `revula_decompile` are never pointed at them.
3. **A session or person that has read a GPL emulator's source writes no core code.** Porting is done by sessions that haven't; this one, which has, writes docs only.
4. **The permissive references may be changed and traced freely**: ProjectPSX gains trace logging in its own source (MIT allows it); Play! is mapped, profiled and its code generator's AArch64 output disassembled with Revula.
5. **Every third-party dependency is audited before it is ported or linked.** From Play-Dependencies, unrarsrc (a non-standard UnRAR licence) and the Windows-only libraries stay out; AltKit isn't needed; Apple frameworks and Swift packages are preferred. External code joins the package only after that audit, on this record's allow-list — empty today.
6. **No Sony files.** No BIOS, system software, disc image or game is bundled, mirrored, downloaded or committed; users import their own through a file picker. A PS1 high-level-emulated BIOS, if it comes, is written from documentation and not based on OpenBIOS. OpenBIOS is not used, as a binary or otherwise.
7. **The PS3 stays out of scope**: its open references are GPL, so it could ship on the App Stores only if written from documentation alone.

## Consequences

- The PS1 core starts from ProjectPSX's design and fixes its known weak spots (CD-ROM, DMA and MDEC timing) against psx-spx, test suites and SwanStation's recorded behaviour — never SwanStation's code.
- Oracle traces are coarser than reference traces: a GPL oracle gives guest state per frame or per breakpoint from the outside, while ProjectPSX gives every instruction from inside its own source.
- The earlier plan's evidence about GPL internals is gone from the docs; only licence and provenance facts about those projects remain.
- This is the plan, not legal advice.

## Enforcement

`ArchitectureTests/ProjectRulesTests.swift` (unchanged from ADRs 0008 and 0010): any `.package(` not on `allowedPackages` (empty), any `.binaryTarget(` / `.systemLibrary(`, and any `.iso .bin .img .cue .m3u .chd .cso .zso .gz .pbp .ecm .pup .rom .mec .nvm` file in the repository fail the run. Provenance headers gain a check with Architecture item A2. §2 and §3 have no mechanical check — no test can tell what someone read — so review holds them, with each ported file's provenance line as the record.
