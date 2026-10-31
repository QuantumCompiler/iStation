---
name: istation-maintenance-summarize-pull-request
description: Draft an iStation pull request description from evidence — the branch's diff, its MILESTONES entries, the backlog documents it deleted, and the decisions recorded on it — with Summary, items closed, decisions, docs updated, verification actually run, review notes, before-merging steps and open questions. Use when the user says "write the PR description", "summarize this branch for a pull request", "draft the PR", or "what goes in the PR for v0.0.1?".
---

# Summarize a pull request — iStation

A PR description written from evidence, delivered as text for the user to paste. Opening the PR is the user's, unless they ask.

## 1. Gather the evidence

- The range: `git log --oneline stable..HEAD`, `git diff --stat stable...HEAD`.
- MILESTONES entries added on the branch: `git diff stable...HEAD -- documentation/istation/assistant/MILESTONES.md`.
- Backlog documents deleted on the branch (their ids and titles): `git diff --name-status stable...HEAD -- documentation/istation/backlog/`.
- Decisions recorded on the branch: new dated lines in backlog documents, ADRs, SPEC, ROADMAP.
- ADRs added or superseded; reference contracts changed (`LaunchContract.swift`, `LibraryStore.swift`).

## 2. Verify, don't claim

Run, and report the actual results:

- `cd src/istation && swift build --explicit-target-dependency-import-check=error`
- `cd src/istation && swift test` (with `ArchitectureTests`)
- `python3 scripts/validate_docs.py documentation` (from the repository root)

A command not run is listed as not run.

## 3. Write

- **Summary** — two or three sentences: what the branch delivers.
- **Backlog items closed** — id and one line each, linking the milestone.
- **Decisions made on this branch** — dated, attributed.
- **Documentation updated** — per document.
- **Verification** — each command and its result; any manual run the user did (an emulator, a game) as they reported it.
- **Review notes** — where to look first; the riskiest change; anything touching the invariants (the layer law, emulator separation, the library file's compatibility).
- **Before merging** — required manual steps (a release tag, a version bump via `/istation-maintenance-update-release`).
- **Open questions** — any `[user]` call still open.

End with the session's pull-request attribution line. Deliver as text.
