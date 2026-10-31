---
name: istation-maintenance-update-documents
description: The pre-merge documentation reconciliation for iStation — scope from the branch's diff, walk every document the diff touched (backlog, MILESTONES, ROADMAP, CLAUDE.md, DEVELOPER.md, layer cards, ADRs, reference, SPEC) against the code, fix the drift, and validate mechanically. Use before opening a pull request or merging a release branch, or when the user says "update the docs", "reconcile the documentation", "docs pass", "make the docs match the code", or "is the backlog up to date?".
---

# Update the documents — iStation

The docs are the source of truth, so before a merge they must say what the code now does. Audit claims about **changed areas only** — no drive-by rewrites.

The docs home is [`documentation/istation/`](../../../documentation/istation/README.md); the code is `src/istation/`; the base branch is `stable`.

## 1. Scope from the diff

`git diff --stat stable...HEAD` plus `git status` (uncommitted work counts). List the modules, contracts and documents touched.

## 2. Walk the documents against the diff

- **Backlog** ([index](../../../documentation/istation/backlog/README.md)): **the cardinal violation is a completed item still in the backlog** — its work recorded in MILESTONES, its document and row deleted. Items being worked are 🚧; gates satisfied by shipped work are updated; decisions taken during the work are recorded in their documents; an emptied version table is retired (the Architecture and Maintenance tables never are); the "Ids spent so far" line is current.
- **[MILESTONES.md](../../../documentation/istation/assistant/MILESTONES.md)**: every shipped item has its entry — goal, built, trade-offs, verified, decisions consumed.
- **[ROADMAP.md](../../../documentation/istation/assistant/ROADMAP.md)**: shipped lines ticked and linked to their milestone; "Decisions needed" current.
- **[CLAUDE.md](../../../documentation/istation/assistant/CLAUDE.md)**: the Codebase Map (one concern per row — a row that can't be written that way is a split waiting, ADR 0003); Stack & environment; a newly enforced rule promoted to `⚠`; style rules; the checklist.
- **[DEVELOPER.md](../../../documentation/istation/assistant/DEVELOPER.md)**: the tree, each changed module's section, the commands, the test table, the recipes.
- **Layer cards** (`src/istation/source/<layer>/CLAUDE.md`, `src/istation/tests/<layer>/CLAUDE.md`) and **ADR 0002's table** against the `modules` rows in `Package.swift`.
- **[ADRs](../../../documentation/istation/adrs/README.md)**: a new standing rule gets a record; a changed one a superseding record (append-only — the old record's Status line is its only edit); each Enforcement section names the real check.
- **[reference/](../../../documentation/istation/reference/README.md)** against the shipped contract: the emulators' flags (`LaunchContract.swift`), the library file (`LibraryStore.swift`).
- **[SPEC.md](../../../documentation/istation/assistant/SPEC.md)** only if scope moved, with a dated note.
- **The root `README.md`** if building, running or installing changed.

## 3. Validate mechanically

- `python3 scripts/validate_docs.py documentation` (from the repository root).
- `cd src/istation && swift build --explicit-target-dependency-import-check=error`
- `cd src/istation && swift test` — the layering and layer-context checks run inside it.

## 4. Report

What was fixed in each document, and what still needs the user (an unanswered `[user]` call, a SPEC question, a release step).
