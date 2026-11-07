# CLAUDE.md

Project context for coding agents working on **iStation**. Read this before making changes. The root [`README.md`](../../../README.md) is the public-facing overview; this file and the rest of `documentation/istation/assistant/` are the contributor-facing detail. You arrived here from the [documentation router](../../CLAUDE.md). This file tells you **how to work here**; the sibling documents tell you **what** and **why**.

## Reading order & the docs system

`documentation/istation/assistant/` is a docs-as-source-of-truth system — work is discussed in chat, written up here, then handed to a coding session to build. Read in this order, then pick the one that matches your intent:

| Doc | Purpose |
|---|---|
| **CLAUDE.md** (this file) | The contributor entry point: how to work, the hard rules, the codebase map. |
| [**SPEC.md**](SPEC.md) | The product spec — what iStation is, how it identifies games, its scope, non-goals and principles. The "why". |
| [**ROADMAP.md**](ROADMAP.md) | The running board — each release at the theme level, plus decisions needed, ideas and explicit non-goals. |
| [**backlog/**](../backlog/README.md) | **The work queue: one document per pending item.** Its README carries the format, lifecycle and the priority-ordered index; an agent builds an item straight from its document. |
| [**MILESTONES.md**](MILESTONES.md) | The record of finished work — what shipped and how it was built. |
| [**DEVELOPER.md**](DEVELOPER.md) | The module-by-module reference: directories, files, interfaces, build/test commands, recipes. |
| [**adrs/**](../adrs/README.md) | The standing architecture rules, each with its reason and its enforcement. |
| [**reference/**](../reference/README.md) | The contracts iStation builds against: the emulators' command lines, the library file. |

**How work flows:** discussed in chat → a line in ROADMAP.md (and SPEC.md if product shape changes) → its own backlog document once specced → an agent builds it straight from that document → folded into MILESTONES.md, and the backlog document deleted. There is no separate TODO file.

**Repo-wide process is recorded here** (the router's rule): versioning, CI and release for the whole repository live in this file.

**The project-local skills** in `.claude/skills/` run each step: `/istation-backlog-investigate-spike` and `/istation-backlog-create-spike`, `/istation-backlog-create-item`, `/istation-backlog-investigate-bug`, `/istation-backlog-execute-item` (and `-execute-group`, `-execute-call-resolution`, `-swap-item`, `-swap-version`), `/istation-maintenance-update-documents`, `-summarize-pull-request`, `-summarize-release`, `-update-release`.

---

## What this is

iStation is a personal, native macOS app that gives DuckStation (PS1), PCSX2 (PS2) and RPCS3 (PS3) one shared game library and one Play button. It scans the user's folders, identifies each game's console by reading the disc itself (SYSTEM.CNF's boot key, PS3's PARAM.SFO), launches the right emulator as a separate process with that emulator's own flags, comes back to the front when the game closes, and records last played and play time. It is a launcher by design: it emulates nothing and links no emulator code. See [SPEC.md](SPEC.md) for scope and [MILESTONES.md](MILESTONES.md) for what has shipped.

## Stack & environment

- **Language / framework:** Swift 6 in language mode 6 — strict concurrency (the default, taken 2026-10-31) — with SwiftUI and Observation; macOS 14 Sonoma or later.
- **Build:** Swift Package Manager, `src/istation/Package.swift` (swift-tools-version 6.0): one library target per module, generated from the module map, plus the `iStation` executable. `swift build` from `src/istation/`. In Xcode, open `iStation.xcodeproj` at the repository root (the user's call, 2026-10-31): a thin project with no targets of its own that opens the package, and one shared scheme, `iStation`, that runs the app and tests every test target. It is not the v1.0.0 move: whether iStation gets an Xcode app target (app icon, signing, notarization) is still a `[user]` call — such a target can depend on this package unchanged.
- **Tests:** Swift Testing (the default, taken 2026-10-31, over the scaffold's XCTest): `swift test` from `src/istation/`, which also runs the architecture checks.
- **Platforms / devices:** macOS 14+ on Apple Silicon. Development host as of 2026-10-31: macOS 27, Xcode 27.1, Swift 6.4. Intel support: _TODO:_ undecided (no item owns it yet).
- **Key dependencies:** none beyond Apple's SDK — [ADR 0008](../adrs/emulators-are-separate-programs.md)'s allow-list is empty. The emulators are the user's own installed apps, driven only by their command lines: never edited, linked or bundled before v2.0.0.
- **Lint / format:** _TODO:_ no formatter or linter chosen (ROADMAP → Ideas).

---

## The architecture

Four layers, lowest to highest — **Infrastructure → Data → Business → Presentation** — and **a module depends only on its own layer or the layers below it** ([ADR 0001](../adrs/layer-enforcement.md)). The `modules` table at the top of `src/istation/Package.swift` is the one declaration of which module sits where and what it may import ([ADR 0002](../adrs/module-map.md)); one concern per module ([ADR 0003](../adrs/granular-modules.md)); tests mirror the source tree ([ADR 0004](../adrs/tests-mirror-architecture.md)). Each layer root carries a short `CLAUDE.md` card with its modules and rules.

**Enforced by:** one SwiftPM target per module with exactly its row's dependencies, `swift build --explicit-target-dependency-import-check=error`, and `ArchitectureTests` (`src/istation/tests/architecture/`: the layering and layer-context checks), run by `swift test` and in CI — an upward or undeclared edge fails the run.

### The UI: MVVM, one styles module

Presentation is one module per user-facing place, each **`Views/` + `ViewModels/`** ([ADR 0005](../adrs/presentation-mvvm.md)): views lay out and bind; view-models (`@MainActor @Observable` classes) hold state and intents, read Business's `Library` (whose services are injected protocols), and never import SwiftUI, AppKit, UIKit or Cocoa. **`styles`** is the only source of colors, symbols, sizes and fonts and of shared components; **`shell`** owns the chrome and the route (`SidebarItem`); **`app`** composes the services and view-models. Every view has named previews per visible state over in-module fakes, and every module builds and tests alone ([ADR 0006](../adrs/presentation-previews.md)). The Presentation layer card has the module list and the recipe.

---

## Invariants

### ⚠ Dependencies point down

**Rule.** A module imports only modules in its own layer or below, and only those its `Module` row in `Package.swift` lists. SwiftUI and AppKit stay in Presentation.

**Why.** Without a check, the shortest import that compiles wins, and the core becomes untestable without the app — the scaffold's `LibraryModel` was that tangle.

**Sub-rules.**
- A new module is a row, a source directory, a test directory, a card line and an ADR 0002 row in the same change.
- A need to point an edge up is an architecture change: a new ADR, never an import.

**Enforcement.** `ArchitectureTests/LayeringTests.swift` and `LayerContextTests.swift`; the per-module targets; CI's explicit-import build.

### ⚠ Emulators are separate programs, driven only by their command line

**Rule.** iStation reaches an emulator only by starting its binary with its own flags and watching the process exit. Nothing links, embeds, loads or modifies emulator code.

**Why.** DuckStation's CC BY-NC-ND licence forbids modification and embedding; PCSX2 (GPLv3) and RPCS3 (GPLv2 only) cannot be linked into one binary. Separate processes are also why an emulator update needs no iStation change ([ADR 0008](../adrs/emulators-are-separate-programs.md)).

**Sub-rules.**
- Only `InfrastructureProcess` starts a process; Business reaches it only through `BusinessLaunching`.
- A flag changes only against the emulator's own argument parser, with [reference/emulator-launch-contract.md](../reference/emulator-launch-contract.md) and `LaunchContractTests` updated in the same change.
- An external package is added only after a licence review, on ADR 0008's allow-list.

**Enforcement.** `ArchitectureTests/ProjectRulesTests.swift` — process spawning outside `source/infrastructure/process/`, `dlopen`, and any package or binary target not on the allow-list fail the run.

### ⚠ iStation never ships, downloads or commits Sony's files or games

**Rule.** No BIOS file, PS3 system software, disc image or game is ever in the repository, in a build, or fetched by the app. Users supply their own.

**Why.** Distributing them is not iStation's right, and a single committed file would taint the public GPL repository the v1.0.0 release publishes.

**Sub-rules.**
- Tests build their discs in memory (`SupportDiscFixtures`) inside a `Sandbox`; never add a real image as a fixture.
- No Sony logos or artwork; describe compatibility only ("plays PS2 games").

**Enforcement.** `ArchitectureTests/ProjectRulesTests.swift` fails on any `.iso .bin .img .cue .m3u .chd .cso .zso .gz .pbp .ecm .pup .rom .mec .nvm` file in the repository outside build output.

### ⚠ View-models never import the UI toolkit

**Rule.** No file under a Presentation module's `ViewModels/` or `Models/` imports SwiftUI, AppKit, UIKit or Cocoa.

**Why.** The view-model is the seam that makes every screen's behavior testable without UI automation and every state previewable from fakes. One toolkit import there, and the next agent puts the logic back in the view — as the scaffold's `LibraryModel` had it, with `NSOpenPanel` inside.

**Sub-rules.**
- A view-model that seems to need a toolkit type is resolved downward: a chooser becomes a `Bool` the view binds `.fileImporter` to; a color becomes a `Platform` the view maps through `Palette`.
- Toolkit calls that are purely visual (Show in Finder, bringing the app to the front) live in `Views/`.

**Enforcement.** `ArchitectureTests/LayeringTests.swift` (`viewModelsImportNoUIFramework`).

### ⚠ A library file written by an older iStation keeps loading

**Rule.** `library.json` from any released version loads with its meaning intact, or is migrated by a named, tested step.

**Why.** Play history cannot be rebuilt by a rescan; losing the file loses it ([ADR 0007](../adrs/backwards-compatibility.md)).

**Sub-rules.**
- A new persisted field decodes with `decodeIfPresent` and a default; nothing is renamed, retyped or removed without a migration and a superseding ADR.
- A game's ID format (`<console>:<path>` or `<console>:id:<title ID>`) is part of the file format.
- A shape change adds a recording to `RecordedLibraryFileTests`; old recordings are never edited.

**Enforcement.** `DataStoreTests/RecordedLibraryFileTests.swift` (the v0.0.1 file, recorded 2026-10-31) and `LibraryStoreTests`.

### ⚠ Tests and previews never touch the real home folder

**Rule.** The real home and Application Support folders are reached only through `Locations.user()`, and only the entry point calls it. Tests write only inside a `Sandbox`; previews write nowhere.

**Why.** A test or preview that reads or writes `~/Library/Application Support/iStation/library.json` would read or destroy the user's real library and play history.

**Sub-rules.**
- Everything that needs a folder takes a `Locations` (or a URL derived from one).
- Never call Launch Services, a real emulator or a real game from a test or preview; inject `AppLookup`, `ProcessRunning` or the `Library` service fakes.

**Enforcement.** `ArchitectureTests/ProjectRulesTests.swift` (`onlyLocationsReachesTheRealHome`).

---

## Codebase Map

| Layer | Module | Concern |
|---|---|---|
| Infrastructure | `bytes` | little-endian integer reads over byte buffers |
| Infrastructure | `locations` | the user's standard folders, as one injectable value |
| Infrastructure | `bundles` | .app bundles: their binary; an installed app by bundle identifier |
| Infrastructure | `process` | start a child process, report its exit status and duration |
| Data | `catalog` | the library's record types: Platform, Game, BootTarget, LibraryFolder |
| Data | `iso9660` | cooked/raw CD sectors and the ISO 9660 directory tree |
| Data | `systemcnf` | SYSTEM.CNF: the boot key's console and serial |
| Data | `paramsfo` | PARAM.SFO key/value metadata |
| Data | `playlists` | .cue track files and .m3u disc entries |
| Data | `emulators` | each emulator's identity, app names and command line |
| Data | `store` | library.json: folders, games, settings |
| Business | `identification` | what one disc image or folder is: console, serial, title |
| Business | `scanning` | library folders into games |
| Business | `discovery` | find the installed emulator apps |
| Business | `launching` | start a game in its emulator and time the session |
| Business | `library` | the library's state and rules: folders, rescans, play history, the one running game |
| Presentation | `styles` | the visual tokens: palette, symbols, metrics, typography |
| Presentation | `shell` | the main window's chrome: sidebar route, search, toolbar, menus, alert |
| Presentation | `library` | the game grid, its tiles and empty state |
| Presentation | `settings` | the Settings window |
| Presentation | `app` | the composition root and the scenes |

The entry point `src/istation/source/main/iStationApp.swift` (the `@main` app) starts the composition over the real user's folders; it is not a module. Detail per module lives in the layer cards and [DEVELOPER.md](DEVELOPER.md).

---

## Working process

### Where new work is written down

- **A new feature or theme** → first a line in [ROADMAP.md](ROADMAP.md) (and [SPEC.md](SPEC.md) if it changes scope or principles).
- **Specced** → its own document in [`backlog/`](../backlog/README.md), in the table the user names, listed in the index in build order.
- **Being built** → the agent works straight from the backlog document; its index row is marked 🚧 so parallel sessions see it is taken.
- **Completed** → recorded in [MILESTONES.md](MILESTONES.md); the backlog document and its row are deleted (see **Documentation and Status**).

### Working a backlog item

Take the **topmost 🟢 item** of the earliest version table, or the item the user names. Read its document — it is the working spec. Before writing code, resolve its **Open calls**: every `[user]` call answered by the user, every `[default: …]` taken and recorded as a dated decision. One item at a time; when it ships, stop and wait to be asked to continue. A bare "Continue" means: re-read this file, then take the topmost claimable item.

Runs against the user's real emulators, games, BIOS files or signing identity are the user's to start: an item that needs one says so, and the agent prepares the run and records its result rather than starting it.

### Decisions and questions

Decisions are dated and attributed ("the user's call, YYYY-MM-DD"). Questions are tagged by owner — `[user]` blocks the build, `[default: …]` is taken and veto-able, `(consumed decision)` is owned elsewhere. Ask only what is genuinely the user's, in plain language.

### Versioning

One version per roadmap phase (the user's call, 2026-10-31): **v0.0.1** first build · **v0.1.0** cover art and titles · **v0.2.0** CHD support · **v0.3.0** per-game settings · **v0.4.0** controllers and couch mode · **v1.0.0** the launcher release · **v2.0.0** bundled emulators. A fix between releases is a patch, `v0.x.y`. Each release is built on a branch named for it (`v0.0.1` today) and, when its backlog table is empty, merged into `stable` and tagged `v<x.y.z>` (the user's call, 2026-10-31). The live number is carried by the branch name, `CFBundleShortVersionString` in `src/istation/scripts/build-app.sh`, and ROADMAP's "In progress" heading — `/istation-maintenance-update-release` moves them together.

---

## Implementing a Feature

Every change satisfies this before merge:

- [ ] Tests for the new behavior pass and existing tests stay green: `swift test` (from `src/istation/`) — it includes the architecture checks.
- [ ] The strict build is clean: `swift build --explicit-target-dependency-import-check=error` (what CI runs).
- [ ] Format and lint: _TODO:_ no formatter configured yet — match the surrounding code.
- [ ] New tests are **hermetic** — no network, files only inside a `Sandbox`, never the real home folder, Launch Services, a real emulator or a real game; real runs are the user's to start.
- [ ] **The layer law holds**: a new module is a directory in its layer, a `Module` row in `Package.swift`, a line on its layer card, a row in ADR 0002's table, a test directory in `tests/<layer>/<module>/` and its test target in the `iStation` Xcode scheme — all in the same change (the layer-context check fails on any one alone).
- [ ] **Emulators stay separate**: launching goes through `BusinessLaunching` → `InfrastructureProcess`; a changed flag updates the launch contract and its tests; no new package without a licence review on ADR 0008's allow-list.
- [ ] **No game, BIOS or firmware file** is added anywhere, fixtures included.
- [ ] **The library file stays compatible**: a new persisted field decodes with `decodeIfPresent` and a default; a shape change adds a recording to `RecordedLibraryFileTests`.
- [ ] **A view has its view-model and its previews**: new UI logic lives in a view-model or in `Library` (tested over fakes, every named state), not the view; every new or changed view has a named `#Preview` per visible state, debug-only, over the module's own fakes and the sample games — never data from the user's own library ([ADR 0006](../adrs/presentation-previews.md), [ADR 0009](../adrs/previews-never-carry-the-users-library.md)).
- [ ] **Visuals come from `styles`**: no literal color, font or size in a feature view — a new need is a token; a component a second module wants is promoted to `styles`, never copied ([ADR 0005](../adrs/presentation-mvvm.md)).
- [ ] **A new place is a module**: `Views/` + `ViewModels/`, its `Module` row, its test directory, its `SidebarItem` in `shell` if the sidebar reaches it, its view-model in `app`, its name on the Presentation card and in ADR 0002's table — in the same change.
- [ ] The docs validator is clean: `python3 scripts/validate_docs.py documentation` (from the repository root).
- [ ] The affected docs are updated in the same change (see **Documentation and Status**) — run `/istation-maintenance-update-documents` before opening a pull request.

## Code Style

- Every public type and function carries a `///` comment saying what it is for, in plain words; comments explain why, not what (the scaffold's convention).
- Messages a person sees say what happened and what to do, in plain words with typographic apostrophes: "PCSX2 isn’t set up yet. Choose its app in Settings (⌘,)."
- Readers tolerate bad input: a truncated, foreign or corrupt file is `nil` or a thrown error, never a trap — check lengths before indexing.
- No singletons or global lookups: dependencies arrive through initializers; only `PresentationApp` constructs the real services, and only the entry point calls `Locations.user()`.
- Value types are `Sendable`; `Library` and every view-model are `@MainActor`; work that must leave the main actor runs in a `Task.detached` inside the service that owns it.
- Match the surrounding code's conventions; when in doubt, find the closest existing analogue and follow it.

## Documentation and Status

When a work item ships, in the same change:

1. **Extend [MILESTONES.md](MILESTONES.md)** — goal, what was built, trade-offs, how it was verified.
2. **Delete the backlog document** and its index row; update any item whose gate it satisfied.
3. **Update [ROADMAP.md](ROADMAP.md)** — tick the line.
4. **Update the [Codebase Map](#codebase-map), [DEVELOPER.md](DEVELOPER.md)**, and for a module added, moved or retired: its layer card, the module map and ADR 0002's table.
5. **Update [SPEC.md](SPEC.md)** only if scope, non-goals or principles changed — with a dated note.
6. **A new standing rule** gets an ADR (a changed one, a superseding ADR) and, once enforced, a `⚠` section above.
7. **A changed contract** (an emulator's flags, the library file) updates its [reference](../reference/README.md) document.

---

## Release and Install

- **Today (v0.0.1):** `./scripts/build-app.sh` (from `src/istation/`) builds `build/iStation.app`, ad-hoc signed, for the user's own Mac; copy it to /Applications. `swift run iStation` runs it unbundled.
- **A release** is its branch merged into `stable` and tagged `v<x.y.z>`; the tag, the merge and any publishing are the user's to do (`/istation-maintenance-update-release` prepares them).
- **From v1.0.0:** the seven-step pipeline in [SPEC.md → Distribution](SPEC.md#distribution) — Developer ID signing with hardened runtime, notarization, a notarized `.dmg`, a GitHub release beside the source tag, and a Sparkle appcast. The signing identity, notarization and publishing are the user's.
- **CI:** `.github/workflows/ci.yml` runs the strict build, `swift test` (with the architecture checks) and the docs validator on a macOS runner, **only for an open pull request and for a merge into `stable`** — a push to a release branch runs nothing (the user's call, 2026-10-31). Between pull requests, the local `swift test` in the checklist above is the only guard.
