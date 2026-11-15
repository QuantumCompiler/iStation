# ADR 0021 — Every Presentation module stands alone, and its views preview each visible state over sample data, never the user's files

**Status:** Accepted · **Date:** 2026-11-14 · Supersedes [ADR 0006](presentation-previews.md) and [ADR 0009](previews-never-carry-the-users-library.md)

## Context

[ADR 0006](presentation-previews.md) (2026-10-31) made each Presentation module build and test on its own and gave every view named previews over in-module fakes. Without them, a screen's look would be checked only by running the whole app with the user's own BIOS and games — slow, unrepeatable, and impossible without those files — and working on one place should not mean building all of them. [ADR 0009](previews-never-carry-the-users-library.md) (the user's call, 2026-11-02) kept the previews on sample games instead of a recording of the user's library, which would have carried the user's titles and serials into a repository meant to be public.

Both records describe the library app, which v0.0.1's item 3b retired on 2026-11-07 ([ADR 0016](two-build-routines-and-a-fresh-start.md) §4, [Milestone F](../../assistant/darwin/MILESTONES.md#milestone-f--the-skeleton-and-both-build-routines)). What they name is gone: `PresentationSettings` and the `iStation` executable in their commands; the `shell`, `library`, `settings` and `app` modules; `PreviewLibrary`, whose fakes stood in for a store, a scanner, a starter and a detector; the sample games `LibraryScanner` reported for the disc fixtures; `RecordedLibraryFileTests`, whose `library.json` recorded the encoder writing those samples. The recording of the user's library that 0006 planned for item 1a was never made. `SupportDiscFixtures` remains as the ISO 9660 tests' fixtures and feeds no preview. v0.0.1's pre-merge docs pass found both records describing what no longer exists (2026-11-14). The rules stand, and this record restates them for today's Presentation modules — `styles`, `player` and `acknowledgements`, the `EmuKit` product — and for the user's own files: BIOS images, which the tools in `lib/src/darwin/tools/` run today, and the BIOS images and games the apps import from v0.2.0 ([ROADMAP](../../assistant/darwin/ROADMAP.md)).

Since those records, the code and the decisions have moved, and this record carries what moved:

- Each Presentation module also has its own shared Xcode scheme ([ADR 0017](every-presentation-module-has-its-scheme.md), 2026-11-14).
- The `Previews/` check skips comment lines — a file's SPDX header — before `#if DEBUG` (2026-11-07, [Milestone H](../../assistant/darwin/MILESTONES.md#milestone-h--provenance-headers-and-notices)).
- The player's preview runs over a real `PS1Console` that is powered off, not over a fake (2026-11-07, item 3b): `PlayerViewModel` takes the concrete console, and a console with no BIOS runs nothing. Neither view-model has an intent yet, so the previews reach their states through the view-model's initializer.
- A run with the user's own BIOS is the user's to start: the user runs it, or tells the agent to and gives the files' paths (the user's call, 2026-11-14; CLAUDE.md's [⚠ Sony's files invariant](../../assistant/darwin/CLAUDE.md#-istation-never-ships-downloads-or-commits-sonys-files-or-games)). Each file stays where the user keeps it, passed by path, never copied or committed, and named in reports only by its size and hash. [Milestone K](../../assistant/darwin/MILESTONES.md#milestone-k--the-reference-and-the-oracle) and [Milestone L](../../assistant/darwin/MILESTONES.md#milestone-l--the-bios-boots) consumed that call, and name the user's 23 images by version and hash. The gate, `lib/src/darwin/tools/gate/run.sh` (item 3g), names the BIOS in its `report.md` by size and hash, never by name.
- A trace, RAM dump or log from a run over the user's BIOS or a game is never committed as a fixture ([Milestone Q](../../assistant/darwin/MILESTONES.md#milestone-q--superpowers-inside-the-lifecycle-and-application-aware-skills), 2026-11-14, `istation-backlog-investigate-bug`'s fixture rule).

