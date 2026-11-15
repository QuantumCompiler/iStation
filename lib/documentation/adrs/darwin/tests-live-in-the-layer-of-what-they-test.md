# ADR 0019 — Tests live in the layer of what they test, and never touch the real home folder

**Status:** Accepted · **Date:** 2026-11-14 · Supersedes [ADR 0004](tests-mirror-architecture.md)

## Context

[ADR 0004](tests-mirror-architecture.md) (2026-10-31) gave the test tree the architecture's shape. A test tree with its own geography answers "where is this tested?" with a search instead of a path, and a test that reaches across layers freely is an undeclared dependency. ADR 0004 also made tests hermetic. The contributor guide's [invariant](../../assistant/darwin/CLAUDE.md#invariants) gives the reason today: a test that reads or writes the user's real files could read or destroy their BIOS dumps, memory cards and settings. These reasons still hold.

The library app's retirement ([ADR 0016](two-build-routines-and-a-fresh-start.md); the user's call to start the apps fresh, 2026-11-07; v0.0.1 item 3b, [Milestone F](../../assistant/darwin/MILESTONES.md#milestone-f--the-skeleton-and-both-build-routines)) left ADR 0004 describing modules and checks that no longer exist. This was found at v0.0.1's pre-merge docs pass, 2026-11-14:

- `SupportLibraryFakes` retired with the library app, and `makeSFO` was removed from `SupportDiscFixtures`. The scanner tests that shared `makeISO` with the format tests are gone too, and so is ADR 0004's example of a cross-layer test, scanning a folder of fixture discs.
- `Locations.user()`, its module `InfrastructureLocations` and the entry point `source/main/` retired. The apps' entry points, `apps/macos/Sources/iStationApp.swift` and `apps/ios/Sources/iStationApp.swift`, locate none of the user's folders, and nothing in the package does.
- Launch Services left with the launcher. Today the real emulators are the GPL oracle and the reference that the tools under `lib/src/darwin/tools/` build.
- ADR 0004's Enforcement no longer matches the checks. `noRealHome` lost its `InfrastructureLocations` exception at 3b and now skips only `tests/architecture/`. Nothing checks `.user()`: the entry-point rules were removed at 3b. And `testsObeyTheLayerLaw` does not apply the law "exactly as to the source": it checks the tests' imports of package targets and the support modules' edges, not everything the source's checks hold.

Today's checks also hold rules that no record states, or states without its check:

- `tests/` holds only the layers, `support/` and `architecture/`, and each test layer root has a card.
- A support module may use only modules, never another support module.
- The `macOS Personal` scheme tests every test target. The check is `theXcodeSchemeTestsEveryTarget`, written for the `iStation` scheme on 2026-10-31 ([Milestone B](../../assistant/darwin/MILESTONES.md#milestone-b--opening-in-xcode)) and moved to `macOS Personal` at 3b. [ADR 0017](every-presentation-module-has-its-scheme.md) restated the rule in passing as "ADR 0002's scheme check" (corrected to this record's, 2026-11-14), but [ADR 0002](module-map.md) never recorded it, and no record's Enforcement names the check.

This record restates the rule for today's tree. It decides nothing new.

## Decision

**The test tree follows the architecture, a test is written in the layer of the thing it tests, and every test is hermetic.**

1. **The mirror.** `lib/src/darwin/tests/<layer>/<module>/` mirrors `lib/src/darwin/source/<layer>/<module>/`. A new module brings its test directory in the same change. Beside the four layers, `tests/` holds only `support/` (the shared fixtures) and `architecture/` (`ArchitectureTests`). Each test layer root has its `CLAUDE.md` card.
2. **A test obeys its subject's dependency law.** It imports its module, that module's declared edges (`uses:`) and its declared test support (`testSupport:`), and nothing else of the package. A Data test does not reach into Business for its fixtures.
3. **A behavior spanning layers is tested in the highest layer involved.** For example, the R3000A's tracer writing TraceKit's records is a Business test (`tests/business/r3000a/TracingTests.swift`), which reaches `DataTracing` through `SupportR3000ATrace`.
4. **Shared fixtures and fakes sink like shared code.** Each is a `Support` row in `Package.swift`'s `testSupport` list and becomes a target `Support<Name>` built from `tests/support/<name>/`. It sits at the lowest layer whose tests use it and imports only the modules its row's `uses:` lists, at or below its layer. Today there are four:
   - `SupportSandbox` (infrastructure): `Sandbox`.
   - `SupportDiscFixtures` (data): `makeISO(files:raw:)`, a tiny ISO 9660 image, cooked or raw.
   - `SupportMIPS` (business): `MIPS`, a small R3000A assembler, and the registers by name.
   - `SupportR3000ATrace` (business, using `BusinessR3000A` and `DataTracing`): `TraceKitTracer`.
5. **Tests are hermetic.**
   - No network.
   - Nothing is written outside the test's own `Sandbox`, a uniquely named folder in the system's temporary directory that is removed when the value is released.
   - Never the real home folder or real Application Support.
   - Never the user's BIOS files or games: a test builds its programs, BIOS images and disc images in code (`makeBIOS` in `tests/business/ps1/Harness.swift`, `makeISO`).
   - Never a real emulator. A test runs iStation's own cores in its own process. The GPL oracles (today SwanStation, `tools/swanstation-oracle/`) and the reference (ProjectPSX, `tools/projectpsx-trace/`) are built and run through their tools under `lib/src/darwin/tools/`, never by a test, and `swift test` neither builds nor runs them.
   - Previews follow the same rule and write nowhere ([ADR 0021](presentation-modules-stand-alone-and-preview-sample-data.md) §3).
6. **Nothing in the package locates a folder of the user's.** Code that needs a file takes its URL or its bytes from its caller (`ISO9660(url:)`, `TraceWriter(url:header:)`, `PS1Console.powerOn(bios:)`), so a test hands it a `Sandbox` URL or bytes built in code. A resource the app bundles is read from the `Bundle` its caller names (`Acknowledgement.bundled(for:in:)`, `.main` by default). Only the apps' targets may reach the user's folders, through the system's file picker and their own containers. The tools under `lib/src/darwin/tools/` are outside the package and take the user's files by path.
7. **Every test target runs in the whole app's test action.** The `macOS Personal` scheme (`lib/src/darwin/iStation.xcodeproj/xcshareddata/xcschemes/macOS Personal.xcscheme`) tests exactly the map's test targets and `ArchitectureTests`. ⌘U there runs every test target, and a new module's test target joins the scheme in the same change.

## Consequences

- The test tree is a map of coverage: an empty `tests/<layer>/<module>/` is a visible hole and fails the check.
- Moving a module moves its tests in the same change.
- A test that cannot be written without an upward dependency is exposing a design fault in its subject.
- A cross-layer fixture is a support module's declared edge, not a test's import. `SupportR3000ATrace` re-exports `DataTracing` (`@_exported import`), so the R3000A's tests write and read TraceKit's files while `BusinessR3000A` itself depends on nothing.
- The library app's retirement left `SupportSandbox` in Infrastructure, and no Infrastructure test uses it now: only Data's and Business's tests declare it. It depends on nothing, so any layer's tests may declare it.
- `swift test` and `lib/scripts/cicd.sh --test` need no network, BIOS or game. Any run on the user's BIOS or a real emulator is done by a tool; `tools/gate/run.sh` over the user's BIOS is the user's to start: the user runs it, or tells the agent to and gives the files' paths (the user's call, 2026-11-14).
- A Presentation module's own scheme tests its bundle alone ([ADR 0017](every-presentation-module-has-its-scheme.md)). `macOS Personal` stays the one scheme that tests every bundle.
- Contributors read the hermetic rule as the guide's invariant **⚠ Tests and previews never touch the real home folder** ([CLAUDE.md](../../assistant/darwin/CLAUDE.md#invariants)). Its Rule and sub-rules are §5 and §6 here, and its Enforcement line names `noRealHome`. This record carries the reason and every check. Under the guide's rule for standing rules, a change to that invariant is a superseding record here.

## Enforcement

The module map generates each test target with only its module and its `testSupport:` as declared dependencies, and each `Support` target with its `uses:` ([ADR 0002](module-map.md)). In `ArchitectureTests`:

- `LayerContextTests.testsMirrorTheSource` fails on:
  - a `Module` row with no Swift file under `tests/<layer>/<module>/`;
  - a directory in `tests/` that is not a layer, `support` or `architecture`;
  - a directory in `tests/<layer>/` that mirrors no module;
  - a directory in `tests/support/` with no `Support` row.
- `LayerContextTests.testCardsExist` fails on a test layer without `tests/<layer>/CLAUDE.md`.
- `LayeringTests.testsObeyTheLayerLaw` fails on:
  - a `testSupport:` entry that is not a `Support` row, or that sits above its module's layer;
  - a test file that imports a package target other than its module, the module's `uses:` and its `testSupport:`;
  - a `Support` row whose `uses:` names anything but a module at or below its layer;
  - a support file that imports a package target outside its row's `uses:`.

  It reads only imports of the package's own targets. Among what passes it: an unused `testSupport:` or support `uses:` entry, a UI framework imported by a test or support file below Presentation, and a support row below the lowest layer whose tests use it.
- `LayerContextTests.theXcodeSchemeTestsEveryTarget` fails when `macOS Personal.xcscheme` can't be read, when a map test target (`<Layer><Name>Tests`) or `ArchitectureTests` is not among its testables, and on a testable that is neither. It reads the testables' identifiers only: one marked `skipped = "YES"` passes it.
- `ProjectRulesTests.noRealHome` fails on a line naming `homeDirectoryForCurrentUser`, `NSHomeDirectory`, `applicationSupportDirectory` or `FileManager.default.urls(for` in any Swift file under `source/` or `tests/`, previews and support modules included. It skips only `tests/architecture/`, whose checks spell those names. It makes no module exception and does not read `apps/`.
- `ProjectRulesTests.noGameOrFirmwareFiles` ([ADR 0013](shipped-code-derives-only-from-permissive-references.md)) fails on any `.iso .bin .img .cue .m3u .chd .cso .zso .gz .pbp .ecm .pup .rom .mec .nvm` file in the repository outside `.git`, build output and worktrees, so no BIOS or game can be a committed fixture.

Review holds the rest, which has no check:

- no network;
- nothing written outside a `Sandbox`;
- no BIOS or game read from outside the repository;
- no emulator, oracle or reference started from a test (`nothingSpawnsProcesses` reads `source/` and `apps/`, not `tests/`);
- §3's highest layer and §4's lowest layer;
- §6 beyond `noRealHome`'s four names;
- a testable left skipped in `macOS Personal`;
- previews writing nowhere.

This record adds no check. The mirror, the test cards and the tests' law were seen to fail on planted violations on 2026-10-31 ([Milestone A](../../assistant/darwin/MILESTONES.md#milestone-a--the-construction)). The scheme check was planted the same day for the `iStation` scheme ([Milestone B](../../assistant/darwin/MILESTONES.md#milestone-b--opening-in-xcode)), and on 2026-11-07 for `macOS Personal`, as was `noRealHome` without its exception, with `NSHomeDirectory()` in a test ([Milestone F](../../assistant/darwin/MILESTONES.md#milestone-f--the-skeleton-and-both-build-routines)).
