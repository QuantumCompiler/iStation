# ADR 0016 — Every app has an App Store routine and a personal routine; the library app is retired

**Status:** Accepted · **Date:** 2026-11-07 · Supersedes [ADR 0007](backwards-compatibility.md) for the retired library file

## Context

The App Store brief (2026-11-07) asks for two apps — macOS (PS1 and PS2) and iOS (PS1) — each with two build routines: an App Store release build and a personal build with debugging and tracing tools. It lays the code out as Swift packages shared by both apps — `PS1Core` and `PS2Core` (emulation only), `EmuKit` (Metal presentation, audio, GameController input, file import, save-state UI) and `TraceKit` (trace format, recorder and diff; personal builds only) — and two app targets.

The App Sandbox the release build needs can't start other emulators and reaches only files the user picks. Asked on 2026-11-07 what happens to today's library app (folder scanning, disc identification, launching DuckStation, PCSX2 and RPCS3), the user chose to **start the apps fresh** and retire it (the user's call). No version was ever released, so no user's `library.json` has to keep loading ([ADR 0007](backwards-compatibility.md)'s rule); the copy the user's own run wrote on 2026-11-07 stays on their Mac, unread.

The repository today: one Swift package (`src/istation/Package.swift`) whose module map generates 21 modules in four layers and their tests, `ArchitectureTests` enforcing the layer law, and a thin `iStation.xcodeproj` with no targets of its own.

## Decision

1. **Two routines per app.** *App Store release:* App Sandbox on, user-selected file access for BIOS and game import, on macOS `com.apple.security.cs.allow-jit`; never `com.apple.security.cs.allow-unsigned-executable-memory` or `get-task-allow`; TraceKit and debug UI compiled out. *Personal:* development signing, `get-task-allow` so LLDB and Frida can attach, JIT on, TraceKit and the debug UI (CPU and VRAM viewers, trace recording); never distributed.
2. **One compilation condition, `PERSONAL_BUILD`**, guards every tool and debug view; separate xcconfig and entitlements files per routine; one scheme or script per routine (`xcodebuild archive` with export options).
3. **The brief's packages are products of the one layered package.** `PS1Core`, `PS2Core`, `EmuKit` and `TraceKit` are library products whose modules sit in the four layers and obey the layer law ([ADR 0001](layer-enforcement.md), [ADR 0002](module-map.md)); the package adds iOS to its platforms. The two apps are targets in `iStation.xcodeproj` — answering the earlier question of an Xcode app target.
4. **The library app retires.** Its modules, tests, previews and contracts (the launch contract, the library file) are removed by v0.0.1's item 3b, which also decides which format readers, if any, carry over to the new apps.
5. **ADR 0007's rule carries to the new apps' own data**: settings and memory cards written by an older version keep loading or are migrated by a named, tested step; a save state carries a version and an older one is refused with a message rather than misread.

## Consequences

- The four-layer law, the module map, `ArchitectureTests`, MVVM for the apps' UI and named previews ([ADRs 0001–0006](README.md)) stand, now over the new modules.
- PS2 and PS3 games can't be played through iStation until the PS2 core exists; PS3 not at all.
- A tool written for a personal build never reaches the App Store, because the release routine compiles it out.

## Enforcement

From v0.0.1's item 3b: a check that every use of TraceKit and every debug view sits under `#if PERSONAL_BUILD`, and that the release entitlements file carries neither `allow-unsigned-executable-memory` nor `get-task-allow` — each verified against a planted violation. §5 by the tests each persisted format gets when it is introduced.