## Decision

### 1. Each Presentation module builds and tests on its own

Every Presentation module, `styles` included, is its own SwiftPM library target, `Presentation<Name>`, with its own test target, `Presentation<Name>Tests`, both generated from its `Module` row in `lib/src/darwin/Package.swift` ([ADR 0002](module-map.md)). From `lib/src/darwin/`, `swift build --target PresentationPlayer` builds the player and what it imports, nothing else, and `swift test --filter PresentationPlayerTests` runs its tests alone; in Xcode, the module's own shared scheme does both ([ADR 0017](every-presentation-module-has-its-scheme.md)). Building a module alone is for working on it: the apps are built and shipped only through their app schemes, by `lib/src/darwin/scripts/build.sh` ([ADR 0016](two-build-routines-and-a-fresh-start.md), [ADR 0017](every-presentation-module-has-its-scheme.md)).

### 2. Every view has named previews, one per visible state

- Every view in a Presentation module's `Views/` or `Components/` has at least one `#Preview("<State>")` in its own file, named for the state it shows.
- A view whose look changes with its view-model's state has one named preview for each state a person sees differently. Today each view-model lists those states as the cases of its `State`, and the previews match them one for one: `PlayerView` has "Nothing loaded" (`PlayerViewModel.State.nothingLoaded`); `AcknowledgementsView` has "Empty" and "Listed" (`.empty`, `.listed`).
- A composite view previews the composition's default state; its parts' states are previewed where the parts live.

### 3. Previews are hermetic and debug-only, over their module's own inputs

