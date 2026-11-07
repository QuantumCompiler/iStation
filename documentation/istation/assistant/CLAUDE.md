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
| [**reference/**](../reference/README.md) | The contracts iStation builds against and writes: TraceKit's trace formats, from item 3c. |

**How work flows:** discussed in chat → a line in ROADMAP.md (and SPEC.md if product shape changes) → its own backlog document once specced → an agent builds it straight from that document → folded into MILESTONES.md, and the backlog document deleted. There is no separate TODO file.

**Repo-wide process is recorded here** (the router's rule): versioning, CI and release for the whole repository live in this file.

**The project-local skills** in `.claude/skills/` run each step: `/istation-backlog-investigate-spike` and `/istation-backlog-create-spike`, `/istation-backlog-create-item`, `/istation-backlog-investigate-bug`, `/istation-backlog-execute-item` (and `-execute-group`, `-execute-call-resolution`, `-swap-item`, `-swap-version`), `/istation-maintenance-update-documents`, `-summarize-pull-request`, `-summarize-release`, `-update-release`.

---

## What this is

iStation is two native Apple apps with PlayStation emulators written in Swift — macOS (PS1 and PS2) and iOS (PS1) — eligible for Apple's App Stores. **Re-envisioned 2026-11-07 (the user's call)** by the brief "PS1 and PS2 emulators in Swift (App Store-eligible)": shipped code is ported only from permissively licensed references — PS1 from ProjectPSX (MIT), PS2 from Play! (BSD) — while the more accurate GPL emulators, SwanStation and PCSX2, are black-box oracles whose guest-visible behaviour is recorded and compared ([ADR 0013](../adrs/shipped-code-derives-only-from-permissive-references.md)). Every app has an App Store release routine and a personal routine with debugging and tracing tools ([ADR 0016](../adrs/two-build-routines-and-a-fresh-start.md)). iStation's own code is MIT.

The repository holds the package's first shape (since v0.0.1's item 3b, 2026-11-07): the four disc-format readers kept for v0.2.0, a powered-off PS1 console, EmuKit's player and acknowledgements views, and the macOS and iOS apps with both build routines. No emulator code exists yet: the R3000A and the PS1 console arrive with items 3e and 3f. See [SPEC.md](SPEC.md) for scope and [MILESTONES.md](MILESTONES.md) for what has shipped.

## Stack & environment

- **Language / framework:** Swift 6 in language mode 6 — strict concurrency (the default, taken 2026-10-31) — with SwiftUI and Observation; macOS 14 Sonoma or later.
- **Build:** Swift Package Manager, `src/istation/Package.swift` (swift-tools-version 6.0; macOS 14 and iOS 17): one library target per module, generated from the module map, grouped into the library products `PS1Core` and `EmuKit` (`TraceKit` from item 3c; `PS2Core` with the PS2 work). The apps are two targets in `iStation.xcodeproj` at the repository root — `iStation macOS` and `iStation iOS`, sources in `src/istation/apps/` — each with two routines ([ADR 0016](../adrs/two-build-routines-and-a-fresh-start.md)): **Personal** is the Debug configuration (`apps/Config/Personal.xcconfig`, `PERSONAL_BUILD`, `get-task-allow`, JIT on) and **App Store** the Release configuration (`apps/Config/AppStore.xcconfig`, App Sandbox, read-only user-selected files, `allow-jit` on macOS). One shared scheme per app per routine: `macOS Personal`, `macOS App Store`, `iOS Personal`, `iOS App Store`. `swift build` from `src/istation/` builds the package alone. Bundle identifiers are placeholders (`local.istation.macos`, `local.istation.ios`) until the user's App Store Connect identifiers exist (v1.0.0).
- **Tests:** Swift Testing (the default, taken 2026-10-31, over the scaffold's XCTest): `swift test` from `src/istation/`, which also runs the architecture checks.
- **Platforms / devices:** macOS 14+ on Apple Silicon (PS1 and PS2) and iOS (PS1, interpreter only). AArch64 only: Intel Macs aren't supported. Development host as of 2026-11-07: macOS 27, Xcode 27.1, Swift 6.4.
- **Key dependencies:** none beyond Apple's SDK — [ADR 0013](../adrs/shipped-code-derives-only-from-permissive-references.md)'s allow-list is empty; every dependency is audited first, and Apple frameworks and Swift packages are preferred. The references — [ProjectPSX](https://github.com/BluestormDNA/ProjectPSX) (PS1, MIT, C#/.NET 10) and [Play!](https://github.com/jpd002/Play-) (PS2, BSD, C++) — are read and built locally, never vendored. The oracles — SwanStation and PCSX2 — are only built unmodified and run.
- **Licences:** iStation's own code MIT (the user's call, 2026-11-07); code ported from ProjectPSX keeps its MIT notice and code from Play! its BSD notices, in source and in each app's acknowledgements ([ADR 0014](../adrs/own-code-is-mit-and-derived-code-keeps-its-notice.md)). Nothing GPL ships.
- **Lint / format:** _TODO:_ no formatter or linter chosen (ROADMAP → Ideas).

---

## The architecture

Four layers, lowest to highest — **Infrastructure → Data → Business → Presentation** — and **a module depends only on its own layer or the layers below it** ([ADR 0001](../adrs/layer-enforcement.md)). The `modules` table at the top of `src/istation/Package.swift` is the one declaration of which module sits where and what it may import ([ADR 0002](../adrs/module-map.md)); one concern per module ([ADR 0003](../adrs/granular-modules.md)); tests mirror the source tree ([ADR 0004](../adrs/tests-mirror-architecture.md)). Each layer root carries a short `CLAUDE.md` card with its modules and rules.

**Enforced by:** one SwiftPM target per module with exactly its row's dependencies, `swift build --explicit-target-dependency-import-check=error`, and `ArchitectureTests` (`src/istation/tests/architecture/`: the layering and layer-context checks), run by `swift test` and in CI — an upward or undeclared edge fails the run.

### The cores: ported from permissive references, checked against oracles

A core lives in Business and imports no UI or Apple framework: one module per CPU family, generic over the bus it is given (the R3000A serves the PS1 and the PS2's I/O processor), and one module per console that owns its memory map and wires its devices, as ProjectPSX's project does; a device is carved into its own module only once the trace harness guards it. Hot paths use concrete types or `@inlinable` generics, never protocol-typed values; the frontend reaches a core only through one narrow, serializable interface ([ADR 0015](../adrs/a-core-is-a-cpu-module-and-a-console-module.md)). A port is checked by trace: instruction by instruction against the permissive reference (ProjectPSX, with trace logging added to its own source), and by guest-visible state against the GPL oracle (SwanStation, unmodified) — TraceKit finds the first divergence. Reference and oracle tools live under `tools/`, outside the shipped apps.

### The UI: MVVM, one styles module

Presentation is EmuKit: one module per user-facing place, each **`Views/` + `ViewModels/`** ([ADR 0005](../adrs/presentation-mvvm.md)): views lay out and bind; view-models (`@MainActor @Observable` classes) hold state and intents, read the core they are given, and never import SwiftUI, AppKit, UIKit or Cocoa. **`styles`** is the only source of colors, symbols, sizes and fonts and of shared components. The apps' targets are the composition roots: each builds the console and the view-models and holds no logic. Every view has named previews per visible state over in-module fakes, and every module builds and tests alone ([ADR 0006](../adrs/presentation-previews.md)). Debug views live in a module's `Debug/`, inside `#if PERSONAL_BUILD`. The Presentation layer card has the module list and the recipe.

---

## Invariants

### ⚠ Dependencies point down

**Rule.** A module imports only modules in its own layer or below, and only those its `Module` row in `Package.swift` lists. SwiftUI and AppKit stay in Presentation.

**Why.** Without a check, the shortest import that compiles wins, and the core becomes untestable without the app — the scaffold's `LibraryModel` was that tangle.

**Sub-rules.**
- A new module is a row, a source directory, a test directory, a card line and an ADR 0002 row in the same change.
- A need to point an edge up is an architecture change: a new ADR, never an import.

**Enforcement.** `ArchitectureTests/LayeringTests.swift` and `LayerContextTests.swift`; the per-module targets; CI's explicit-import build.

### ⚠ Shipped code comes only from permissive sources; GPL emulators are black boxes

**Rule.** Shipped code derives only from permissively licensed sources: ProjectPSX (MIT) for PS1, Play! and its own libraries (BSD) for PS2, iStation's own code (MIT) and public documentation (psx-spx, ps2tek). The source of a GPL emulator — SwanStation, PCSX2, DuckStation, PCSX-Redux (including its OpenBIOS), Beetle PSX/Mednafen, PCSX-ReARMed, Avocado, RPCS3 — is never opened, read or copied, and its disassembled or decompiled code is never transcribed. A GPL emulator may only be built unmodified and run, recording guest-visible state. Every ported file names its source file and keeps its notice.

**Why.** GPL code on the App Store is legally contested and the project can't grant an exception; ProjectPSX's and Play!'s licences require their notices to travel with the code ([ADR 0013](../adrs/shipped-code-derives-only-from-permissive-references.md), [ADR 0014](../adrs/own-code-is-mit-and-derived-code-keeps-its-notice.md)).

**Sub-rules.**
- A session or person that has read a GPL emulator's source writes no core code. The session that wrote the re-vision on 2026-11-07 had, under the earlier plans, so it wrote docs only.
- Recording an oracle uses its built-in debugger, trace and logging features first, else LLDB or Frida for guest state only; `revula_disassemble` and `revula_decompile` are never pointed at a GPL emulator.
- Every third-party dependency is audited before it is ported or linked (unrarsrc and Windows-only libraries stay out); an external package joins only on ADR 0013's allow-list.
- Nothing in the package or the apps starts a process or loads code at runtime.

**Enforcement.** `ArchitectureTests/ProjectRulesTests.swift` — any package or binary target not on the allow-list, and process spawning or `dlopen` anywhere in the package's sources or the apps', fail the run. Provenance headers gain their check with Architecture item A2, which gates the first ported module. What someone read has no mechanical check: review holds it, by each ported file's provenance line.

### ⚠ iStation never ships, downloads or commits Sony's files or games

**Rule.** No BIOS file, system software, disc image or game is ever in the repository, in a build, or fetched, bundled or mirrored by the apps. Users import their own through the file picker. OpenBIOS is not used, as a binary or otherwise; a PS1 high-level-emulated BIOS, if it comes, is written from documentation.

**Why.** Distributing them is not iStation's right, and a single committed file would taint the public repository ([ADR 0013](../adrs/shipped-code-derives-only-from-permissive-references.md) §6).

**Sub-rules.**
- Hermetic tests build their programs and memory images in code inside a `Sandbox`; open test suites (ps1-tests MIT, ps2autotests ISC) run in personal builds, and are committed only beside their licence through an allow-list.
- A run with the user's own BIOS dump is the user's to start.
- No Sony logos or artwork; describe compatibility only ("plays PS2 games").

**Enforcement.** `ArchitectureTests/ProjectRulesTests.swift` fails on any `.iso .bin .img .cue .m3u .chd .cso .zso .gz .pbp .ecm .pup .rom .mec .nvm` file in the repository outside build output.

### ⚠ View-models never import the UI toolkit

**Rule.** No file under a Presentation module's `ViewModels/` or `Models/` imports SwiftUI, AppKit, UIKit or Cocoa.

**Why.** The view-model is the seam that makes every screen's behavior testable without UI automation and every state previewable from fakes. One toolkit import there, and the next agent puts the logic back in the view — as the scaffold's `LibraryModel` had it, with `NSOpenPanel` inside.

**Sub-rules.**
- A view-model that seems to need a toolkit type is resolved downward: a chooser becomes a `Bool` the view binds `.fileImporter` to; a color becomes a `Platform` the view maps through `Palette`.
- Toolkit calls that are purely visual (Show in Finder, bringing the app to the front) live in `Views/`.

**Enforcement.** `ArchitectureTests/LayeringTests.swift` (`viewModelsImportNoUIFramework`).

### ⚠ Release builds carry no tools and no debugging entitlements

**Rule.** TraceKit, every debug view and every tool compile only into personal builds, under `#if PERSONAL_BUILD`; an App Store build's entitlements never carry `com.apple.security.cs.allow-unsigned-executable-memory` or `get-task-allow`.

**Why.** App Review rejects debugging and unrestricted executable memory, and a shipped trace recorder or memory viewer is a tool the store build must not contain ([ADR 0016](../adrs/two-build-routines-and-a-fresh-start.md)).

**Sub-rules.**
- The personal routine is the Debug configuration, the App Store routine the Release configuration; the package defines `PERSONAL_BUILD` only in debug.
- A debug view lives in its module's `Debug/` and opens with `#if PERSONAL_BUILD`; a core reaches TraceKit only through a generic tracer that release builds specialize to nothing.
- `CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO` stays in `apps/Config/AppStore.xcconfig`.

**Enforcement.** `ArchitectureTests/ProjectRulesTests.swift` (`toolsArePersonalOnly`, `appStoreEntitlementsAreClean`).

### ⚠ Tests and previews never touch the real home folder

**Rule.** Nothing in the package — sources, tests or previews — reaches the real home or Application Support folders. Tests write only inside a `Sandbox`; previews write nowhere. Only the apps' targets may reach the user's folders, through the system's file picker and their own containers.

**Why.** A test or preview that reads or writes the user's real files could read or destroy their BIOS dumps, memory cards and settings.

**Sub-rules.**
- Everything in the package that needs a file takes a URL or the file's bytes from its caller.
- Never run a real BIOS or game from a test or preview; build programs and memory images in code.

**Enforcement.** `ArchitectureTests/ProjectRulesTests.swift` (`noRealHome`).

---

## Codebase Map

| Layer | Module | Concern |
|---|---|---|
| Infrastructure | `bytes` | little-endian integer reads over byte buffers |
| Data | `iso9660` | cooked/raw CD sectors and the ISO 9660 directory tree |
| Data | `systemcnf` | SYSTEM.CNF: the boot key's console and serial |
| Data | `playlists` | .cue track files and .m3u disc entries |
| Business | `ps1` | the PS1 console (a powered-off placeholder until items 3e and 3f) |
| Presentation | `styles` | the visual tokens: palette, symbols, metrics, typography |
| Presentation | `player` | the player's screen |
| Presentation | `acknowledgements` | every notice the app carries |

The products: `PS1Core` (`ps1`) and `EmuKit` (`styles`, `player`, `acknowledgements`); the format readers join a product with v0.2.0's discs. The apps' targets in `iStation.xcodeproj` (`src/istation/apps/macos/`, `src/istation/apps/ios/`) are the entry points and composition roots, not modules. Detail per module lives in the layer cards and [DEVELOPER.md](DEVELOPER.md).

---

## Working process

### Where new work is written down

- **A new feature or theme** → first a line in [ROADMAP.md](ROADMAP.md) (and [SPEC.md](SPEC.md) if it changes scope or principles).
- **Specced** → its own document in [`backlog/`](../backlog/README.md), in the table the user names, listed in the index in build order.
- **Being built** → the agent works straight from the backlog document; its index row is marked 🚧 so parallel sessions see it is taken.
- **Completed** → recorded in [MILESTONES.md](MILESTONES.md); the backlog document and its row are deleted (see **Documentation and Status**).

### Working a backlog item

Take the **topmost 🟢 item** of the earliest version table, or the item the user names. Read its document — it is the working spec. Before writing code, resolve its **Open calls**: every `[user]` call answered by the user, every `[default: …]` taken and recorded as a dated decision. One item at a time; when it ships, stop and wait to be asked to continue. A bare "Continue" means: re-read this file, then take the topmost claimable item.

Runs against the user's real games, BIOS files or signing identity are the user's to start: an item that needs one says so, and the agent prepares the run and records its result rather than starting it. Building and running the references and oracles on open content (homebrew, the open suites, content built in code) is not such a run: the agent does it, under `tools/` or in a scratch folder — and a GPL oracle only unmodified, never reading its source.

### Decisions and questions

Decisions are dated and attributed ("the user's call, YYYY-MM-DD"). Questions are tagged by owner — `[user]` blocks the build, `[default: …]` is taken and veto-able, `(consumed decision)` is owned elsewhere. Ask only what is genuinely the user's, in plain language.

### Committing and pushing

Every task ends with a commit and a push (the user's call, 2026-11-07): a shipped backlog item, a docs pass, a spike's documents, a groomed table, a release sweep, any change the user asked for. A task that changed no file — a spike's report, an answer — commits nothing.

- **One commit per task**, staging only that task's paths, on the release branch (`v<x.y.z>`, today `v0.0.1`) — never on `stable`.
- **The message is exactly one line, in this pattern and nothing else:** `v<x.y.z> : Title Case Summary` — the live version (the branch name), a space, a colon, a space, then a short summary with every word capitalized. Example: `v0.0.1 : Documentation And Planning`. No body, no blank line, no trailers — not even a session's default attribution lines: this rule takes precedence over them.
- **Push right after committing**: `git push origin v<x.y.z>` (`git push -u origin v<x.y.z>` the first time). Never force-push, and never push `stable` or a tag: merging into `stable` and tagging stay the user's.
- A push that fails (no network, rejected) is reported with its error and left for the user, never retried with force.

### Versioning

One version per roadmap phase (the user's call, 2026-10-31; re-planned 2026-11-07 with the App Store brief): **v0.0.1** JIT verified, both build routines, the R3000A boots the BIOS · **v0.1.0** the first picture · **v0.2.0** PS1 games boot · **v0.3.0** Metal, audio and input · **v0.4.0** the iOS app · **v1.0.0** the PS1 release on the App Stores · **v2.x** PS2. A fix between releases is a patch, `v0.x.y`. Each release is built on a branch named for it (`v0.0.1` today) and, when its backlog table is empty, merged into `stable` and tagged `v<x.y.z>` (the user's call, 2026-10-31). The live number is carried by the branch name, `MARKETING_VERSION` in `src/istation/apps/Config/Version.xcconfig`, and ROADMAP's "In progress" heading — `/istation-maintenance-update-release` moves them together.

---

## Implementing a Feature

Every change satisfies this before merge:

- [ ] Tests for the new behavior pass and existing tests stay green: `swift test` (from `src/istation/`) — it includes the architecture checks.
- [ ] The strict build is clean: `swift build --explicit-target-dependency-import-check=error` (what CI runs).
- [ ] Format and lint: _TODO:_ no formatter configured yet — match the surrounding code.
- [ ] New tests are **hermetic** — no network, files only inside a `Sandbox`, never the real home folder, Launch Services, a real emulator or a real game; real runs are the user's to start.
- [ ] **The layer law holds**: a new module is a directory in its layer, a `Module` row in `Package.swift`, a line on its layer card, a row in ADR 0002's table, a test directory in `tests/<layer>/<module>/` and its test target in the `iStation` Xcode scheme — all in the same change (the layer-context check fails on any one alone).
- [ ] **Shipped code is clean**: it comes only from a permissive source (ProjectPSX, Play!, iStation's own, public documentation) — never from a GPL emulator's source or disassembly — and each ported file names its source file and keeps its notice, with the acknowledgements list updated ([ADR 0013](../adrs/shipped-code-derives-only-from-permissive-references.md), [ADR 0014](../adrs/own-code-is-mit-and-derived-code-keeps-its-notice.md)).
- [ ] **Hot paths use concrete types**: no protocol-typed value, unspecialized generic or allocation in per-instruction, per-pixel or per-sample code ([ADR 0015](../adrs/a-core-is-a-cpu-module-and-a-console-module.md)).
- [ ] **Release builds carry no tools**: TraceKit and every debug view sit under `#if PERSONAL_BUILD`; the release entitlements carry neither `allow-unsigned-executable-memory` nor `get-task-allow` ([ADR 0016](../adrs/two-build-routines-and-a-fresh-start.md)).
- [ ] **No game, BIOS or firmware file** is added anywhere, fixtures included — open test suites only beside their licence, through the allow-list; never OpenBIOS.
- [ ] **The user's data stays readable**: a new persisted field (settings, memory cards) decodes with a default; a save state carries its version ([ADR 0016](../adrs/two-build-routines-and-a-fresh-start.md) §5).
- [ ] **A view has its view-model and its previews**: new UI logic lives in a view-model or in `Library` (tested over fakes, every named state), not the view; every new or changed view has a named `#Preview` per visible state, debug-only, over the module's own fakes — never data from the user's own library ([ADR 0006](../adrs/presentation-previews.md), [ADR 0009](../adrs/previews-never-carry-the-users-library.md)).
- [ ] **Visuals come from `styles`**: no literal color, font or size in a feature view — a new need is a token; a component a second module wants is promoted to `styles`, never copied ([ADR 0005](../adrs/presentation-mvvm.md)).
- [ ] **A new place is a module**: `Views/` + `ViewModels/`, its `Module` row, its test directory, its place in the `EmuKit` product, its view-model built by the apps, its name on the Presentation card and in ADR 0002's table — in the same change.
- [ ] The docs validator is clean: `python3 scripts/validate_docs.py documentation` (from the repository root).
- [ ] The affected docs are updated in the same change (see **Documentation and Status**) — run `/istation-maintenance-update-documents` before opening a pull request.
- [ ] **Committed and pushed**: one commit for the task, its message exactly `v<x.y.z> : Title Case Summary`, pushed to `origin/v<x.y.z>` (Working process → **Committing and pushing**).

## Code Style

- Every public type and function carries a `///` comment saying what it is for, in plain words; comments explain why, not what (the scaffold's convention).
- Messages a person sees say what happened and what to do, in plain words with typographic apostrophes: "The BIOS couldn’t be read. Choose another file."
- Readers tolerate bad input: a truncated, foreign or corrupt file is `nil` or a thrown error, never a trap — check lengths before indexing.
- No singletons or global lookups: dependencies arrive through initializers; only the apps' targets construct the console and the view-models.
- Value types are `Sendable`; every view-model is `@MainActor`; work that must leave the main actor runs in a `Task.detached` inside the service that owns it.
- Match the surrounding code's conventions; when in doubt, find the closest existing analogue and follow it.

## Documentation and Status

When a work item ships, in the same change:

1. **Extend [MILESTONES.md](MILESTONES.md)** — goal, what was built, trade-offs, how it was verified.
2. **Delete the backlog document** and its index row; update any item whose gate it satisfied.
3. **Update [ROADMAP.md](ROADMAP.md)** — tick the line.
4. **Update the [Codebase Map](#codebase-map), [DEVELOPER.md](DEVELOPER.md)**, and for a module added, moved or retired: its layer card, the module map and ADR 0002's table.
5. **Update [SPEC.md](SPEC.md)** only if scope, non-goals or principles changed — with a dated note.
6. **A new standing rule** gets an ADR (a changed one, a superseding ADR) and, once enforced, a `⚠` section above.
7. **A changed contract** (an installed emulator's flags, the library file, a trace format) updates its [reference](../reference/README.md) document.
8. **Commit and push** the whole change — one commit, `v<x.y.z> : Title Case Summary` (Working process → **Committing and pushing**).

---

## Release and Install

- **Today (v0.0.1):** one script per routine, from `src/istation/`: `./scripts/build-personal.sh macOS|iOS` builds the personal routine (macOS signed to run locally, iOS for the Simulator) into `build/DerivedData`; `./scripts/archive-appstore.sh macOS|iOS` archives the App Store routine into `build/<platform>/iStation.xcarchive` — unsigned or ad-hoc, or, with `ISTATION_TEAM_ID` set, signed with the user's team and exported for App Store Connect. Signing for distribution, uploading and submitting are the user's.
- **A release** is its branch merged into `stable` and tagged `v<x.y.z>`; the tag, the merge and any publishing are the user's to do (`/istation-maintenance-update-release` prepares them). Pushing the release branch after each task is the agent's (Working process → **Committing and pushing**).
- **From v1.0.0:** App Store submission of each app, after checking App Review Guidelines section 4.7 (retro game console emulators) — see [SPEC.md → Distribution](SPEC.md#distribution). The signing identity, App Store Connect and every submission are the user's.
- **CI:** `.github/workflows/ci.yml` runs the strict build, `swift test` (with the architecture checks), both apps' personal routine unsigned, and the docs validator on a macOS runner, **only for an open pull request and for a merge into `stable`** — a push to a release branch runs nothing (the user's call, 2026-10-31). Between pull requests, the local `swift test` in the checklist above is the only guard.
