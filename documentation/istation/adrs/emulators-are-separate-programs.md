# ADR 0008 — Emulators are separate programs, driven only by their command line, and iStation ships none of their code or Sony's files

**Status:** Accepted · **Date:** 2026-10-31

## Context

The user's design (Overview & Architecture, 2026-10-26) makes iStation a launcher, not a merged emulator, for reasons that are legal as much as technical:

| Emulator | Console | Licence | What it means for iStation |
|---|---|---|---|
| DuckStation | PS1 | CC BY-NC-ND 4.0 | No forking, modifying or embedding; launching the user's installed copy is fine |
| PCSX2 | PS2 | GPLv3 | Can't be linked into one binary with RPCS3 |
| RPCS3 | PS3 | GPLv2 only | Can't be linked into one binary with PCSX2 |
| PCSX-Redux | PS1 (v1 recommendation, v2 bundled) | GPLv2 | Bundled in v2 as a separate helper app |

Keeping them separate also lets emulator updates arrive the normal way. Separately, Sony's BIOS files, PS3 system software and games are the user's to supply: iStation never bundles, downloads or commits them (SPEC non-goals).

## Decision

1. **iStation talks to an emulator only through its command line and its process exit** — never by linking, embedding, loading (`dlopen`) or modifying its code. The flags are each emulator's own ([reference/emulator-launch-contract.md](../reference/emulator-launch-contract.md)).
2. **One module starts processes**: `InfrastructureProcess`. Business reaches it only through `BusinessLaunching`.
3. **The package links no external code** unless it is on this record's allow-list, each entry licence-reviewed first. The allow-list is empty today. Expected entries: Sparkle (MIT, v1.0.0) and libchdr (BSD, v0.2.0) — each added by a superseding record or an "Accepted, with the allow-list extended" note, with its licence obligation.
4. **The repository holds no disc images, BIOS or system-software files.** Tests build their discs in memory, in a temporary folder.
5. In v2, bundled emulators are separate helper apps in `Contents/Helpers`, built from pinned git submodules, each keeping its own licence (aggregation, not linking) — never DuckStation.

## Consequences

- An emulator update needs no change to iStation unless its flags change; the launch contract's tests pin what iStation passes.
- Features that would need an emulator's internals (save-state thumbnails, in-game overlays) are out of reach by design, unless the emulator exposes them on its command line or in its files.
- This is the plan, not legal advice: the user's design calls for a legal review before charging money or heavily modifying an emulator.

## Enforcement

`ArchitectureTests/ProjectRulesTests.swift` fails on: `Process(`, `posix_spawn`, `NSTask`, `dlopen(` or `system(` in any source file outside `source/infrastructure/process/`; any `.package(` not on `allowedPackages` (empty), or any `.binaryTarget(` / `.systemLibrary(`, in `Package.swift`; and any disc-image, BIOS or firmware file (`.iso .bin .img .cue .m3u .chd .cso .zso .gz .pbp .ecm .pup .rom .mec .nvm`) anywhere in the repository outside build output. Each verified against a planted violation, 2026-10-31.
