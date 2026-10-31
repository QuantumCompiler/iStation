---
name: istation-backlog-execute-item
description: Build one iStation backlog item straight from its document — resolve its open calls first, mark it in progress, implement it within the layer law and the invariants, run the tests and checks green, then ship it through the documentation flow (MILESTONES entry, backlog document and row deleted, ROADMAP ticked). Use when the user says "Continue", "take the next item", "build 1a", "do M1", "execute the item", "work the backlog", or names an item id or document.
---

# Execute a backlog item — iStation

One item, built from its document, then shipped through the docs. Then stop.

The docs home is [`documentation/istation/`](../../../documentation/istation/README.md); the code is `src/istation/`.

## 1. Load the working process

Read [CLAUDE.md](../../../documentation/istation/assistant/CLAUDE.md) in full — the invariants, code style, the per-change checklist (the definition of done) — and [SPEC.md](../../../documentation/istation/assistant/SPEC.md), [ROADMAP.md](../../../documentation/istation/assistant/ROADMAP.md), and [DEVELOPER.md](../../../documentation/istation/assistant/DEVELOPER.md) as needed. They override anything remembered.

## 2. Pick

- A bare "Continue": the **topmost 🟢 row of the earliest version table** in [the index](../../../documentation/istation/backlog/README.md). Maintenance and Architecture items are taken by name.
- A named item: verify its gate; if unmet, say so and stop.
- **Re-read the live index** first: parallel sessions take items. A 🚧 row is someone else's.

## 3. Read the whole document

It is the working spec. A **split first** item is groomed into its sub-documents (confirmed with the user, to create-item's bar) and nothing is built. Read its References before designing.

## 4. Resolve the open calls before any code

- Every `[user]` call: asked with AskUserQuestion, in plain language, the document's recommendation first; answered.
- Every `[default: …]`: taken and recorded as "YYYY-MM-DD: <decision> (the default, taken)".
- `(consumed decision)`: not reopened.
- Rewrite every constraint, seam line, guardrail and criterion that branched on an answer, in the document, before building.

## 5. Build

- Mark the row 🚧 (and save the index) before the first code change.
- One item. Honor its constraints and every `⚠` invariant.
- **The layer law**: a new module brings its `Module(…)` row in `src/istation/Package.swift`, its source and test directories, its layer card's Modules line, its ADR 0002 table row and its Codebase Map row — in the same change.
- **Hermetic tests per its guardrails**: files only in a `Sandbox`, never the real home, never Launch Services, a real emulator or a real game.
- An item that needs a real run (the user's emulators, games, BIOS, signing identity) is prepared by you and run by the user; record what they report.
- Done means green, with the real commands:
  - `cd src/istation && swift build --explicit-target-dependency-import-check=error`
  - `cd src/istation && swift test` (includes `ArchitectureTests`)
  - `python3 scripts/validate_docs.py documentation` (from the repository root)
- Changing repository settings, CI secrets, or anything outward-facing (pushing, publishing, signing) is asked first.

## 6. Ship — the documentation and status flow, in the same change

1. **MILESTONES.md** extended: goal, what was built (modules and files), trade-offs, how it was verified (the commands and their results), decisions consumed.
2. **The backlog document and its index row deleted**; any item gated on it updated (🔒 → 🟢 when its gate empties). A version table that empties is retired at the pre-merge docs pass.
3. **ROADMAP.md** line ticked, linking the milestone.
4. **Codebase Map, DEVELOPER.md, layer cards, ADR 0002's table** updated for any module change; **reference/** for a changed contract (an emulator's flags, the library file).
5. **SPEC.md** only on a scope change, with a dated note.
6. A new standing rule → an ADR; promoted to a `⚠` section once enforced.
7. The validator clean again.

Commit only when the user's process says so, staging only this item's paths. End git commit messages with the attribution lines the session specifies.

## 7. Stop

Report what was built, how it was verified, the docs updated, and anything left for the user. Wait to be asked to continue.
