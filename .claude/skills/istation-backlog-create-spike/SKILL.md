---
name: istation-backlog-create-spike
description: Turn an iStation spike's findings (from this conversation or an attached write-up) into the whole split of backlog documents in one pass — documents, index rows, track preamble and ROADMAP lines, never code. Use when the user says "execute the spike", "create the documents from the spike", "write up the spike as backlog items", "spec the spike's split", or "turn those walls into items".
---

# Create the backlog documents from a spike — iStation

A spike's findings become backlog documents, all of them in one pass. This writes documents only: no code, no MILESTONES entry, no SPEC change the user hasn't agreed.

The docs home is [`documentation/istation/`](../../../documentation/istation/README.md); the backlog index is [`backlog/README.md`](../../../documentation/istation/backlog/README.md).

## 1. Gather

From the conversation (or the attached write-up): every wall with its evidence, every measurement with its number, the proposed split, and every question — which have since been answered, and by whom.

## 2. Confirm the split and its placement

- The user's latest word wins over the report's proposal.
- **Ids come from the destination tables' live sequences**, never from the report: re-read the index. A release item takes its track's next letter ever assigned (`1b` after `1a`), or the next track number ever used for a new theme; standing items take the next `M<n>` / `A<n>`. Ids are never reused — the index lists the ids spent.
- A collision with SPEC (a non-goal, a principle) is settled with the user and SPEC amended with a dated note **before** the documents exist.

## 3. Write each document

To `/istation-backlog-create-item`'s bar (the format in the backlog README), plus:

- **Evidence baked in** with its numbers and `file:line` — "measured, not guessed: <date>, <method>".
- **Walls mapped visibly**: each wall owned by exactly one document; siblings reference it by id.
- **Answers as dated decisions** ("2026-11-02: … (the user's call)"); unanswered recommendations as `[default: …]`; user-owned unknowns as `[user]`.
- **Core constraints** naming every `⚠` invariant the item touches (CLAUDE.md): the layer law, emulators as separate programs, no Sony files, UI-free view-models, the library file's compatibility, the real home untouched.
- **Seam + files** naming the layer and module from the codebase map, or the new module with its `Module(…)` row.
- **Gates** wiring the siblings' build order with real ids and no cycles; an item useful alone carries no gate.
- One **Reference** pass: in-house precedents and the emulators' or libraries' own sources.

## 4. Place

- An index row per document, in build order, in its table (creating the version table and its `v<x.y.z>/` directory if this is its first item).
- A **track preamble** above the rows telling the spike's story: when, what it measured, how it split, which calls are recorded where — so a later agent trusts the documents without the chat.
- ROADMAP lines linking each document. SPEC only per step 2. MILESTONES never.
- Update the index's "Ids spent so far" line.

## 5. Validate and report

- `python3 scripts/validate_docs.py documentation` (from the repository root) is clean; every number quoted matches the report.
- Report: each document's path, id, position, gate and walls closed; decisions versus defaults; every `[user]` call; the docs updated; the validator's result.