- A preview reads and writes no file, starts no process, reaches neither the network nor the user's folders, and runs no real BIOS or game — a test's rules, made stricter: a test writes inside its `Sandbox`, a preview nowhere ([⚠ Tests and previews never touch the real home folder](../../assistant/darwin/CLAUDE.md#-tests-and-previews-never-touch-the-real-home-folder)).
- It builds the view's **real view-model** and reaches each state **through the view-model's public API** — its initializer, and its intents once it has them — never by assigning its state.
- Its inputs come from the module's own `Previews/` (`PreviewPlayer`, `PreviewAcknowledgements`): fakes and values built in memory, or a real Business value that does nothing on its own, as `PreviewPlayer`'s powered-off `PS1Console()`. `PreviewAcknowledgements` builds its entries in memory and never reads the bundled `Acknowledgements.json`.
- Preview code is **debug-only**: every `#Preview` sits inside `#if DEBUG`, and every file in `Previews/` opens with it, so no Release build — the App Store routine's included — compiles any of it.
- Preview support is **per module**: a fake a second module wants is copied, since preview code is not shipped code and never justifies a shared module; no preview uses a test `Support…` target.

### 4. Preview data is sample data, and nothing derived from the user's files is committed

- **Preview data is sample data built in code**: values shaped like the real thing (`PreviewAcknowledgements.listed()`'s two entries are shaped like `Acknowledgements.json`'s), and, for a state that needs a BIOS or a game, programs and memory images built in code, as the tests build theirs.
- **The user's BIOS images and games are never committed** — the files themselves are governed by [ADR 0013](shipped-code-derives-only-from-permissive-references.md) §6 and CLAUDE.md's ⚠ Sony's files invariant — **and nothing derived from them is committed beyond the record the next point allows**: no title, file name or path, and no trace, RAM dump, TTY log or screenshot of a run over them — not as preview data, not as a test fixture, not in a document.
- **A run with the user's files is recorded — in a report, a backlog document or MILESTONES — by each file's size and hash** (the user's call, 2026-11-14), never by a file name, a title or a path. Its results are numbers and findings — instructions, frames, addresses, the first divergence's fields — and each file stays where the user keeps it, passed by path, never copied.

## Consequences

- Any place can be built, previewed and tested alone, with no BIOS, no game and no file of the user's.
- The cost: a new view comes with its previews; a new visible state with its preview and its sample data; a new module with its two targets, its tests and its scheme.
- **Previews show; tests decide.** A preview never substitutes for a view-model test: each module's tests in `lib/src/darwin/tests/presentation/<module>/` assert its view-models' states (`PlayerViewModelTests`, `AcknowledgementsViewModelTests`).
- A run over the user's files leaves sizes, hashes and numbers in the docs, never a file name, a title or a path; what it finds is committed only as a reproduction built in code or from an open suite.

## Enforcement

**Standing alone.** The module map generates each module's two targets ([ADR 0002](module-map.md)). `LayerContextTests.testsMirrorTheSource` fails, among other drift, on a module whose test directory holds no Swift file; `LayerContextTests.everyPresentationModuleHasItsScheme` on a Presentation module with no `<Target>.xcscheme` in `lib/src/darwin/iStation.xcodeproj/xcshareddata/xcschemes/`, or one whose Build action builds anything but `<Target>` or whose Test action tests anything but `<Target>Tests` ([ADR 0017](every-presentation-module-has-its-scheme.md)). `LayeringTests.importsAreDeclared` fails on a module's import of a package module its row doesn't list, of one in a higher layer, or of a test or `Support…` target — which also keeps preview code off the tests' fakes. CI's strict build (`swift build --explicit-target-dependency-import-check=error`, in `lib/scripts/cicd.sh --test`) fails on an import of a module its target doesn't depend on at all; a dependency's dependency passes it, which is why `importsAreDeclared` exists ([Milestone A](../../assistant/darwin/MILESTONES.md#milestone-a--the-construction)). Those declared imports are what let a module build alone; nothing builds each module on its own.

**Previews.** `LayeringTests.everyViewHasAPreview` reads every Swift file of every Presentation module — not the apps' targets — and fails on:

- a file under `Views/` or `Components/` that declares a view — a line opening `struct …: View` or `public struct …: View`, `View` first among its conformances — and has no named `#Preview("…")`;
- a file that contains `#Preview` and no `#if DEBUG`;
- a file under `Previews/` whose first line that is neither empty nor a `//` comment isn't `#if DEBUG`.

Each was seen to fail on a planted violation on 2026-10-31 ([Milestone A](../../assistant/darwin/MILESTONES.md#milestone-a--the-construction)); the comment-line skip dates from 2026-11-07. `ProjectRulesTests.noRealHome` fails on `homeDirectoryForCurrentUser`, `NSHomeDirectory`, `applicationSupportDirectory` or `FileManager.default.urls(for` in any Swift file under `source/` — preview code included — or under `tests/` outside `tests/architecture/`; `ProjectRulesTests.nothingSpawnsProcesses` on `Process(`, `posix_spawn`, `NSTask`, `dlopen(` or C's `system(` in any Swift file under `source/` or `apps/`.

Held by review: a preview for each visible state beyond the first; a view the pattern doesn't see (a `private` one, or one whose `View` follows another conformance); each `#Preview` inside its file's `#if DEBUG` block, not beside it; a preview reading no file and reaching no network; states reached through the view-model's API, not assigned; fakes copied, not shared.

**The user's files.** `ProjectRulesTests.noGameOrFirmwareFiles` fails on any `.iso .bin .img .cue .m3u .chd .cso .zso .gz .pbp .ecm .pup .rom .mec .nvm` file in the repository outside any folder named `.git`, `.build`, `.swiftpm`, `build`, `DerivedData` or `worktrees` ([ADR 0013](shipped-code-derives-only-from-permissive-references.md)). What is derived from the user's files has no check — no test can tell sample data from the user's — so review holds it: a change that commits a title, a file name, a path, or a trace, dump, log or screenshot of a run over the user's files is rejected by citing this record. The gate's `run.sh` writes its output to a new temporary folder unless `--out` names another, which must be empty, and names the BIOS in `report.md` by its size in bytes and the first 16 hex digits of its SHA-256.
