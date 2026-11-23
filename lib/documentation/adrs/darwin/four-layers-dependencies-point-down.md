# ADR 0018 — Four layers, dependencies point down, regardless of language and framework

**Status:** Superseded by [ADR 0024](four-layers-and-business-holds-the-session.md) (2026-11-22): Business is the cores and what the apps do with one, `session`, where it said the cores alone; the rule otherwise carries · **Date:** 2026-11-14 · Supersedes [ADR 0001](layer-enforcement.md)

## Context

[ADR 0001](layer-enforcement.md) made iStation four layers on 2026-10-31, carving the user's Code Scaffold (2026-10-26) — a Foundation-only `iStationCore` under a SwiftUI `iStation` — into modules. Two targets keep SwiftUI out of the core, but nothing inside the core stops one concern from reaching into another, and coding agents take the shortest import that compiles. Structure drifts first when nothing holds it; a law with a mechanical check keeps every later change honest (the user's call, 2026-10-31: construct the project this way, carving the scaffold into the layers then rather than leaving the port as an item).

The law outlived the app it was written for: the App Store re-vision kept the four layers, the module map and `ArchitectureTests`, now over the new modules ([ADR 0016](two-build-routines-and-a-fresh-start.md), 2026-11-07). The library app's retirement (ADR 0016 §4, carried out by v0.0.1's item 3b, [Milestone F](../../assistant/darwin/MILESTONES.md#milestone-f--the-skeleton-and-both-build-routines)) left ADR 0001 describing what no longer exists, as v0.0.1's pre-merge docs pass found (2026-11-14):

- Its layers held the library app: the user's folders, app bundles, Launch Services and child processes; the library's records, PARAM.SFO, each emulator's launch contract and `library.json`; disc identification, scanning, emulator discovery, launching and the play history; the game grid and Settings. Its Consequences put `Platform` and `Game` in Data's `catalog`.
- Its entry point was `source/main/iStationApp.swift`, inside the package; the apps now start in two Xcode app targets.
- Its Enforcement names a check the code no longer makes — an import of the entry point, removed with `source/main/` on 2026-11-07 — and claims the whole law over test and support targets, which `testsObeyTheLayerLaw` has applied only in part since it was written.
- It leaves out checks the code does make: a `Module` row in a layer the `Layer` enum lacks, a module that uses itself, and the order of ADR 0001's own list of the layers.

This record restates the rule for today's tree. It decides nothing new.

## Decision

iStation is four layers, lowest to highest:

1. **Infrastructure** — the mechanisms everything stands on, each behind one small interface: today byte decoding (`bytes`). It knows nothing about games.
2. **Data** — the shapes of the outside world, not the rules: the disc-image readers kept for v0.2.0's discs (`iso9660`, `systemcnf`, `playlists`) and TraceKit's trace formats (`tracing`, personal builds only).
3. **Business** — the cores, what a console does: the R3000A interpreter (`r3000a`) and the PS1 console (`ps1`), both ported from ProjectPSX, in the shape [ADR 0015](a-core-is-a-cpu-module-and-a-console-module.md) sets.
4. **Presentation** — EmuKit, the SwiftUI views the macOS and iOS apps share: the player (`player`) and the acknowledgements screen (`acknowledgements`), each MVVM ([ADR 0020](presentation-is-mvvm-with-one-styles-module.md)), and the tokens they draw with (`styles`).

**A module may depend only on modules in its own layer or in any layer below it**, and only on those its row in the module map lists ([ADR 0002](module-map.md)). Dependencies point down, never up. Test and support targets obey the same law ([ADR 0019](tests-live-in-the-layer-of-what-they-test.md)). SwiftUI, AppKit, UIKit and Cocoa are imported in Presentation and by the apps, never below.

**The apps are not modules.** `iStation macOS` and `iStation iOS`, the app targets of `lib/src/darwin/iStation.xcodeproj`, start at `lib/src/darwin/apps/macos/Sources/iStationApp.swift` and `lib/src/darwin/apps/ios/Sources/iStationApp.swift` (each `@main`). They are the entry points and composition roots: each builds the console and the view-models from the library products it links (`PS1Core`, `EmuKit`) and holds no logic, and nothing imports them.

## Consequences

- Adding a module means declaring its layer first: its `Module` row in the map, its directory `source/<layer>/<name>/` (lowercase) and its target `<Layer><Name>`; [ADR 0002](module-map.md) lists what else lands in the same change.
- Shared code sinks to the lowest layer that needs it, so every user reaches it downward; a shared test fixture is a `Support` row no higher than the lowest layer whose tests use it — `SupportSandbox`, which Data's and Business's tests use, sits in Infrastructure.
- SwiftUI gets its wishes granted inside Presentation and the apps and nowhere else. An OS mechanism a lower layer needs enters Infrastructure behind one interface, so the layers above test over fakes; the cores go further and import neither UI nor Apple frameworks — the Swift standard library, and nothing else without a recorded reason ([ADR 0015](a-core-is-a-cpu-module-and-a-console-module.md) §1).
- The apps are outside the module map, so the layer checks below don't read them.
- A change that would point an edge upward is an architecture change: a new ADR through the planning docs, never a clever import.

## Enforcement

- **The build.** Every module is its own SwiftPM target, generated from the module map in `lib/src/darwin/Package.swift` with exactly the dependencies its row's `uses:` declares ([ADR 0002](module-map.md)); a module's test target depends on the module and its `testSupport:`, a support target on its row's `uses:`. `swift build --explicit-target-dependency-import-check=error` builds every target but the test targets — the modules and the `Support…` targets; `swift test` builds the test targets without the flag — and fails on an import of a module the importing target does not depend on at all. Measured 2026-10-31: the flag tolerates a module reached through a dependency's dependency, so `importsAreDeclared` is the stricter line. `lib/scripts/cicd.sh --test` runs the strict build, then `swift test`; CI runs it as `cicd.sh --app darwin --test` (`.github/workflows/darwin.yml`) whenever `lib/scripts/changed.sh darwin` finds `lib/src/darwin/` or the pipeline's own files changed since the latest release, so when only documentation has changed, CI runs neither.
- **The checks.** `ArchitectureTests`, run by `swift test`, parses the map from `Package.swift` (or the copy `ISTATION_ARCHITECTURE_MANIFEST` names) and reads the Swift files under `source/` and `tests/`; each failure names its rule in brackets and the file. In `lib/src/darwin/tests/architecture/LayeringTests.swift`:
  - `theMapIsNotEmpty` fails when no `Layer` case or no `Module` row parses, when a layer holds no module, and when a row names a layer the `Layer` enum lacks.
  - `everyModuleHasItsSourceDirectory` fails on a module whose `source/<layer>/<name>/` holds no Swift file, a directory in `source/` that is not a layer, and a directory in a layer with no `Module` row.
  - `declaredEdgesPointDown` fails on a `uses:` entry that is not a module, that names its own module, or that sits in a higher layer.
  - `importsAreDeclared` fails, in a module's source files, on an import of a `Support…` target or of any `…Tests` target (`ArchitectureTests` included), an import of a module in a higher layer, and an import of a package module not in the importer's own `uses:` — direct, not transitive.
  - `everyDeclaredEdgeIsUsed` fails on a `uses:` entry that no file of the module imports.
  - `theModuleGraphHasNoCycles` fails on a cycle through the modules' `uses:`.
  - `uiFrameworksStayInPresentation` fails on `SwiftUI`, `AppKit`, `UIKit` or `Cocoa` imported by a source file of a module below Presentation.
  - `testsObeyTheLayerLaw` fails on a `testSupport:` entry that is not a `Support` row or sits above its module's layer; a test file importing a package target other than its module, that module's `uses:` and its `testSupport:`; a `Support` row's `uses:` entry that is not a module or sits above the row's layer; and a support file importing a package target its row doesn't list.

  `LayeringTests`' other six tests hold the Presentation shape ([ADR 0020](presentation-is-mvvm-with-one-styles-module.md), [ADR 0021](presentation-modules-stand-alone-and-preview-sample-data.md)). `LayerContextTests.adrListsTheLayersInOrder` fails when this record's numbered layer list differs from the map's `Layer` cases (it read ADR 0001's file until this record superseded it, 2026-11-14).
