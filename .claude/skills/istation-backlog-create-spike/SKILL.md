---
name: istation-backlog-create-spike
description: Turn an iStation spike's findings (from this conversation or an attached write-up) into the whole split of backlog documents in one pass — documents, index rows, track preamble and ROADMAP lines, never code; the skill resolves which application is meant and asks when it cannot. Use when the user says "execute the spike", "create the documents from the spike", "write up the spike as backlog items", "spec the spike's split", or "turn those walls into items".
---

# Create the backlog documents from a spike — iStation

A spike ends as a report: walls with evidence, measurements, a proposed split, the user's calls. This is the step after: the whole split becomes backlog documents in one pass, each to `/istation-backlog-create-item`'s bar, plus what a spike-born set needs — the evidence carried in, the answers recorded, the siblings' gates wired, the track's story told in the index. Documents only: no code, no MILESTONES entry, no SPEC change the user hasn't agreed. Building stays `/istation-backlog-execute-item`'s, later, one item at a time.

## 0. Which application?

iStation's documentation is split by kind, then by platform ([the router](../../../lib/documentation/CLAUDE.md)): `lib/documentation/{assistant,backlog,adrs,reference}/<app>/`. Today there is one application, **`darwin`**: the Apple apps, one Swift package at `lib/src/darwin/` with the macOS app (PS1 and PS2) and the iOS app (PS1); what binds one OS alone sits in that kind's `darwin/macos/` or `darwin/ios/`. A second application gets its own folder in each kind and a row in the router. Resolve which application this invocation means, and for work that binds one OS which OS folder, before reading anything else, in order:

1. **The arguments.** An id or table names its queue: `darwin`'s version tables (`v0.0.1`, `v0.1.0`, …) with their numeric tracks (`4e`), and its standing `M<n>` and `A<n>` tables. A named document resolves by the backlog that holds it, and by its folder (`macos/`, `ios/`) to one OS.
2. **The conversation.** What the work touches: the package, its cores, the apps, their build routines and their tools (`lib/src/darwin/`) are `darwin`'s; a screen, entitlement or setting of one app alone is that OS's folder; what both apps share is `darwin` itself.
3. **Still ambiguous? Ask.** One AskUserQuestion — which application, or whether the work binds macOS alone, iOS alone or both apps — before anything is treated as decided. Never guess between them. A request for an application that has no folder yet (a web or Windows app, say) is asked about too, never filed under `darwin`.

Everything below reads from the chosen application's folders, written `<app>` (today always `darwin`): its backlog index (`lib/documentation/backlog/<app>/README.md`) is the authority on that queue's tables, numbering, document format and link depths, and its contributor docs (`lib/documentation/assistant/<app>/CLAUDE.md` first) carry the invariants, the clean-room rule first among them. Where this skill says `<app>`, substitute the chosen application's folder name.

**Superpowers** ([Superpowers fits the docs-first lifecycle](../../../lib/documentation/assistant/darwin/CLAUDE.md#superpowers-fits-the-docs-first-lifecycle)): a spike's conversation may have run through `superpowers:brainstorming`. Its decisions are the user's answers here, and these documents are its written design: nothing goes to `docs/superpowers/specs/`. The brainstorm ends when the documents are placed; planning and building wait for `/istation-backlog-execute-item`.

## 1. Gather

The input is wherever the findings live:

- **This conversation** — the usual case: the `/istation-backlog-investigate-spike` report earlier in the chat, and the user's answers since. A spike kept only in the chat has no other record: the documents become it, so nothing from the report is left behind.
- **An attached or named write-up** — read all of it before writing anything. Where it is thinner than a report (walls, evidence, split), say what's missing rather than inventing it.

Either way, extract before writing: every wall with its evidence, every measurement with its number, the proposed split (documents, tables, gates), every question — which have since been answered, and by whom.

## 2. Confirm the split and its placement

- **The split is the contract**, but the user's latest word wins over the report's proposal — fewer items, other tables, another release (possibly via `/istation-backlog-swap-version` first).
- **Placement is the user's call**, as in `/istation-backlog-create-item`: they name the table(s); ask only where they genuinely haven't said. An item that binds one OS alone goes in that OS's folder (`lib/documentation/backlog/<app>/macos/` or `ios/`).
- **Ids come from the destination tables' live sequences**, never from the report: re-read the index. A release item takes its track's next letter ever assigned (`1b` after `1a`), or the next track number ever used for a new theme; standing items take the next `M<n>` / `A<n>`. Ids are never reused — the index lists the ids spent.
- **A SPEC collision blocks the set**: a finding that touches a non-goal or a principle is settled with the user, and `lib/documentation/assistant/<app>/SPEC.md` amended with a dated note, **before** the documents exist.

## 3. Write each document

To `/istation-backlog-create-item`'s bar (the format and link depths in `lib/documentation/backlog/<app>/README.md`), plus:

- **Evidence baked in** with its numbers and `file:line`, for the walls *it* closes — "measured, not guessed: <date>, <method>" — so the item builds without this conversation. A measurement that shaped the design appears where it did the shaping.
- **Walls mapped visibly**: each wall owned by exactly one document; siblings reference it by id rather than re-owning it.
- **Answers as dated decisions** ("2026-11-02: … (the user's call)"); recommendations the user let stand as `[default: …]`, the recommendation recorded; user-owned unknowns as `[user]`. Nothing the spike settled is reopened — `(consumed decision)` where a sibling owns it.
- **Core constraints** naming every `⚠` invariant the item touches (`lib/documentation/assistant/<app>/CLAUDE.md`): the layer law, shipped code from permissive sources only (GPL emulators black boxes), no Sony files, UI-free view-models, release builds without tools, the real home untouched.
- **Seam + files** naming the layer and module from the codebase map, or the new module with its `Module(…)` row.
- **Gates** wiring the siblings' build order with real ids and no cycles; an item useful alone carries no gate just to mirror the narrative.
- **One Reference pass** for the set: the precedents the spike found — in-house items and seams, the references' own sources (ProjectPSX, Play!), public documentation — cited per document, left out where there is none. An oracle is cited by the behaviour recorded from it, never its source.

## 4. Place

- An index row per document, in build order, in its table (creating the version table and its `v<x.y.z>/` directory if this is its first item), gates in the Status cells.
- A **track preamble** above the rows telling the spike's story: when, what it measured (the headline numbers), how it split, which calls are recorded where — so a later agent trusts the documents without the chat.
- ROADMAP lines (`lib/documentation/assistant/<app>/ROADMAP.md`) linking each document; a new release section is introduced with the spike summarized the way the existing sections are. SPEC only per step 2. MILESTONES never.
- Update the index's "Ids spent so far" line.

## 5. Validate, commit and report

- `python3 lib/scripts/validate_docs.py lib/documentation` (from the repository root) is clean — rows and documents both ways, each document in its table's directory, every status and gate (the new sibling gates included), every relative link. Checked by hand: every number quoted matches the report.
- **Commit and push** ([Committing and pushing](../../../lib/documentation/assistant/darwin/CLAUDE.md#committing-and-pushing)): one commit on the release branch, staging only this task's paths, its message exactly `v<x.y.z> : Title Case Summary` — no body, no trailers, not even a session's attribution lines — then `git push origin v<x.y.z>`. Never force-push, never push `stable` or a tag; a failed push is reported with its error and left for the user.
- Report: each document's path, id, position, gate and walls closed; decisions versus defaults; **every `[user]` call across the set** — the questions that will block builds later; the docs updated (index, ROADMAP, SPEC if revised); the validator's result.
