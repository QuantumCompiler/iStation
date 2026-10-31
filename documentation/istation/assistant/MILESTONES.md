# iStation — Milestones

The detailed record of finished work: what shipped, how it was built, the trade-offs taken and how it was verified. Pending work lives in [`backlog/`](../backlog/README.md); this file holds finished work only.

## Milestone A — The construction

**Goal.** Make iStation buildable over many sessions without the chat as memory: the user's Code Scaffold (2026-10-26) carved into a four-layer architecture with mechanically enforced dependencies, compiling and green; a network of `CLAUDE.md` files; this docs home; and the project-local lifecycle skills. It also delivers the first two lines of the v0.0.1 roadmap: the scaffold compiles, and its tests are green.

**Built** (construction, 2026-10-31):

- **The package** (`src/istation/Package.swift`, swift-tools-version 6.0, Swift 6 language mode, macOS 14): the `modules` table — the layer law's one declaration ([ADR 0002](../adrs/module-map.md)) — generating 21 library targets and 21 Swift Testing targets; 3 test-support targets (`SupportSandbox`, `SupportDiscFixtures`, `SupportLibraryFakes`); the `iStation` executable (`source/main/iStationApp.swift`); and `ArchitectureTests`.
- **The carve** of the scaffold's two targets (19 files) into 21 modules: Infrastructure `bytes`, `locations`, `bundles`, `process`; Data `catalog`, `iso9660`, `systemcnf`, `paramsfo`, `playlists`, `emulators`, `store`; Business `identification`, `scanning`, `discovery`, `launching`, `library`; Presentation `styles`, `shell`, `library`, `settings`, `app`. The scaffold's logic is unchanged except where the layers required a seam:
  - `CommandBuilder` → `LaunchContract.arguments(for:booting:options:)` (Data) + `GameLauncher` (Business: executable, process, `LaunchError`); `Platform.emulator` → `EmulatorChoice` (Business).
  - `EmulatorLocator` → `AppBundles` (Infrastructure) + `EmulatorDiscovery` (Business); the `NSWorkspace` bundle-ID lookup → Launch Services (`LaunchServicesLookup`), keeping AppKit out of the lower layers.
  - `GameLauncher.launch` → `ProcessRunner` behind `ProcessRunning` (Infrastructure), the one place a process is started.
  - `LibraryStore.merge` → `PlayHistory.merge` (Business); `LibraryStore` takes its file URL; `AppSettings.rpcs3GameFolder` became optional (nil = RPCS3's default), so no default reaches the real home; `ParamSFO` got its own error type.
  - The scanner's per-file probe → `DiscIdentifier.identify(file:hint:)` (Business `identification`), with the game-file extension sets beside it.
  - `LibraryModel` → Business `Library` (`@MainActor @Observable`, its services injected as protocols) plus one view-model per place: `ShellViewModel`, `LibraryGridViewModel`, `SettingsViewModel`, and `AppViewModel` as the composition root. `NSOpenPanel` → SwiftUI `.fileImporter`; `NSApp.activate(ignoringOtherApps:)` → `NSApplication.activate()` in `MainWindow`.
  - Every color, symbol, size and font moved to `styles` (`Palette`, `Symbols`, `Metrics`, `Typography`); `GameTile` takes a `GameTileModel`.
  - Every view has named `#Preview`s per visible state over in-module fakes ("Empty library", "Library", "Scanning", "Error", "Playing", "Nothing set up", "Set up", "First launch").
- **The tests**: the scaffold's 12 XCTest cases, ported to Swift Testing, split one directory per module and extended to 87 module tests, plus a `library.json` recorded from the real encoder at v0.0.1 (`RecordedLibraryFileTests`).
- **The checks** (`tests/architecture/`): `LayeringTests` (14 rules), `LayerContextTests` (5), `ProjectRulesTests` (4).
- **The scripts**: `src/istation/scripts/build-app.sh` (the scaffold's, at version 0.0.1); `scripts/validate_docs.py` (the docs validator); `.github/workflows/ci.yml` (the strict build, `swift test` and the validator on `macos-15`; built to run on every push and pull request, narrowed the same day to pull requests and merges into `stable` — the user's call, 2026-10-31).
- **The docs**: the root `CLAUDE.md` and `README.md`; the [router](../../CLAUDE.md); this home (CLAUDE, SPEC, ROADMAP, MILESTONES, DEVELOPER, the backlog with 1a, M1 and M2, ADRs 0001–0008, two reference contracts); a card at each of the eight layer roots in `source/` and `tests/`.
- **The skills** (`.claude/skills/`): the core set — `istation-backlog-investigate-spike`, `-create-spike`, `-create-item`, `-investigate-bug`, `-execute-item`, `-execute-call-resolution`, `istation-maintenance-update-documents` — and the optional set — `istation-backlog-execute-group`, `-swap-item`, `-swap-version`, `istation-maintenance-summarize-pull-request`, `-summarize-release`, `-update-release`.

**Trade-offs.**

- 21 modules for about 1,700 lines of scaffold, over two targets: more targets and directories, accepted because every edge is now a declared, checked fact ([ADR 0003](../adrs/granular-modules.md)).
- The module map lives in `Package.swift` as one-line rows that a test parses, rather than in a separate map file: the declaration *is* the build and cannot drift from it. The cost: the rows must keep their one-line shape.
- The checks are a Swift test target, not a separate script, so a routine `swift test` runs them. SwiftPM's `--explicit-target-dependency-import-check=error` catches only imports of modules a target does not depend on at all (measured: a dependency's dependency passes), so the test's own import scan is the line that requires direct declaration.
- Preview fakes are copied into each module (`shell`, `library`, `settings`), per [ADR 0006](../adrs/presentation-previews.md); preview games are real-shaped (the disc fixtures' titles and serials), not yet recorded from a real library.
- `.fileImporter` over `NSOpenPanel` keeps view-models AppKit-free, but loses the emulator chooser's /Applications start folder (M2).

**Verified** (2026-10-31, macOS 27, Xcode 27.1, Swift 6.4):

- `swift build --explicit-target-dependency-import-check=error` — clean, no warnings in Swift 6 language mode.
- `swift test` — 110 tests in 22 test targets, all passing (87 module tests, 23 architecture checks).
- **Every architecture rule was seen to fail on a planted violation, then the plant removed: 44 plants, 44 caught**, each failure naming its rule in brackets and the offending file — empty map and empty layer; unknown source directory; unmapped module; missing module and the hole it leaves in the mirror; a Presentation module without `Views/`/`ViewModels/`; upward, unknown, self and unused edges; a cycle; an undeclared (transitive) import; an upward import; importing the entry point; importing test code; SwiftUI below Presentation; SwiftUI in a view-model and AppKit in `Models/`; an unadmitted, an empty, and a root-level file in a Presentation module; `styles` using a sibling; a view importing Business; a literal padding in a component; a view without a preview; `#Preview` outside `#if DEBUG`; a `Previews/` file without the guard; upward and undeclared test imports; upward and unknown test support; an upward support edge; an undeclared support import; an unmapped support directory; orphan tests; card drift; a missing test card; ADR 0002 drift; ADR 0001 out of order; a `Process()` outside `InfrastructureProcess`; an external package; a `.bin` file in the repository; a real-home lookup outside `Locations`; `Locations.user()` in a test. The rules SwiftPM refuses to load (a cycle, `styles` using a sibling) were planted in a copy of the manifest via `ISTATION_ARCHITECTURE_MANIFEST`; SwiftPM itself refused a real cycle ("cyclic dependency declaration found").
- `./scripts/build-app.sh` — builds `build/iStation.app`, version 0.0.1, ad-hoc signed.
- **Smoke launch**: the app ran for six seconds over a sandbox home (`CFFIXED_USER_HOME`, which redirects both `homeDirectoryForCurrentUser` and Application Support), stayed up, found DuckStation, PCSX2 and RPCS3 in /Applications, and wrote its `library.json` only into the sandbox. No game was launched; that is the gate (1a).
- `python3 scripts/validate_docs.py documentation` — clean.

**Decisions consumed.**

- 2026-10-31: construct the project with the four-layer scheme, carving the scaffold into the modules now, rather than leaving the port as an item (the user's call).
- 2026-10-31: one version per roadmap phase (the user's call); releases on a `v<x.y.z>` branch, merged into `stable` and tagged (the user's call).
- 2026-10-31: a GitHub Actions workflow on a macOS runner (the user's call); the core and optional skill sets (the user's call).
- 2026-10-31: Swift 6 language mode; Swift Testing over XCTest; the skill prefix `istation`; lowercase module directories with `<Layer><Name>` targets; the module carve itself (the defaults, taken at construction — each veto-able).
- 2026-10-26: everything in [SPEC.md](SPEC.md)'s foundational choices (the user's design).