- **What no check holds.** The layer checks read the modules' and the support targets' own directories, never `apps/`. The entry point's imports were held to a declared list until that check went with `source/main/` on 2026-11-07; no check holds an app's imports to one, and only `toolsArePersonalOnly` reads them, for `DataTracing` ([ADR 0016](two-build-routines-and-a-fresh-start.md)). No check looks for an import of an app either — `ModuleMap.packageTargets` (`tests/architecture/Repository.swift`) names only the modules, their test targets, the support targets and `ArchitectureTests` — and none is needed: a package target can depend only on the package's own targets and on packages, never on an Xcode app target. Test and support targets get the import and support-edge checks above but not the unused-edge or UI-framework checks, so an unused `testSupport:` or support `uses:` entry, or a UI framework imported by a test or support file below Presentation, passes; no check has held those since the suite was written (2026-10-31), and review does.
- **Proof** (history). Every architecture rule of 2026-10-31 was seen to fail on a planted violation, then the plant removed: 44 plants across `LayeringTests`, `LayerContextTests` and `ProjectRulesTests`, the entry-point plant among them, with a cycle and `styles` using a sibling planted in a copy of the manifest through `ISTATION_ARCHITECTURE_MANIFEST`, because SwiftPM refuses to load them ([Milestone A](../../assistant/darwin/MILESTONES.md#milestone-a--the-construction)). The eight checks above have since lost only their entry-point parts (2026-11-07), and MILESTONES records no later plant of them.
