# Documentation by kind, then platform — `lib/documentation/{assistant,backlog,adrs,reference}/darwin/`, the router and the validator, as Apogee lays them out

**What / why.** The user's call (2026-11-14): mimic the directory structure and agentic procedure of the user's Apogee repository, adapted for iStation. Apogee splits its documentation **by kind, then by platform** (`lib/documentation/CLAUDE.md`, "the change of 2026-11-07"): one folder per kind — `assistant/` (contributor docs), `backlog/` (the work queue), `adrs/` (the records), `reference/` (contracts) — each with a `README.md` listing its platform folders, and inside each kind one folder per application, the Apple apps' being `darwin/` with an `ios/`, `ipados/` and `macos/` subfolder (each a `README.md`) for what binds one OS alone. iStation today keeps everything in one home, `documentation/istation/{assistant,adrs,backlog,reference}` (29 files), reached from the router `documentation/CLAUDE.md`. Its two apps — macOS (PS1 and PS2) and iOS (PS1) — are one Swift codebase, exactly Apogee's `darwin`.

Measured, not guessed (2026-11-14, `git ls-files` and `git grep` in both repositories): Apogee's documentation is 125 files under `lib/documentation/`, its router has a kinds table and a platforms table and a "Facts that cross the boundary" list, and its darwin home holds `CLAUDE.md`, `DEVELOPER.md`, `MILESTONES.md`, `ROADMAP.md` with its backlog at `backlog/darwin/` (index `README.md`; cross-OS versions in `darwin/v<x.y.z>/`, one-OS items in `darwin/macos/v<x.y.z>/` and `darwin/macos/maintenance/`). In iStation, `documentation/istation` is written in 33 tracked files (84 mentions) outside the Xcode project, and `scripts/validate_docs.py` in 16 (20 mentions).

**Core constraint(s).** Shipped code from permissive sources only, GPL emulators black boxes (⚠ in CLAUDE.md): the move carries every rule and every redaction note intact — nothing reworded except paths. The ADRs keep their numbers and stay append-only; a moved record is the same record. Every relative link stays valid: the validator is clean at the end. Nothing in flight is moved under another session: this lands after 3g.

**Seam + files.** No module.
- `git mv documentation/istation/assistant/* lib/documentation/assistant/darwin/` (CLAUDE, SPEC, ROADMAP, MILESTONES, DEVELOPER), likewise `adrs/` → `lib/documentation/adrs/darwin/`, `backlog/` → `lib/documentation/backlog/darwin/` (its index becomes `backlog/darwin/README.md`; `v0.0.1/` and the standing tables beneath it), `reference/` → `lib/documentation/reference/darwin/`.
- New: `lib/documentation/{assistant,adrs,backlog,reference}/README.md` (each kind's platform table, Apogee's form); `…/darwin/macos/README.md` and `…/darwin/ios/README.md` in each kind (what binds one OS; an item for one OS goes under `backlog/darwin/<os>/v<x.y.z>/`).
- The router moves to `lib/documentation/CLAUDE.md`, rewritten in Apogee's shape: the kinds table, the platforms table (darwin today), and the facts that cross the boundary (the GPL rule, commit-and-push, repo-wide process living in `assistant/darwin/CLAUDE.md`).
- `scripts/validate_docs.py` → `lib/scripts/validate_docs.py`, taught the new layout: one backlog index per platform, version and standing tables under OS subfolders, and the link depths that follow.
- Every path in the docs, the root `README.md` and `CLAUDE.md`, the 13 skills, code comments, `ci.yml` and the Xcode project's navigator group.

**Reference.** Apogee: `lib/documentation/CLAUDE.md` (the router), `lib/documentation/{assistant,adrs,backlog,reference}/README.md`, `lib/documentation/backlog/darwin/README.md` (an app's index with OS subfolders). In-house: the router `documentation/CLAUDE.md` and the validator; Milestone B (the navigator showing the whole repository).

**Decisions made** (dated):
- 2026-11-14: mimic Apogee's directory structure and agentic procedure, adapted for iStation, as v0.0.1 items (the user's call).
- 2026-11-14: the root `CLAUDE.md` stays, as a pointer to `lib/documentation/CLAUDE.md` with the hard rules at its top — Apogee has none at its root, but iStation's carries the clean-room rule every session must see first (the default, confirmed by the user).
- 2026-11-14: iStation's one application is `darwin`, with `macos/` and `ios/` subfolders in each kind and no `ipados/` until an iPad-specific item exists (the default, confirmed by the user).
- 2026-11-14: it lands after 3g, so the BIOS work in flight isn't moved under it — met: 3g shipped 2026-11-14 (the default, confirmed by its condition).

**Open calls:** none — all answered 2026-11-14.

**Guardrail(s).** The validator, moved and extended, checks every backlog index in the new layout and every relative link, and fails on a planted index row whose document is missing and on a planted broken link; `swift test`'s architecture checks still find ADR 0001 and ADR 0002 at their new paths.

**Acceptance criteria:**
- [ ] `documentation/` is gone; `lib/documentation/` holds the four kinds, each with its README and its `darwin/` folder (and `macos/`, `ios/` beneath).
- [ ] `lib/documentation/CLAUDE.md` routes by kind and platform as Apogee's does.
- [ ] `python3 lib/scripts/validate_docs.py lib/documentation` is clean, and `git grep documentation/istation` finds only history (MILESTONES' and dated decisions' quoted paths).
- [ ] `swift test` passes, its ADR checks reading the new paths.

**Scope note.** v0.0.1, track 4, first; gated on 3g. 4b moves the code; 4e rewrites the skills for the new paths. Out of scope: Apogee's `gui/` and `design/` homes (iStation has one codebase and no design prototype).
