---
name: istation-backlog-execute-group
description: Execute a whole iStation backlog table (a version like v0.1.0, or a named set of Maintenance items) unsupervised — read every document first, ask every blocking question up front in one sitting, then build each item serially to execute-item's full bar, committing once per shipped item, and report per item at the end. Use when the user says "do the whole v0.2.0 table", "execute the group", "build everything in Maintenance", "run the release's items", or "work through the backlog without me".
---

# Execute a group — iStation

A whole table, built unsupervised after one sitting of questions.

The docs home is [`documentation/istation/`](../../../documentation/istation/README.md); the index is [`backlog/README.md`](../../../documentation/istation/backlog/README.md).

## 1. Read everything first

Re-read the live index; take the named table's rows in order, skipping 🚧 rows (someone else's) and saying so. Read [CLAUDE.md](../../../documentation/istation/assistant/CLAUDE.md) in full, then **every document in the group** and its References, before building anything.

## 2. Ask every blocking question up front

In one sitting, before the first line of code:

- Every `[user]` call across the group, one AskUserQuestion each, plain language, the document's recommendation first.
- Every `[default: …]` call, confirm-or-veto, up to four per round.
- Any item that needs a run only the user can do (their emulators, games, BIOS files, signing identity): ask now whether to skip it or wait for it.

Record every answer in its document, propagated (as `/istation-backlog-execute-call-resolution` does), before building.

## 3. Build each item, serially

Each item to `/istation-backlog-execute-item`'s full bar: 🚧 first; the layer law and every invariant; hermetic tests; green with the real commands (`cd src/istation && swift build --explicit-target-dependency-import-check=error`, `swift test`, and `python3 scripts/validate_docs.py documentation` from the root); shipped through the documentation flow (MILESTONES, document and row deleted, gates updated, ROADMAP ticked, map/cards/ADR 0002/DEVELOPER/reference as needed).

**Commit and push once per shipped item** (CLAUDE.md → Committing and pushing): staging only that item's paths, the message exactly `v<x.y.z> : Title Case Summary` — no body, no trailers — then `git push origin v<x.y.z>`.

- A step that would need a dangerous or outward-facing permission mid-run (publishing, signing, force-pushing, touching `stable` or a tag, changing repository settings) means rethink the approach, not ask: the run is unsupervised.
- **An item that fails its bar** is stopped: revert its partial change, record why in its document (a dated note under Decisions made, its row back to 🟢 or 🔒), and continue with the items that don't depend on it.

## 4. Report per item

For each: shipped (its commit, pushed; its milestone) or stopped (why, what it needs); the docs updated; the commands run and their results; what is left for the user.
