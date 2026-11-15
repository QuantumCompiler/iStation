# CLAUDE.md

Project context for coding agents working on **iStation**. Read this before making changes. The root [`README.md`](../../../../README.md) is the public-facing overview; this file and the rest of `lib/documentation/assistant/darwin/` are the contributor-facing detail. You arrived here from the [documentation router](../../CLAUDE.md). This file tells you **how to work here**; the sibling documents tell you **what** and **why**.

## Reading order & the docs system

`lib/documentation/assistant/darwin/` is a docs-as-source-of-truth system — work is discussed in chat, written up here, then handed to a coding session to build. Read in this order, then pick the one that matches your intent:

| Doc | Purpose |
|---|---|
| **CLAUDE.md** (this file) | The contributor entry point: how to work, the hard rules, the codebase map. |
| [**SPEC.md**](SPEC.md) | The product spec — what iStation is, how it identifies games, its scope, non-goals and principles. The "why". |
| [**ROADMAP.md**](ROADMAP.md) | The running board — each release at the theme level, plus decisions needed, ideas and explicit non-goals. |
| [**backlog/**](../../backlog/darwin/README.md) | **The work queue: one document per pending item.** Its README carries the format, lifecycle and the priority-ordered index; an agent builds an item straight from its document. |
| [**MILESTONES.md**](MILESTONES.md) | The record of finished work — what shipped and how it was built. |
| [**DEVELOPER.md**](DEVELOPER.md) | The module-by-module reference: directories, files, interfaces, build/test commands, recipes. |
| [**adrs/**](../../adrs/darwin/README.md) | The standing architecture rules, each with its reason and its enforcement. |
| [**reference/**](../../reference/darwin/README.md) | The contracts iStation builds against and writes: TraceKit's trace formats. |

**How work flows:** discussed in chat → a line in ROADMAP.md (and SPEC.md if product shape changes) → its own backlog document once specced → an agent builds it straight from that document → folded into MILESTONES.md, and the backlog document deleted. There is no separate TODO file.

**Repo-wide process is recorded here** (the router's rule): versioning, CI and release for the whole repository live in this file.

**The project-local skills** in `.claude/skills/` run each step, each opening with the "Which application?" ladder and working inside Superpowers where it fits ([Superpowers fits the docs-first lifecycle](#superpowers-fits-the-docs-first-lifecycle)): `/istation-backlog-investigate-spike` and `/istation-backlog-create-spike`, `/istation-backlog-create-item`, `/istation-backlog-investigate-bug`, `/istation-backlog-execute-item` (and `-execute-group`, `-execute-call-resolution`, `-swap-item`, `-swap-version`), `/istation-maintenance-update-documents`, `-summarize-pull-request`, `-summarize-release`, `-update-release`.

---

## What this is

iStation is two native Apple apps with PlayStation emulators written in Swift — macOS (PS1 and PS2) and iOS (PS1) — eligible for Apple's App Stores. **Re-envisioned 2026-11-07 (the user's call)** by the brief "PS1 and PS2 emulators in Swift (App Store-eligible)": shipped code is ported only from permissively licensed references — PS1 from ProjectPSX (MIT), PS2 from Play! (BSD) — while the more accurate GPL emulators, SwanStation and PCSX2, are black-box oracles whose guest-visible behaviour is recorded and compared ([ADR 0013](../../adrs/darwin/shipped-code-derives-only-from-permissive-references.md)). Every app has an App Store release routine and a personal routine with debugging and tracing tools ([ADR 0016](../../adrs/darwin/two-build-routines-and-a-fresh-start.md)). iStation's own code is MIT.

The repository holds the package's first shape (since v0.0.1's item 3b, 2026-11-07): the four disc-format readers kept for v0.2.0, EmuKit's player and acknowledgements views, and the macOS and iOS apps with both build routines. The emulator code so far is ProjectPSX's, ported: the R3000A interpreter (item 3e) and the PS1 console around it (3f) — its memory map, interrupts, timers, DMA and the GPU's timing, the other devices stubbed — which boots the user's BIOS images to the shell and passes ps1-tests' CPU tests up to known gaps (3g). See [SPEC.md](SPEC.md) for scope and [MILESTONES.md](MILESTONES.md) for what has shipped.

## Stack & environment

- **Language / framework:** Swift 6 in language mode 6 — strict concurrency (the default, taken 2026-10-31) — with SwiftUI and Observation; macOS 14 Sonoma or later.
- **Build:** Swift Package Manager, `lib/src/darwin/Package.swift` (swift-tools-version 6.0; macOS 14 and iOS 17): one library target per module, generated from the module map, grouped into the library products `PS1Core`, `EmuKit` and `TraceKit` (personal builds only; `PS2Core` with the PS2 work). The apps are two targets in `lib/src/darwin/iStation.xcodeproj`, beside the package — `iStation macOS` and `iStation iOS`, sources in `lib/src/darwin/apps/` — each with two routines ([ADR 0016](../../adrs/darwin/two-build-routines-and-a-fresh-start.md)): **Personal** is the Debug configuration (`apps/Config/Personal.xcconfig`, `PERSONAL_BUILD`, `get-task-allow`, `allow-jit` on macOS) and **App Store** the Release configuration (`apps/Config/AppStore.xcconfig`, App Sandbox, read-only user-selected files, `allow-jit` on macOS). One shared scheme per app per routine — `macOS Personal`, `macOS App Store`, `iOS Personal`, `iOS App Store` — and one per Presentation module, which builds and tests it alone ([ADR 0017](../../adrs/darwin/every-presentation-module-has-its-scheme.md)). `swift build` from `lib/src/darwin/` builds the package alone. The App Store routine's bundle identifiers are placeholders (`local.istation.macos`, `local.istation.ios`) until the user's App Store Connect identifiers exist (v1.0.0); the personal routine has its own, `….personal`, named "iStation Personal" ([Development runs on the personal channel](#development-runs-on-the-personal-channel)).
- **Tests:** Swift Testing (the default, taken 2026-10-31, over the scaffold's XCTest): `swift test` from `lib/src/darwin/`, which also runs the architecture checks.
- **Platforms / devices:** macOS 14+ on Apple Silicon (PS1 and PS2) and iOS (PS1, interpreter only). AArch64 only: Intel Macs aren't supported. Development host as of 2026-11-07: macOS 27, Xcode 27.1, Swift 6.4.
- **Key dependencies:** none beyond Apple's SDK — [ADR 0013](../../adrs/darwin/shipped-code-derives-only-from-permissive-references.md)'s allow-list is empty; every dependency is audited first, and Apple frameworks and Swift packages are preferred. The references — [ProjectPSX](https://github.com/BluestormDNA/ProjectPSX) (PS1, MIT, C#/.NET 10) and [Play!](https://github.com/jpd002/Play-) (PS2, BSD, C++) — are read and built locally, never vendored. The oracles — SwanStation and PCSX2 — are only built unmodified and run.
- **Licences:** iStation's own code MIT (the user's call, 2026-11-07); code ported from ProjectPSX keeps its MIT notice and code from Play! its BSD notices, in source and in each app's acknowledgements ([ADR 0014](../../adrs/darwin/own-code-is-mit-and-derived-code-keeps-its-notice.md)). Nothing GPL ships.
- **Lint / format:** _TODO:_ no formatter or linter chosen (ROADMAP → Ideas).

---

## The architecture

Four layers, lowest to highest — **Infrastructure → Data → Business → Presentation** — and **a module depends only on its own layer or the layers below it** ([ADR 0018](../../adrs/darwin/four-layers-dependencies-point-down.md)). The `modules` table at the top of `lib/src/darwin/Package.swift` is the one declaration of which module sits where and what it may import ([ADR 0002](../../adrs/darwin/module-map.md)); one concern per module ([ADR 0003](../../adrs/darwin/granular-modules.md)); tests mirror the source tree ([ADR 0019](../../adrs/darwin/tests-live-in-the-layer-of-what-they-test.md)). Each layer root carries a short `CLAUDE.md` card with its modules and rules.

**Enforced by:** one SwiftPM target per module with exactly its row's dependencies, `swift build --explicit-target-dependency-import-check=error`, and `ArchitectureTests` (`lib/src/darwin/tests/architecture/`: the layering and layer-context checks), run by `swift test` and in CI — an upward or undeclared edge fails the run.

### The cores: ported from permissive references, checked against oracles

A core lives in Business and imports no UI or Apple framework: one module per CPU family, generic over the bus it is given (the R3000A serves the PS1 and the PS2's I/O processor), and one module per console that owns its memory map and wires its devices, as ProjectPSX's project does; a device is carved into its own module only once the trace harness guards it. Hot paths use concrete types or `@inlinable` generics, never protocol-typed values; the frontend reaches a core only through one narrow, serializable interface ([ADR 0015](../../adrs/darwin/a-core-is-a-cpu-module-and-a-console-module.md)). A port is checked by trace: instruction by instruction against the permissive reference (ProjectPSX, with trace logging added to its own source), and by guest-visible state against the GPL oracle (SwanStation, unmodified) — TraceKit finds the first divergence. Reference and oracle tools live under `lib/src/darwin/tools/`, outside the shipped apps.

### The UI: MVVM, one styles module

Presentation is EmuKit: one module per user-facing place, each **`Views/` + `ViewModels/`** ([ADR 0020](../../adrs/darwin/presentation-is-mvvm-with-one-styles-module.md)): views lay out and bind; view-models (`@MainActor @Observable` classes) hold state and intents, read the core they are given, and never import SwiftUI, AppKit, UIKit or Cocoa. **`styles`** is the only source of colors, symbols, sizes and fonts and of shared components. The apps' targets are the composition roots: each builds the console and the view-models and holds no logic. Every view has named previews per visible state over in-module fakes, and every module builds and tests alone ([ADR 0021](../../adrs/darwin/presentation-modules-stand-alone-and-preview-sample-data.md)). Debug views live in a module's `Debug/`, inside `#if PERSONAL_BUILD`. The Presentation layer card has the module list and the recipe.

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

**Why.** GPL code on the App Store is legally contested and the project can't grant an exception; ProjectPSX's and Play!'s licences require their notices to travel with the code ([ADR 0013](../../adrs/darwin/shipped-code-derives-only-from-permissive-references.md), [ADR 0014](../../adrs/darwin/own-code-is-mit-and-derived-code-keeps-its-notice.md)).

**Sub-rules.**
- A session or person that has read a GPL emulator's source writes no core code. The session that wrote the re-vision on 2026-11-07 had, under the earlier plans, so it wrote docs only.
- Recording an oracle uses its built-in debugger, trace and logging features first, else LLDB or Frida for guest state only; `revula_disassemble` and `revula_decompile` are never pointed at a GPL emulator.
- Every third-party dependency is audited before it is ported or linked (unrarsrc and Windows-only libraries stay out); an external package joins only on ADR 0013's allow-list.
- Nothing in the package or the apps starts a process or loads code at runtime ([ADR 0022](../../adrs/darwin/nothing-starts-a-process-or-loads-code-at-runtime.md)); code a core generates into a `MAP_JIT` region is not loaded code.

**Enforcement.** `ArchitectureTests/ProjectRulesTests.swift` — any package or binary target not on the allow-list, and `Process(`, `posix_spawn`, `NSTask`, `dlopen(` or C's `system(` anywhere in the package's sources or the apps' (`nothingSpawnsProcesses`, [ADR 0022](../../adrs/darwin/nothing-starts-a-process-or-loads-code-at-runtime.md)), fail the run; any other way of starting a process or loading code is review's. Every Swift file's SPDX header, every ported file's provenance line and licence, and the acknowledgements list are checked by `everyFileHasItsHeader`, `portedModulesNameTheirSources` and `everyLicenceIsAcknowledged` (Milestone H). What someone read has no mechanical check: review holds it, by each ported file's provenance line.

### ⚠ iStation never ships, downloads or commits Sony's files or games

**Rule.** No BIOS file, system software, disc image or game is ever in the repository, in a build, or fetched, bundled or mirrored by the apps. Users import their own through the file picker. OpenBIOS is not used, as a binary or otherwise; a PS1 high-level-emulated BIOS, if it comes, is written from documentation.

**Why.** Distributing them is not iStation's right, and a single committed file would taint the public repository ([ADR 0013](../../adrs/darwin/shipped-code-derives-only-from-permissive-references.md) §6).

**Sub-rules.**
- Hermetic tests build their programs and memory images in code inside a `Sandbox`; open test suites (ps1-tests MIT, ps2autotests ISC) are fetched by their tools under `lib/src/darwin/tools/` (`ps1-tests/fetch.sh`, into a git-ignored `.build/` beside the suite's licence) and run from there; a suite is committed as a fixture only beside its licence, through an allow-list the first such fixture adds (the default of 2026-11-07).
- A run with the user's own BIOS dump is the user's to start: the user runs it, or tells the agent to and gives the files' paths (the user's call, 2026-11-14). Either way each file stays where the user keeps it, passed by path, never copied or committed, and named in reports only by its size and hash ([ADR 0021](../../adrs/darwin/presentation-modules-stand-alone-and-preview-sample-data.md) §4).
- No Sony logos or artwork; describe compatibility only ("plays PS2 games").

**Enforcement.** `ArchitectureTests/ProjectRulesTests.swift` fails on any `.iso .bin .img .cue .m3u .chd .cso .zso .gz .pbp .ecm .pup .rom .mec .nvm` file in the repository outside build output.

### ⚠ View-models never import the UI toolkit

**Rule.** No file under a Presentation module's `ViewModels/` or `Models/` imports SwiftUI, AppKit, UIKit or Cocoa.

**Why.** The view-model is the seam that makes every screen's behavior testable without UI automation and every state previewable from fakes. One toolkit import there, and the next agent puts the logic back in the view — as the scaffold's `LibraryModel` had it, with `NSOpenPanel` inside.

**Sub-rules.**
- A view-model that seems to need a toolkit type is resolved downward: a chooser becomes a `Bool` the view binds `.fileImporter` to; a color or symbol becomes a case of the view-model's `State` that the view maps to `styles` tokens, as `AcknowledgementsView` does with `AcknowledgementsViewModel.State`.
- Toolkit calls that are purely visual (Show in Finder, bringing the app to the front) live in `Views/`.

**Enforcement.** `ArchitectureTests/LayeringTests.swift` (`viewModelsImportNoUIFramework`).

### ⚠ Release builds carry no tools and no debugging entitlements

**Rule.** TraceKit, every debug view and every tool compile only into personal builds, under `#if PERSONAL_BUILD`; an App Store build's entitlements never carry `com.apple.security.cs.allow-unsigned-executable-memory` or `get-task-allow`.

**Why.** App Review rejects debugging and unrestricted executable memory, and a shipped trace recorder or memory viewer is a tool the store build must not contain ([ADR 0016](../../adrs/darwin/two-build-routines-and-a-fresh-start.md)).

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
| Data | `tracing` | TraceKit: trace records, files, the first divergence and checkpoints (personal builds only) |
| Business | `r3000a` | the R3000A interpreter, generic over its bus, coprocessor 2 and tracer (ported from ProjectPSX) |
| Business | `ps1` | the PS1 console: its memory map and wait states, interrupt controller, timers, DMA, the GPU's timing, stubs for the other devices, PS-EXE loading and the TTY (ported from ProjectPSX) |
| Presentation | `styles` | the visual tokens: palette, symbols, metrics, typography |
| Presentation | `player` | the player's screen |
| Presentation | `acknowledgements` | every notice the app carries |

The products: `PS1Core` (`r3000a`, `ps1`), `EmuKit` (`styles`, `player`, `acknowledgements`) and `TraceKit` (`tracing`, personal builds only); the format readers join a product with v0.2.0's discs. The apps' targets in `lib/src/darwin/iStation.xcodeproj` (`lib/src/darwin/apps/macos/`, `lib/src/darwin/apps/ios/`) are the entry points and composition roots, not modules. Detail per module lives in the layer cards and [DEVELOPER.md](DEVELOPER.md).

---

## Working process

### Where new work is written down

- **A new feature or theme** → first a line in [ROADMAP.md](ROADMAP.md) (and [SPEC.md](SPEC.md) if it changes scope or principles).
- **Specced** → its own document in [`backlog/`](../../backlog/darwin/README.md), in the table the user names, listed in the index in build order.
- **Being built** → the agent works straight from the backlog document; its index row is marked 🚧 so parallel sessions see it is taken.
- **Completed** → recorded in [MILESTONES.md](MILESTONES.md); the backlog document and its row are deleted (see **Documentation and Status**).

### Working a backlog item

Take the **topmost 🟢 item** of the earliest version table, or the item the user names. Read its document — it is the working spec. Before writing code, resolve its **Open calls**: every `[user]` call answered by the user, every `[default: …]` taken and recorded as a dated decision. One item at a time; when it ships, stop and wait to be asked to continue. A bare "Continue" means: re-read this file, then take the topmost claimable item.

Runs against the user's real games, BIOS files or signing identity are the user's to start: an item that needs one says so, and the agent prepares the run and records its result rather than starting it — unless the user tells it to make the run and gives it the files' paths (2026-11-14). Building and running the references and oracles on open content (homebrew, the open suites, content built in code) is not such a run: the agent does it, under `lib/src/darwin/tools/` or in a scratch folder — and a GPL oracle only unmodified, never reading its source.

### Decisions and questions

Decisions are dated and attributed ("the user's call, YYYY-MM-DD"). Questions are tagged by owner — `[user]` blocks the build, `[default: …]` is taken and veto-able, `(consumed decision)` is owned elsewhere. Ask only what is genuinely the user's, in plain language.

### Committing and pushing

Every task ends with a commit and a push (the user's call, 2026-11-07): a shipped backlog item, a docs pass, a spike's documents, a groomed table, a release sweep, any change the user asked for. A task that changed no file — a spike's report, an answer — commits nothing.

- **One commit per task**, staging only that task's paths, on the release branch (`v<x.y.z>`, today `v0.0.1`) — never on `stable`.
- **The message is exactly one line, in this pattern and nothing else:** `v<x.y.z> : Title Case Summary` — the live version (the branch name), a space, a colon, a space, then a short summary with every word capitalized. Example: `v0.0.1 : Documentation And Planning`. No body, no blank line, no trailers — not even a session's default attribution lines: this rule takes precedence over them.
- **Push right after committing**: `git push origin v<x.y.z>` (`git push -u origin v<x.y.z>` the first time). Never force-push, and never push `stable` or a tag: merging into `stable` and tagging stay the user's.
- A push that fails (no network, rejected) is reported with its error and left for the user, never retried with force.

### Superpowers fits the docs-first lifecycle

*(The user's call, 2026-11-14, taking Apogee's procedure.)* [Superpowers](https://github.com/obra/superpowers) (obra/superpowers, MIT) is a development method packaged as skills: brainstorming, plans, test-driven development, subagent-driven development, debugging, review, worktrees and finishing a branch. This repository enables it in `.claude/settings.json` (`superpowers@claude-plugins-official`, with `worktree.baseRef: head`). Its own `using-superpowers` rule makes a project's instructions outrank its skills, so **iStation's docs-first lifecycle governs, and Superpowers works inside it** at the steps below. Where this section says a Superpowers default gives way, this section is the instruction that rule asks for.

**Setup** (the user's, once per machine). The setting names the plugin but doesn't download it: each collaborator runs `claude plugin install superpowers@claude-plugins-official --scope project` once, in a trusted folder. A machine that already runs another copy (this repository's author runs a local clone, `superpowers@superpowers-dev`) either leaves the official one uninstalled or, before installing it, turns it off in its own git-ignored `.claude/settings.local.json` (`{"enabledPlugins": {"superpowers@claude-plugins-official": false}}`), so only one copy loads; `claude plugin list` shows which. The mapping was checked against Superpowers 7.0.2.

| Lifecycle step | iStation's skill | Superpowers at that step | Where iStation's rule wins |
|---|---|---|---|
| A new idea discussed | (chat) → `/istation-backlog-create-item` | `brainstorming` for the conversation | Its written design is a **backlog document** in the table the user names, with its ROADMAP line, never `docs/superpowers/specs/`. Its builder check may read the draft before it is placed, its subagent told the GPL rule; the check's "theirs" pile becomes the document's `[user]` calls and its "minor" pile `[default: …]` calls. **The brainstorm ends when the user approves that document**: brainstorming's hard gate ("invoke superpowers:writing-plans and no other skill"), and the same hand-off in its checklist, give way; planning or building waits for a later `/istation-backlog-execute-item`. Its visual companion runs with its project directory in the scratchpad, never the repository root. A throwaway build it offers is a probe in the scratchpad, over a `Sandbox` and never the real home folder or a real game; keeping it is a new item. |
| A design question | `/istation-backlog-investigate-spike` | `brainstorming` for the conversation; `dispatching-parallel-agents` for independent probes | A spike stays a probed, evidence-only **report**. Brainstorming's written design is that report, never `docs/superpowers/specs/`, and its hand-off to `writing-plans` gives way. Each parallel probe is read-only on the checkout — it runs in the scratchpad or a `Sandbox` and fixes nothing — and a probe that runs a GPL oracle runs it unmodified, as a black box. Nothing is written until "execute the spike", and then through `/istation-backlog-create-spike`. |
| A bug reported | `/istation-backlog-investigate-bug` | `systematic-debugging`, its Phases 1–3 | Phase 2's working examples and references are ProjectPSX, Play!, iStation's own code and public documentation (psx-spx, ps2tek); a GPL emulator is compared only through its runs and traces, never its source. Phase 1's instrumentation and Phase 3's minimal changes go in a scratchpad probe or a `Sandbox` test and leave the checkout as it was. Phase 4 (the fix) becomes the queued Maintenance item, with the reproduction as its failing test, unless the user asks for it built. |
| Building an item | `/istation-backlog-execute-item` (`-group` for a table) | `test-driven-development` for each change; for several tasks, `writing-plans` then `subagent-driven-development` (or `executing-plans` where no subagent tool exists), in a worktree from `using-git-worktrees` | **The backlog document is the approved design**, so brainstorming does not run again, and the user's request to build is the approval. The plan restates nothing the document decides; its `Spec:` line is the backlog document's path, the authority the implementers rule against; and it is a session-only file in the scratchpad (with no scratchpad, a `mktemp -d` directory outside the repository), **never committed** — no `docs/superpowers/plans/`. writing-plans' hand-off gives way: the plan is self-reviewed against the document and the method is the one named here, with no wait for the user. The worktree is consented to here (using-git-worktrees doesn't ask): it is made with EnterWorktree under `.claude/worktrees/` (a `git worktree add` fallback uses the same folder, never `.worktrees/`), from the release branch — the session is on that branch first (the repository's `worktree.baseRef` is `head`), and `git merge-base --is-ancestor v<x.y.z> HEAD` holds before the first task — and its baseline is `lib/scripts/cicd.sh --test`, a failing baseline stopping the build. Task commits (writing-plans' Commit steps, the implementers', executing-plans') stay on the item branch, with any message: the squash landing replaces them. Where no worktree can be made, the plan's Commit steps are dropped and the item lands as one uncommitted change. Every `Ruling:` (the ledger's, gathered in the final message's "Rulings I made") is carried, dated, into the item's MILESTONES entry with its decisions consumed — the same commit deletes the document that holds **Decisions made** — and an item that stops keeps them as dated **Decisions made** entries. A ruling that would reverse a `[user]` decision is not made: it stops the build, and a group run takes its stopped-item path. The tests are iStation's: hermetic (a `Sandbox`, never the real home, Launch Services, a real game or a BIOS), `lib/scripts/cicd.sh --test` (the strict build, then `swift test` with the architecture checks). |
| Checking the work | the item's Guardrails and Acceptance criteria | `verification-before-completion`; `requesting-code-review` / `receiving-code-review` | "Done" is the item's acceptance criteria and the documentation-and-status flow, each checked by running it. The review's range is `git merge-base v<x.y.z> HEAD`..`HEAD` for a worktree item, or the working tree against `HEAD` (untracked files included) for an uncommitted one — never a range from `stable`. |
| Landing it | the documentation-and-status flow | `finishing-a-development-branch` | Its menu gives way to one landing, once what the menu would have shown is settled: a residual Critical or Important finding from the final review stops the landing (a group run takes its stopped-item path); deferred minors and parked findings go in the item's report; a final review done as a self-review is said there. ExitWorktree with `action: "keep"` returns the session to the main checkout, still on the release branch, with no checkout or pull. There the index's uncommitted 🚧 edit is undone (the item branch carries the row's deletion, and a merge won't overwrite local changes), then `git merge --squash <item-branch>`, then `lib/scripts/cicd.sh --test` on the squashed result (a failure stops the landing, the worktree and branch kept). Then stage only the item's own paths, as **one commit per shipped item** in [Committing and pushing](#committing-and-pushing)'s one-line form (`v<x.y.z> : Title Case Summary`, no body, no trailers), **then `git push origin v<x.y.z>`** — iStation's agent commits and pushes, where Apogee's leaves both to the user. Then `git worktree remove .claude/worktrees/<name>` and `git branch -D <item-branch>` (which a squash-landed branch needs), both sanctioned here; never ExitWorktree's `remove`, which refuses a squash-landed branch without discarding it and deletes the branch itself. The item branch is never pushed. **Never a merge into `stable` and never a pull request into it mid-release**: that merge is the release, prepared at the boundary by `/istation-maintenance-update-release` and `/istation-maintenance-summarize-pull-request`, and opened and merged by the user. |
| Writing a skill | the repository's `.claude/skills/` | `writing-skills` | iStation's skills stay application-aware: each opens with the "Which application?" ladder and names the docs as `lib/documentation/<kind>/<app>/`. Their commit-and-push step is iStation's; no upstream pull request to Superpowers without the user's word. |

**What else holds**:
- **The clean room covers every agent Superpowers dispatches** ([ADR 0013](../../adrs/darwin/shipped-code-derives-only-from-permissive-references.md) §2–§3). Every subagent it dispatches — implementers, reviewers, the builder check, parallel probes, and an orchestrator, which carries the rule into every prompt it writes — is told the GPL rule in its prompt (the source of SwanStation, PCSX2, DuckStation, PCSX-Redux and its OpenBIOS, Beetle PSX/Mednafen, PCSX-ReARMed, Avocado and RPCS3 is never opened, read or copied; shipped code comes only from ProjectPSX, Play!, iStation's own code and public documentation). One given core work (porting, a core's tests, reviewing a core), or a probe that runs an oracle, is also pointed at no oracle's build folder. A session that has read a GPL emulator's source dispatches no core work: its prompts would carry what it read.
- Everything else in this file applies to Superpowers' steps as to any other: the invariants, the two build routines, and **staging only your own paths** in a checkout that other sessions share and commit from mid-run.
- Superpowers' working files stay out of every commit: `.superpowers/` (its plan workspaces and brainstorm mockups), `.claude/worktrees/` and `.claude/settings.local.json` are in the repository's `.gitignore`.
- A research subagent that starts without this file (the built-in Explore and Plan agents) is given these rules in its prompt, the GPL rule first.

### Development runs on the personal channel

*(The user's call, 2026-11-14, as Apogee's "Development runs on the dev channel".)* An App Store install of iStation is the user's real install: its container, settings, memory cards and imported-file bookmarks change only through what a release ships. So development never runs as it:

- **Live passes, smoke tests and "try it" steps use the personal build**, "iStation Personal" — `local.istation.macos.personal` and `local.istation.ios.personal`, set in `apps/Config/Personal.xcconfig` — which keeps its own container, defaults and bookmarks, and says what it is in the Finder, the menu bar and the Home Screen.
- **The App Store routine keeps the App Store identity** (`local.istation.macos`, `local.istation.ios`, in `apps/Config/AppStore.xcconfig`, placeholders until the user's App Store Connect identifiers exist at v1.0.0). It is built and archived to be checked, never launched against the user's data: the App Store app's container is read-only to development. Running both side by side is for the iOS Simulator, where neither touches a real install.
- **An app's identity lives in the routines' xcconfigs**, never in a target's build settings in the project, where it would override both.

**Enforcement.** `ArchitectureTests/ProjectRulesTests.swift` → `routinesHaveTheirOwnIdentity` fails when an app's two routines share a bundle identifier or leave one unset, when the personal build isn't named as one, or when a target setting in the project overrides them; `theIdentityCheckCatchesItsViolations` keeps the check honest against planted violations (Milestone R).

### Versioning

One version per roadmap phase (the user's call, 2026-10-31; re-planned 2026-11-07 with the App Store brief): **v0.0.1** JIT verified, both build routines, the R3000A boots the BIOS · **v0.1.0** the first picture · **v0.2.0** PS1 games boot · **v0.3.0** Metal, audio and input · **v0.4.0** the iOS app · **v1.0.0** the PS1 release on the App Stores · **v2.x** PS2. A fix between releases is a patch, `v0.x.y`. Each release is built on a branch named for it (`v0.0.1` today) and, when its backlog table is empty, merged into `stable` (the user's call, 2026-10-31). **`lib/release/VERSION` is the release, and the only thing that names one**; **the merge into `stable` is the release**: CI's `tag and release` job tags the merge commit `v<VERSION>` and publishes a GitHub release of its source (the user's call, 2026-11-14, as in Apogee). The apps' `MARKETING_VERSION` (`lib/src/darwin/apps/Config/Version.xcconfig`) is written from `VERSION` by `lib/src/darwin/scripts/build.sh`, and `ArchitectureTests` fail while it or ROADMAP's "In progress" heading disagrees; `lib/scripts/version-check.sh` (CI's `version bump`, on every pull request into `stable`) fails a release branch named for another version, and an already-released `VERSION` when the apps' code changed. `/istation-maintenance-update-release` sweeps `VERSION` first.

---

## Implementing a Feature

Every change satisfies this before merge:

- [ ] Tests for the new behavior pass and existing tests stay green: `swift test` (from `lib/src/darwin/`) — it includes the architecture checks.
- [ ] The strict build is clean: `swift build --explicit-target-dependency-import-check=error` (what CI runs).
- [ ] **Before a pull request, CI is rehearsed**: `lib/scripts/pr-ci.sh` (from the repository root) runs both pipelines' jobs on the test merge into `stable`, and passes; between pull requests, `lib/scripts/cicd.sh --all` is the same path.
- [ ] Format and lint: _TODO:_ no formatter configured yet — match the surrounding code.
- [ ] New tests are **hermetic** — no network, files only inside a `Sandbox`, never the real home folder, Launch Services, a real emulator or a real game; real runs are the user's to start.
- [ ] **The layer law holds**: a new module is a directory in its layer, a `Module` row in `Package.swift`, a line on its layer card, a row in ADR 0002's table, a test directory in `tests/<layer>/<module>/` and its test target in the `macOS Personal` scheme's tests — all in the same change (the layer-context check fails on any one alone).
- [ ] **Shipped code is clean**: it comes only from a permissive source (ProjectPSX, Play!, iStation's own, public documentation) — never from a GPL emulator's source or disassembly — and each file opens with its SPDX header — a ported one also with `// Ported from <repository>/<path> — <copyright>`, in a module the map marks `derivedFrom:` — with the acknowledgements list (`lib/src/darwin/apps/Acknowledgements.json`) updated ([ADR 0013](../../adrs/darwin/shipped-code-derives-only-from-permissive-references.md), [ADR 0014](../../adrs/darwin/own-code-is-mit-and-derived-code-keeps-its-notice.md)).
- [ ] **Hot paths use concrete types**: no protocol-typed value, unspecialized generic or allocation in per-instruction, per-pixel or per-sample code, and no class stored `var` there without `@exclusivity(unchecked)` ([ADR 0015](../../adrs/darwin/a-core-is-a-cpu-module-and-a-console-module.md)).
- [ ] **Release builds carry no tools**: TraceKit and every debug view sit under `#if PERSONAL_BUILD`; the release entitlements carry neither `allow-unsigned-executable-memory` nor `get-task-allow` ([ADR 0016](../../adrs/darwin/two-build-routines-and-a-fresh-start.md)).
- [ ] **No game, BIOS or firmware file** is added anywhere, fixtures included — open test suites are fetched by their tools, or committed only beside their licence through an allow-list; never OpenBIOS.
- [ ] **The user's data stays readable**: a new persisted field (settings, memory cards) decodes with a default; a save state carries its version ([ADR 0016](../../adrs/darwin/two-build-routines-and-a-fresh-start.md) §5).
- [ ] **A view has its view-model and its previews**: new UI logic lives in a view-model (tested over fakes, every named state), not the view; every new or changed view has a named `#Preview` per visible state, debug-only, over the module's own fakes and sample data — never anything derived from the user's own files ([ADR 0021](../../adrs/darwin/presentation-modules-stand-alone-and-preview-sample-data.md)).
- [ ] **Visuals come from `styles`**: no literal color, font or size in a feature view — a new need is a token; a component a second module wants is promoted to `styles`, never copied ([ADR 0020](../../adrs/darwin/presentation-is-mvvm-with-one-styles-module.md)).
- [ ] **A new place is a module**: `Views/` + `ViewModels/`, its `Module` row, its test directory, its place in the `EmuKit` product, its view-model built by the apps, its name on the Presentation card and in ADR 0002's table, and its own shared Xcode scheme (ADR 0017) — in the same change.
- [ ] The docs validator is clean: `python3 lib/scripts/validate_docs.py lib/documentation` (from the repository root).
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
7. **A changed contract** (a TraceKit trace or checkpoint format) updates its [reference](../../reference/darwin/README.md) document.
8. **Commit and push** the whole change — one commit, `v<x.y.z> : Title Case Summary` (Working process → **Committing and pushing**).

---

## Release and Install

- **Today (v0.0.1):** one entry point, from `lib/src/darwin/`: `./scripts/build.sh personal macOS|iOS` builds the personal routine, `iStation Personal.app` (macOS signed to run locally, iOS for the Simulator; `--unsigned` as CI builds it), into `build/DerivedData`; `./scripts/build.sh appstore macOS|iOS` archives the App Store routine into `build/<platform>/iStation.xcarchive` — unsigned or ad-hoc, or, with `ISTATION_TEAM_ID` set, signed with the user's team and exported for App Store Connect. `build.sh` first writes `MARKETING_VERSION` from `lib/release/VERSION`; the routines' scripts behind it, `build-personal.sh` and `archive-appstore.sh`, skip that when run alone. Signing for distribution, uploading and submitting are the user's.
- **A release** is its branch's pull request merged into `stable`: the merge is the release — CI tags it `v<VERSION>` and publishes its source on GitHub (`lib/scripts/release-from-pr.sh`, the user's call, 2026-11-14). Opening and merging that pull request are the user's (`/istation-maintenance-update-release` prepares them). Pushing the release branch after each task is the agent's (Working process → **Committing and pushing**).
- **From v1.0.0:** App Store submission of each app, after checking App Review Guidelines section 4.7 (retro game console emulators) — see [SPEC.md → Distribution](SPEC.md#distribution). The signing identity, App Store Connect and every submission are the user's.
- **CI:** two pipelines, each through the one build path, `lib/scripts/cicd.sh` (Apogee's shape; v0.0.1 item 4d): `.github/workflows/ci.yml`, the repository's — the docs validator (`docs`), `version bump` on a pull request into `stable`, and `tag and release` once one merges — and `.github/workflows/darwin.yml`, the Apple apps' — `what changed (darwin)` (`lib/scripts/changed.sh darwin`, since the latest release) and `build darwin`, the strict build, `swift test` and both apps' personal routine unsigned (`cicd.sh --app darwin --test`) on GitHub's `xcode-27` image, or, with nothing changed, the same job passing empty on Linux. **Only for an open pull request and for a merge into `stable`** — a push to a release branch runs nothing (the user's call, 2026-10-31). A required job never gets a job-level `if:`; `lib/scripts/required-checks.py --pr <N>` proposes the required checks and `--apply` sets them, which is the user's to run. Before a pull request, `lib/scripts/pr-ci.sh` rehearses both pipelines on the test merge into `stable`.
