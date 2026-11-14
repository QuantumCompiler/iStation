# The code under `lib/src/darwin/` — the package, the apps, the Xcode project, the scripts and the tools, as Apogee's Apple app is laid out

**What / why.** Apogee keeps each application self-contained under `lib/src/<app>/`, its Apple app at `lib/src/darwin/`: the Xcode project (`Apogee.xcodeproj`), `scripts/` (its one build entry point `scripts/build.sh` and helpers), `source/{business,data,infrastructure,main,presentation}` with a layer card in each, and `tests/{architecture,business,data,infrastructure,presentation}`; repository-wide scripts sit in `lib/scripts/`. iStation's code is the same shape in other places: the package at `src/istation/` (94 files: `Package.swift`, `apps/`, `scripts/`, `source/`, `tests/`), the Xcode project at the root (`iStation.xcodeproj`, 4 shared schemes), and the reference and oracle tools at `tools/` (26 files: `gate`, `istation-run`, `jit-probe`, `projectpsx-trace`, `ps1-tests`, `swanstation-oracle`). This item moves them to Apogee's places (the user's call, 2026-11-14).

Measured, not guessed (2026-11-14, `git grep` outside the Xcode project): `src/istation` is written in 37 files (93 mentions), `iStation.xcodeproj` in 21 (41), `tools/` in 12 (40); the Xcode project holds 8 `path =` references to `src`, `documentation`, `tools` and `scripts`; `ci.yml` runs in `working-directory: src/istation`.

**Core constraint(s).** The layer law: the module map, `ArchitectureTests` and the scheme check keep working from the new root — `Repository.swift`'s root detection and `ISTATION_ARCHITECTURE_MANIFEST` included. Release builds carry no tools: the two routines' xcconfigs, entitlements and checks move intact. Shipped code from permissive sources only: provenance lines name reference files, not repository paths, and stay as they are. **The whole repository stays in Xcode's navigator** (the user's call, 2026-11-14, commit `48f2726`). The local signing team stays out of the repository (`Local.xcconfig`, git-ignored). Tests never touch the real home.

**Seam + files.** No module changes.
- `git mv src/istation lib/src/darwin` (package, `apps/`, `scripts/`, `source/`, `tests/`); `git mv iStation.xcodeproj lib/src/darwin/iStation.xcodeproj`, its groups and package reference re-pointed and its navigator still showing the whole repository; `git mv tools lib/src/darwin/tools`.
- `lib/src/darwin/scripts/build.sh`: the one entry point from outside, Apogee's form, over today's `build-personal.sh` and `archive-appstore.sh` (which it calls).
- A shared Xcode scheme per Presentation module — `styles`, `player`, `acknowledgements` — building the module and running its tests, as Apogee's darwin ADR 0004 gives each; the scheme check covers them.
- Path anchors: `tests/architecture/Repository.swift`, the tools' scripts (`tools/*/build.sh`, `run.sh`, `fetch.sh`, `gate/run.sh`), `.gitignore` (`lib/src/darwin/build/`, the tools' `.build/`), `ci.yml`.
- Docs: DEVELOPER.md's tree, commands and recipes; CLAUDE.md's stack and codebase map; the layer cards; the root README; the skills' commands.

**Reference.** Apogee: `lib/src/darwin/` (its Xcode project, `scripts/build.sh`, `source/`, `tests/architecture/layering/`). In-house: Milestone B and commit `48f2726` (the navigator over the whole repository), Milestone F (the routines and their checks).

**Decisions made** (dated):
- 2026-11-14: mimic Apogee's directory structure, adapted for iStation (the user's call).
- 2026-11-14: the tools move to `lib/src/darwin/tools/` — they serve this codebase alone (the default, confirmed by the user).
- 2026-11-14: the Xcode project moves into `lib/src/darwin/` as Apogee's does, its navigator still showing the whole repository through a group at the repository root (the default, confirmed by the user).
- 2026-11-14: `scripts/build.sh <routine> <platform>` is the one entry point, calling today's two scripts as helpers until 4d makes `cicd.sh` the one path (the default, confirmed by the user).
- 2026-11-14: per-module Xcode schemes now, as Apogee gives every Presentation module one (its darwin ADR 0004) — each of iStation's Presentation modules (`styles`, `player`, `acknowledgements`) gets its own shared scheme (the user's veto of the default to wait for a second module; the default also miscounted them as one).

**Open calls:** none — all answered 2026-11-14.

**Guardrail(s).** `swift test` (all architecture checks, the scheme check, the provenance and routine checks) passes from the new root; every scheme builds; `tools/istation-run/cpu-check.sh` and the gate's dry run work from their new place; a planted stale path in a tool script fails its own run.

**Acceptance criteria:**
- [ ] `src/`, `tools/` and the root `iStation.xcodeproj` are gone; `lib/src/darwin/` holds the package, the apps, the project, `scripts/` and `tools/`.
- [ ] `swift test`, the strict build and all four schemes pass from the new layout; the navigator still shows the whole repository.
- [ ] `git grep -E 'src/istation|(^|[^/])tools/'` finds only history.
- [ ] DEVELOPER.md, CLAUDE.md, the cards, the README and the skills name the new paths.
- [ ] Each Presentation module has its own shared scheme, which builds and tests it.

**Scope note.** v0.0.1, track 4; gated on 4a. 4c, 4d, 4e and 4f build on the new paths. Out of scope: changing any module, the build system (the package stays SwiftPM with a thin Xcode project), or the routines.
