# ADR 0010 — iStation's cores are Swift ports of open-source references; installed emulators cover the rest

**Status:** Superseded by [ADR 0013](shipped-code-derives-only-from-permissive-references.md) (2026-11-07, the same day: the App Store brief) · **Date:** 2026-11-07 · Supersedes [ADR 0008](emulators-are-separate-programs.md)

## Context

[ADR 0008](emulators-are-separate-programs.md) made iStation a launcher: emulators were separate programs, driven only by their command line, and nothing linked, embedded, loaded or modified emulator code. On 2026-11-07 the user re-envisioned the project (the brief "Port PS1 and PS2 emulators to Swift"): iStation writes its own emulators in Swift, using open-source C++ emulators as reference implementations — PS1 first, then PS2 — and keeps the library app as their frontend.

The references were checked the same day ([Milestone C](../assistant/MILESTONES.md#milestone-c--the-re-vision)):

| Console | Reference | Licence | Provenance |
|---|---|---|---|
| PS1 | [libretro/swanstation](https://github.com/libretro/swanstation) | GPLv3 (`LICENSE`; no per-file headers in its own sources) | DuckStation's history up to its author's last commit, 2022-01-11 — before DuckStation's 2024 relicense — then libretro's own work; no commit since 2023 mentions taking code from DuckStation |
| PS2 | [PCSX2](https://github.com/PCSX2/pcsx2) | GPLv3 | — |
| PS3 | RPCS3 | GPLv2 only | can never be linked with GPLv3 code |

SwanStation's bundled libraries were all GPLv3-compatible. The current DuckStation (stenzek/duckstation) is CC BY-NC-ND, which forbids derivatives.

*Redacted 2026-11-07 under [ADR 0013](shipped-code-derives-only-from-permissive-references.md): details of GPL emulators' source that stood here are removed; only licence and provenance facts remain.*

## Decision

1. **Each native core is a Swift port of one named reference** — PS1 from SwanStation, PS2 from PCSX2 — released under GPLv3, keeping the reference's copyright notices and credits, with its source published. The Swift R3000A serves the PS1 and the PS2's I/O processor.
2. **Provenance is clean.** PS1 code is read only from SwanStation: the current DuckStation is never read or copied. A third-party library inside a reference is licence-checked before it is ported or linked. Every ported file names the reference file it comes from and that file's authors ([ADR 0011](each-module-carries-its-licence.md)).
3. **The reference is built and traced locally, never vendored.** Its build, any local trace patch and the small frontend that drives it live outside the shipped app (`tools/`), are built from a pinned commit of the reference's public repository, and are never redistributed as binaries. Revula maps and profiles the compiled reference; nothing is decompiled, because the sources are open.
4. **GPLv2-only code never enters this program.** A later PS3 core would be a separate executable in the app bundle, reached over IPC — which is why the frontend reaches every core through one narrow, serializable interface ([ADR 0012](cores-shape-and-hot-paths.md)).
5. **A console without a native core is played through the user's installed emulator, as ADR 0008 required:** started only by `InfrastructureProcess`, reached only through `BusinessLaunching`, with that emulator's own flags (reference/emulator-launch-contract.md (retired with v0.0.1's item 3b; in the git history)) and nothing else. DuckStation is never bundled.
6. **No Sony files.** No BIOS, PS3 system software, disc image or game is ever in the repository, in a build, or fetched by the app; users supply their own dumps. Open replacements and open test suites are not Sony's files: OpenBIOS (MIT), [ps1-tests](https://github.com/JaCzekanski/ps1-tests) (MIT) and [ps2autotests](https://github.com/unknownbrackets/ps2autotests) (ISC) may be committed as test fixtures, each beside its licence, through the check's allow-list.
7. **External code in the package only after a licence review**, on this record's allow-list. The allow-list is empty today. Expected entries: libchdr (BSD, CD images) and Sparkle (MIT, updates).

## Consequences

- iStation now contains emulation code, and SPEC's non-goal "emulating any hardware" is gone ([SPEC.md](../assistant/SPEC.md), revised 2026-11-07).
- The app as a whole is GPLv3. The shared infrastructure stays GPL-2.0-or-later so it can serve a GPLv2-only core later ([ADR 0011](each-module-carries-its-licence.md)).
- The launching path, its process rule and its tests stay: the PS1 still launches the installed DuckStation until the native core plays games, and the PS2 and PS3 launch PCSX2 and RPCS3.
- A port's correctness is judged against its reference's trace, not by opinion; the trace tools are part of the work, not an extra.
- This is the plan, not legal advice: get a legal review before charging money.

## Enforcement

`ArchitectureTests/ProjectRulesTests.swift` (from ADR 0008, unchanged): `Process(`, `posix_spawn`, `NSTask`, `dlopen(` or `system(` in a Swift source file outside `source/infrastructure/process/`; any `.package(` not on `allowedPackages` (empty), or any `.binaryTarget(` / `.systemLibrary(`; and any `.iso .bin .img .cue .m3u .chd .cso .zso .gz .pbp .ecm .pup .rom .mec .nvm` file in the repository outside build output. The fixture allow-list for OpenBIOS and the open test suites is added by the first item that commits one (v0.0.1, item 2e). Provenance (§2) has no mechanical check — no test can tell where code was read — so review holds it, by the credit header every ported file carries.
