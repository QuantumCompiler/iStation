# ADR 0024 — Four layers, dependencies point down, regardless of language and framework; Business is the cores and what the apps do with one

**Status:** Accepted · **Date:** 2026-11-22 · Supersedes [ADR 0018](four-layers-dependencies-point-down.md)

## Context

[ADR 0018](four-layers-dependencies-point-down.md) (2026-11-14) restated [ADR 0001](layer-enforcement.md)'s law for the tree the library app's retirement left. Its third layer was "the cores, what a console does": the R3000A interpreter and the PS1 console, both ported from ProjectPSX, in the shape [ADR 0015](a-core-is-a-cpu-module-and-a-console-module.md) sets. Each app built the console and the view-models.

v0.1.0's item 5b, the console session and the player ([MILESTONES](../../assistant/darwin/MILESTONES.md)), needs something between the two: a service that runs the console off the main actor for the player, and for every later screen that starts or watches a run (5c's BIOS check, 5d's opening job, 5f's Tools and debug drawer). Three findings shaped it:

- **Frames have to be paced.** Measured on 2026-11-21 over the CPU-check image built in code, 60 `runFrame()` calls took 0.014 s. A loop that only called `runFrame()` would race far ahead of 60 frames a second, so something has to own a clock.
- **Reset is a fresh power-on, and the boot comes right after it.** Powering the console on again brought its frame back to 0 (the design's contract row C06). Since item 6a ([Milestone T](../../assistant/darwin/MILESTONES.md#milestone-t--the-narrow-interface-boot-the-shell-and-debug-values)), the BIOS enters its shell once per power-on. So a PS-EXE has to go to `boot(exe:)` right after each power-on, Reset's included, before a frame runs. Given once frames are running, it can wait for good. Whatever runs the console has to keep that order.
- **A core is driven from one thread** (ADR 0015 §4). The player's view-model lives on the main actor, and Swift 6's strict concurrency won't let a console that isn't `Sendable` be shared between the two.

That runner is not a core. It emulates nothing and owns no memory map, and it is iStation's own code, ported from no reference. ADR 0018's Business, "the cores", had no place for it, and every other place was worse:

- **In Presentation**, either the view-model would drive the console itself on the main actor, its frames taking the interface's time, or the module would grow a service beside its views. [ADR 0023](presentation-is-mvvm-and-styles-carries-the-design.md)'s shape has no directory for a service, and it would sit within reach of SwiftUI.
- **In an app target**, it would be logic in a composition root, which holds none. It would be written once per app, and no check would see it, because the layer checks never read `apps/`.
- **In Data or Infrastructure**, it would sit below the console it runs, and its edge to the console would point up.

Decided 2026-11-22 (the default, confirmed by the user): the runner is a new Business module, `session`. It is not a core but what the apps do with one, and it is free of UI frameworks. ADR 0018's definition of Business no longer holds, and ADRs are append-only, so this record restates its whole rule for today. Only what that call changes is different: Business's definition, what the apps build, and the citations that follow from them. Presentation's shape has been ADR 0023's since 2026-11-22, when it superseded ADR 0020.

## Decision

iStation is four layers, lowest to highest:

1. **Infrastructure** — the mechanisms everything stands on, each behind one small interface: today byte decoding (`bytes`). It knows nothing about games.
2. **Data** — the shapes of the outside world, not the rules: the disc-image readers kept for v0.2.0's discs (`iso9660`, `systemcnf`, `playlists`) and TraceKit's trace formats (`tracing`, personal builds only).
3. **Business** — the cores, what a console does, and what the apps do with a core. The cores are the R3000A interpreter (`r3000a`) and the PS1 console (`ps1`), both ported from ProjectPSX, in the shape [ADR 0015](a-core-is-a-cpu-module-and-a-console-module.md) sets. What the apps do with a core is, today, run it. That is the console session (`session`), iStation's own module and not a core, which runs one console off the main actor:
   - It powers the console on with a BIOS and boots the PS-EXE given with it.
   - It runs the console's frames 60 a second, paced by the clock it is given.
   - It pauses, resumes, resets and stops the console.
   - It streams a `Sendable` snapshot of the console.
4. **Presentation** — EmuKit, the SwiftUI views the macOS and iOS apps share: the player (`player`) and the acknowledgements screen (`acknowledgements`), each MVVM ([ADR 0023](presentation-is-mvvm-and-styles-carries-the-design.md)), and the tokens and shared components they draw with (`styles`).

**A module may depend only on modules in its own layer or in any layer below it**, and only on those its row in the module map lists ([ADR 0002](module-map.md)). Dependencies point down, never up. Test and support targets obey the same law ([ADR 0019](tests-live-in-the-layer-of-what-they-test.md)). SwiftUI, AppKit, UIKit and Cocoa are imported in Presentation and by the apps, never below.

**No Business module imports a UI or Apple framework.** A core imports the Swift standard library and nothing else without a recorded reason (ADR 0015 §1). A Business module that is not a core is held to the same rule: `session` imports the standard library, including its concurrency, and the cores it runs. ADR 0015's other rules are about the shape of the cores: a CPU family generic over its bus, a console owning its memory map, concrete types on hot paths. A module that is not a core reaches a core only through that core's narrow interface.

**The apps run a console only through `session`.** The console is the session's own state, so every call into it happens in one place, one at a time and between frames: power-on, the boot, its frames and the reads between them. That is ADR 0015 §4's "one thread", kept as one isolation domain. Work that leaves the main actor runs in a `Task.detached` that the session owns, which is its frame loop. The player drives the session through `ConsoleSessionControls` (pause, resume, reset, stop and the snapshots), and its previews and tests use a fake in its place. Powering on belongs to whatever starts a run (5c's BIOS check, 5d's opening job), never to the player.

**The apps are not modules.** `iStation macOS` and `iStation iOS`, the app targets of `lib/src/darwin/iStation.xcodeproj`, start at `lib/src/darwin/apps/macos/Sources/iStationApp.swift` and `lib/src/darwin/apps/ios/Sources/iStationApp.swift` (each `@main`). They are the entry points and composition roots. Each builds the console session and the view-models from the library products it links (`PS1Core`, `EmuKit`) and holds no logic. Nothing imports them.

## Consequences

- Adding a module means declaring its layer first: its `Module` row in the map, its directory `source/<layer>/<name>/` (lowercase) and its target `<Layer><Name>`. [ADR 0002](module-map.md) lists what else lands in the same change.
- Shared code sinks to the lowest layer that needs it, so every user reaches it downward. A shared test fixture is a `Support` row no higher than the lowest layer whose tests use it: `SupportSandbox`, which Data's and Business's tests use, sits in Infrastructure.
- SwiftUI's needs are met inside Presentation and the apps and nowhere else. An OS mechanism a lower layer needs enters Infrastructure behind one interface, so the layers above can be tested over fakes. Business goes further and imports neither UI nor Apple frameworks, as above.
- "Business" and "a core" are no longer the same thing. A rule written for the cores, such as ADR 0015's shape and hot-path rules, binds `r3000a`, `ps1` and the cores to come, not `session`. A rule written for Business binds every Business module. A card or document that means the layer says Business.
- `session` is iStation's own code. Its row carries no `derivedFrom:`, and its files carry iStation's MIT header alone ([ADR 0014](own-code-is-mit-and-derived-code-keeps-its-notice.md)).
- Something else the apps do with a core, below the interface, goes into Business: a module beside `session`, or a part of it, by [ADR 0003](granular-modules.md)'s one concern. A screen's state stays in its view-model, which consumes Business and never mirrors state Business owns (ADR 0023).
- How the console is driven is tested without a window, and on real time in only one short test. `session` takes its clock in its initializer, so its tests move a clock of their own a sixtieth of a second at a time over BIOS images built in code (`tests/business/session/`). The player's tests and previews use fakes of `ConsoleSessionControls`.
- ADR 0023, written the same day before the session existed, has each app build the `PS1Console` and `PlayerViewModel(console:)` take it. Now the apps build the session, the session builds its console, and the view-model takes `ConsoleSessionControls`. ADR 0023's rule itself is unchanged: the apps are the composition roots and hold no logic.
- The apps are outside the module map, so the layer checks below don't read them.
- A change that would point an edge upward is an architecture change: a new ADR through the planning docs, never a clever import.
- The trade-off: Business no longer holds one kind of thing, so a reader can't take a Business module for a core. That was accepted because every other home for the runner was worse: logic where no check reads it, a UI framework within its reach, or frames run on the main actor.

## Enforcement

- **The build.** Every module is its own SwiftPM target, generated from the module map in `lib/src/darwin/Package.swift` with exactly the dependencies its row's `uses:` declares ([ADR 0002](module-map.md)). A module's test target depends on the module and its `testSupport:`, and a support target on its row's `uses:`.
  - `swift build --explicit-target-dependency-import-check=error` builds the modules and the `Support…` targets, but not the test targets; `swift test` builds those, without the flag. The strict build fails on an import of a module the importing target doesn't depend on at all. Measured 2026-10-31, the flag tolerates a module reached through a dependency's dependency, so `importsAreDeclared` is the stricter check.
  - `lib/scripts/cicd.sh --test` runs the strict build, then `swift test`. CI runs it as `cicd.sh --app darwin --test` (`.github/workflows/darwin.yml`) whenever `lib/scripts/changed.sh darwin` finds that `lib/src/darwin/` or the pipeline's own files changed since the latest release. When only documentation has changed, CI runs neither.
- **The layering checks.** `ArchitectureTests`, run by `swift test`, parses the map from `Package.swift` (or the copy `ISTATION_ARCHITECTURE_MANIFEST` names) and reads the Swift files under `source/` and `tests/`. Each failure names its rule in brackets and the file. In `lib/src/darwin/tests/architecture/LayeringTests.swift`:
  - `theMapIsNotEmpty` fails when no `Layer` case or no `Module` row parses, when a layer holds no module, and when a row names a layer the `Layer` enum lacks.
  - `everyModuleHasItsSourceDirectory` fails on a module whose `source/<layer>/<name>/` holds no Swift file, a directory in `source/` that is not a layer, and a directory in a layer with no `Module` row.
  - `declaredEdgesPointDown` fails on a `uses:` entry that is not a module, that names its own module, or that sits in a higher layer.
  - `importsAreDeclared` fails, in a module's source files, on:
    - an import of a `Support…` target or of any `…Tests` target, `ArchitectureTests` included;
    - an import of a module in a higher layer;
    - an import of a package module not in the importer's own `uses:` (direct, not transitive).
  - `everyDeclaredEdgeIsUsed` fails on a `uses:` entry that no file of the module imports.
  - `theModuleGraphHasNoCycles` fails on a cycle through the modules' `uses:`.
  - `uiFrameworksStayInPresentation` fails on `SwiftUI`, `AppKit`, `UIKit` or `Cocoa` imported by a source file of a module below Presentation, `session` included.
  - `testsObeyTheLayerLaw` fails on:
    - a `testSupport:` entry that is not a `Support` row, or that sits above its module's layer;
    - a test file importing a package target other than its module, that module's `uses:` and its `testSupport:`;
    - a `Support` row's `uses:` entry that is not a module, or that sits above the row's layer;
    - a support file importing a package target its row doesn't list.

  `LayeringTests`' other six tests hold the Presentation shape (ADR 0023, [ADR 0021](presentation-modules-stand-alone-and-preview-sample-data.md)).
- **The layer-context checks.** In `lib/src/darwin/tests/architecture/LayerContextTests.swift`:
  - `sourceCardsListTheMappedModules` fails when a source layer card's **Modules** line leaves out a module of its layer, or names one that isn't in it. `session` is on the Business card's line.
  - `testCardsExist` fails when a test layer has no card.
  - `theModuleMapADRMatchesTheMap` fails when ADR 0002's table lacks a module's row, has a row for one the map doesn't hold, or gives a module other edges than its `uses:`.
  - `testsMirrorTheSource` fails when a module has no tests, when `tests/` holds a directory that is not a layer, `support` or `architecture`, when a layer's test directory mirrors no module, and when a support directory has no `Support` row.
  - `theXcodeSchemeTestsEveryTarget` fails when the `macOS Personal` scheme doesn't test exactly every test target and `ArchitectureTests`.
  - `adrListsTheLayersInOrder` fails when this record's numbered list of layers differs from the map's `Layer` cases. It read ADR 0018's file until this record superseded it on 2026-11-22.
  - `everyPresentationModuleHasItsScheme` holds [ADR 0017](every-presentation-module-has-its-scheme.md).
- **What no check holds.**
  - **The apps.** The layer checks read the modules' and the support targets' own directories, never `apps/`. The entry point's imports were held to a declared list until that check went with `source/main/` on 2026-11-07. No check holds an app's imports to a list now. The project-rule checks read the apps' Swift files only for what they refuse everywhere: `toolsArePersonalOnly` (TraceKit and the personal-only names outside `#if PERSONAL_BUILD`, [ADR 0016](two-build-routines-and-a-fresh-start.md)), `nothingSpawnsProcesses` ([ADR 0022](nothing-starts-a-process-or-loads-code-at-runtime.md)) and `everyFileHasItsHeader` (ADR 0014).
  - **Imports of an app.** No check looks for one, and none is needed. `ModuleMap.packageTargets` (`tests/architecture/Repository.swift`) names only the modules, their test targets, the support targets and `ArchitectureTests`, and a package target can depend only on the package's own targets and on packages, never on an Xcode app target.
  - **Test and support targets.** They get the import and support-edge checks above, but not the unused-edge or UI-framework checks. An unused `testSupport:` or support `uses:` entry passes, and so does a UI framework imported by a test or support file below Presentation. No check has held those since the suite was written (2026-10-31); review does.
  - **Apple frameworks in Business.** `uiFrameworksStayInPresentation` refuses only the four UI frameworks, so a `Foundation` import in a core or in `session` passes. Review holds ADR 0015 §1 and this record's rule for Business.
  - **Running the console only through `session`.** `player` may import `BusinessPS1`, for `PS1Console.name`, and the apps aren't read. A `runFrame()` called from a view-model or an app would pass; review holds it.
  - **Imports under `#if`.** The import checks read imports as text and ignore `#if`. `session`'s `BusinessR3000A` edge is imported only under `#if PERSONAL_BUILD`, for the personal build's instruction counter, yet it counts as used for every build.
- **Proof (history).** Every architecture rule of 2026-10-31 was seen to fail on a planted violation, then the plant was removed ([Milestone A](../../assistant/darwin/MILESTONES.md#milestone-a--the-construction)):
  - There were 44 plants across `LayeringTests`, `LayerContextTests` and `ProjectRulesTests`, the entry-point plant among them.
  - A cycle, and `styles` using a sibling, were planted in a copy of the manifest through `ISTATION_ARCHITECTURE_MANIFEST`, because SwiftPM refuses to load them.

  Since then, the eight layering checks above have lost only their entry-point parts (2026-11-07), and MILESTONES records no later plant of them. This record adds no check. `session` passes them as written, and its row, card line, ADR 0002 row and test target in the `macOS Personal` scheme are held by the layer-context checks above.
