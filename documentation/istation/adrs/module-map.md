# ADR 0002 — The module map is the layer law's one declaration

**Status:** Accepted · **Date:** 2026-10-31

## Context

[ADR 0001](layer-enforcement.md) fixes the layers and the rule between them. A law stated in prose and again in the build drifts the first time one of them changes; the build and every check must read one declaration.

## Decision

**The `modules` table at the top of `src/istation/Package.swift` is the one declaration of which module sits in which layer and which modules it may depend on, and this table restates it.** Each `Module(.<layer>, "<Name>", uses: […], testSupport: […])` row generates the library target `<Layer><Name>` from `source/<layer>/<name>/` and the test target `<Layer><Name>Tests` from `tests/<layer>/<name>/`. Within the layer bound, a module may depend on exactly the targets its row lists. Shared test fixtures are `Support(.<layer>, "<Name>")` rows (target `Support<Name>`, `tests/support/<name>/`), placed at the lowest layer whose tests use them. The apps in `iStation.xcodeproj` are the entry points; nothing in the package imports them.

The directory naming follows SwiftPM's freedom of `path:`: lowercase module directories, `<Layer><Name>` target names (the default, taken 2026-10-31).

| Layer | Module | May depend on |
|---|---|---|
| infrastructure | `bytes` | — |
| data | `iso9660` | `InfrastructureBytes` |
| data | `systemcnf` | — |
| data | `playlists` | — |
| data | `tracing` | — |
| business | `ps1` | — |
| presentation | `styles` | — |
| presentation | `player` | `BusinessPS1`, `PresentationStyles` |
| presentation | `acknowledgements` | `PresentationStyles` |

The table as of 2026-11-07, after v0.0.1's item 3b retired the library app's 17 other modules ([Milestone F](../assistant/MILESTONES.md#milestone-f--the-skeleton-and-both-build-routines)). The library products the apps link are `PS1Core` (`BusinessPS1`) and `EmuKit` (the three Presentation modules); `TraceKit` (`DataTracing`, item 3c) is for personal builds only.

## Consequences

- A new module is a row in the map, a row in this table, a name on its layer card, and its source and test directories — in the same change; any one alone fails the check below.
- A module moving layers is a new record superseding this one; the table is history at the date it holds.

## Enforcement

`ArchitectureTests/LayerContextTests.swift` holds this table, the layer cards' **Modules** lines and the mirrored test tree equal to the map, and fails when it cannot find them. `ArchitectureTests/LayeringTests.swift` holds the code to the map ([ADR 0001](layer-enforcement.md)). Both verified against planted violations, 2026-10-31.
