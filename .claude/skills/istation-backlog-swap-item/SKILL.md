---
name: istation-backlog-swap-item
description: Move one iStation backlog item between tables — a release table and Maintenance or Architecture, or one version to another — giving it the destination's id and position, moving its document, and fixing every reference across the docs and skills; the skill resolves which application's queue is meant and asks when it cannot. Use when the user says "move M2 into v0.1.0", "push 1a to v0.1.0", "make this a maintenance item instead", "swap this item to another version", or "reschedule item X".
---

# Swap an item between tables — iStation

An item's id is shaped by its table: a release item carries a track number and letter (`3e`, `4f`), a standing item `M<n>` or `A<n>`. Moving it between tables is therefore a **re-identification**, not just a moved row: a new id from the destination's sequence, the document `git mv`'d into the destination's directory, and every reference updated — index, preambles, ROADMAP, the document's own scope note and cross-links. Ids are identities, so **this skill runs only on the user's explicit instruction**, and the document records the move, dated, as the user's call.

## 0. Which application?

iStation's documentation is split by kind, then by platform ([the router](../../../lib/documentation/CLAUDE.md)): `lib/documentation/{assistant,backlog,adrs,reference}/<app>/`. Today there is one application, **`darwin`**: the Apple apps, one Swift package at `lib/src/darwin/` with the macOS app (PS1 and PS2) and the iOS app (PS1); what binds one OS alone sits in that kind's `darwin/macos/` or `darwin/ios/`. A second application gets its own folder in each kind and a row in the router. Resolve which application this invocation means, and for work that binds one OS which OS folder, before reading anything else, in order:

1. **The arguments.** An id or table names its queue: `darwin`'s version tables (`v0.0.1`, `v0.1.0`, …) with their numeric tracks (`4e`), and its standing `M<n>` and `A<n>` tables. A named document resolves by the backlog that holds it, and by its folder (`macos/`, `ios/`) to one OS.
2. **The conversation.** What the work touches: the package, its cores, the apps, their build routines and their tools (`lib/src/darwin/`) are `darwin`'s; a screen, entitlement or setting of one app alone is that OS's folder; what both apps share is `darwin` itself.
3. **Still ambiguous? Ask.** One AskUserQuestion — which application, or whether the work binds macOS alone, iOS alone or both apps — before anything is treated as decided. Never guess between them. A request for an application that has no folder yet (a web or Windows app, say) is asked about too, never filed under `darwin`.

Everything below reads from the chosen application's folders, written `<app>` (today always `darwin`): its backlog index (`lib/documentation/backlog/<app>/README.md`) is the authority on that queue's tables, numbering, document format and link depths, and its contributor docs (`lib/documentation/assistant/<app>/CLAUDE.md` first) carry the invariants, the clean-room rule first among them. Where this skill says `<app>`, substitute the chosen application's folder name.

## 1. Ground in the live state first

Parallel sessions build and ship while you work:

1. Re-read the index (`lib/documentation/backlog/<app>/README.md`) and `git status`. Find the item's row, document and status — a 🚧 item is someone else's: stop and say so. A 🚧 document that only cites the moving id gets that one edit and nothing else.
2. Find every item whose gate names it.
3. **Survey every reference before editing**: grep the item's id and its filename across `lib/documentation/`, the root `CLAUDE.md` and `README.md`, and `.claude/skills/`. List the hits; each becomes a targeted edit.
4. **Bare ids are landmines.** `M3` matches the "M3 Max" in MILESTONES' verification lines, `M1` matches inside `M10`, and a bare track number matches a date's day. Never blind-replace an id: each occurrence is replaced as part of a longer exact string, word-bounded, or hand-verified first.

## 2. The new id and the position — the destination decides

- **Into a release table:** joining a track whose pending items share it, the track's next letter ever assigned — shipped and cancelled letters count, so with `4a`–`4f` spent the next is `4g`; a new theme takes the next track number ever used.
- **Into Maintenance / Architecture:** the next `M<n>` / `A<n>` ever assigned. The index's "Ids spent so far" line, checked against MILESTONES, is the record.
- **The old id stays spent and its gap stays open**: an id is "never reused" (the index), and this house does not renumber.
- **Position:** rows are in suggested build order, so the item goes where the user says; ask if they haven't.
- **Gates are table-agnostic**: the moved item keeps its gate, and every item whose gate named it gets the new id. Its status is re-derived — a gate pointing at another release may no longer hold.
- **Within one table, into or out of an OS folder** (an item that comes to bind macOS or iOS alone, or stops binding one): the same id and row, a new File link and its links' depth.

## 3. The move mechanics

All of a piece, per the index's rule — "a `git mv`, its row, its Version cell and its links":

1. **The document:** `git mv` into the destination's directory under `lib/documentation/backlog/<app>/` — `v<x.y.z>/`, `maintenance/` or `architecture/`, or the same under `macos/` or `ios/` for one OS (plain `mv` for an untracked file); a directory comes with its table's first item. Re-derive its relative links for the new place: same-table links are bare filenames, cross-table ones `../<table-dir>/<file>`; links out of the backlog keep their depth, except across an OS folder, which adds or drops one `../`.
2. **The document's content:** its **Scope note** in the destination's wording (earmarked for the version, or the Maintenance or Architecture queue, claimable by name at any time) and a dated **Decisions made** entry ("2026-11-14: moved from M2 to 1b (the user's call)").
3. **The index:** the row leaves the old table and joins the new one in position, with its new id, its Version cell (`v0.1.0`, `maint.`, `arch.`), its File link (display text equal to the link) and its status; **both tables' preambles** tell the story; the "Ids spent so far" line gains the new id.
4. **ROADMAP** (`lib/documentation/assistant/<app>/ROADMAP.md`): the line moves to the destination's section — a release under "In progress" or "Planned" ↔ Architecture or Maintenance — restyled to its neighbours, its link label and path updated.
5. **Everything else that cites it:** other items' gates and cross-links, track preambles, `lib/documentation/assistant/<app>/CLAUDE.md`, the ADRs (`lib/documentation/adrs/<app>/`), `lib/documentation/reference/<app>/` and the skills. **MILESTONES** changes only where it carries a forward-looking reference; shipped history is never rewritten.
6. **Retire** a version table the move left empty only at the pre-merge docs pass (`/istation-maintenance-update-documents`), never the standing tables.

## 4. Validate

- `python3 lib/scripts/validate_docs.py lib/documentation` (from the repository root) is clean: rows ↔ documents both ways, each row's Version cell matching its directory, unique ids, one status per row, every 🔒 gate naming a pending id, and every relative link, the skills' included.
- Stale greps: the old id appears only in dated history; the old `<table-dir>/<file>` path appears nowhere.
- If an Edit fails because a parallel session touched the file, re-read the live region and re-anchor — never force the stale version over it.

## 5. Commit, push and report

- **Commit and push** ([Committing and pushing](../../../lib/documentation/assistant/darwin/CLAUDE.md#committing-and-pushing)): one commit on the release branch, staging only this task's paths, its message exactly `v<x.y.z> : Title Case Summary` — no body, no trailers, not even a session's attribution lines — then `git push origin v<x.y.z>`. Never force-push, never push `stable` or a tag; a failed push is reported with its error and left for the user.
- **Report** the old → new id and where the row landed, its status, the document's new path, every file touched and the dated history recorded, anything deliberately left alone (a 🚧 document, MILESTONES' shipped history), and the validation results.
