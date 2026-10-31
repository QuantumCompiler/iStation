# ADR 0001 — Four layers, dependencies point down, regardless of language and framework

**Status:** Accepted · **Date:** 2026-10-31

## Context

iStation started as a two-target design: a Foundation-only `iStationCore` and a SwiftUI `iStation` on top (the user's Code Scaffold, 2026-10-26). Two targets keep SwiftUI out of the core, but nothing inside the core stops a format reader from reaching the store or a scanner from reaching the launcher, and coding agents take the shortest import that compiles. Structure drifts first when nothing holds it. A law with a mechanical check keeps every later change honest (the user's call, 2026-10-31: construct the project this way and carve the scaffold into the layers now).

## Decision

iStation is four layers, lowest to highest:

1. **Infrastructure** — the macOS mechanisms, each behind one interface: byte decoding, the user's folders, app bundles and Launch Services, child processes. Knows nothing about games.
2. **Data** — the shapes of the outside world: the library's record types, the ISO 9660 / SYSTEM.CNF / PARAM.SFO / playlist formats, each emulator's launch contract, and `library.json`.
3. **Business** — what iStation does: identify a disc, scan folders into games, find installed emulators, launch one game at a time, keep the library and its play history.
4. **Presentation** — the SwiftUI app: the window's chrome, the game grid, Settings, and the composition root that wires them to the library.

**A module may depend only on modules in its own layer or in any layer below it.** Dependencies point down, never up. SwiftUI, AppKit, UIKit and Cocoa are imported in Presentation only. The entry point (`source/main/iStationApp.swift`, the `@main` app) is the composition's starting point, not a module, and nothing imports it.

## Consequences

- Adding a module means declaring its layer first: its directory is `source/<layer>/<module>/` and its target is `<Layer><Module>`.
- Shared types sink: `Platform` and `Game` live in Data's `catalog`, because the store, the formats and every layer above need them.
- SwiftUI gets its wishes granted inside Presentation and nowhere else; AppKit calls the lower layers would have wanted (`NSWorkspace` lookups by bundle ID) are reached through Launch Services in Infrastructure instead.
- A change that would point an edge upward is an architecture change: a new ADR through the planning docs, never a clever import.

## Enforcement

- **The build.** Every module is its own SwiftPM target, generated from the module map in `src/istation/Package.swift` with exactly the dependencies its row declares ([ADR 0002](module-map.md)). `swift build --explicit-target-dependency-import-check=error` (run in CI) fails on an import of a module the target does not depend on at all. Measured 2026-10-31: the flag tolerates a module reached through a dependency's dependency, so the check below is the stricter line.
- **The check.** `ArchitectureTests` (`src/istation/tests/architecture/LayeringTests.swift`), run by `swift test` and in CI, fails naming the file and rule on: an empty map; a module without its directory, or a directory without its row; a declared edge pointing up or to an unknown module; an import not declared in the importer's own row (direct, not transitive); an upward import; an unused declared edge; a cycle; a UI framework below Presentation; anything importing the entry point or test code; and a test or support target breaking the same law.
- **Proof.** Every rule above was seen to fail on a planted violation, then the plant removed (2026-10-31; [MILESTONES.md → Milestone A](../assistant/MILESTONES.md#milestone-a--the-construction)).
