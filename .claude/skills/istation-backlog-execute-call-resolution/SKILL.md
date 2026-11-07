---
name: istation-backlog-execute-call-resolution
description: Groom a group of iStation backlog items (a version table, a track, or Maintenance) so they build with nothing left to ask — inventory every open call, ask the user's [user] calls one by one, confirm or veto the [default: …] calls in rounds, and record every answer as a dated decision propagated through each document. Use when the user says "resolve the open calls", "groom v0.1.0", "answer the questions in the backlog", "clear the [user] calls", "let's decide the open questions", or "get the table ready to build".
---

# Resolve the open calls — iStation

A group of items, groomed until it builds with nothing left to ask.

The docs home is [`documentation/istation/`](../../../documentation/istation/README.md); the index is [`backlog/README.md`](../../../documentation/istation/backlog/README.md).

## 1. Inventory

- Re-read the live index. Skip 🚧 items — their builder owns their calls — and say so.
- Read every document in the group, in table order.
- Count the calls by tag: `[user]`, `[default: …]`, `(consumed decision)`.
- Verify each `(consumed decision)`'s owner still exists; if it shipped, repoint the citation to its MILESTONES entry.
- Also look at ROADMAP's "Decisions needed" lines that belong to the group.
- **Show the user the map** (each item, its calls, what each blocks) before the first question.

## 2. Resolve, one by one, in build order

Record each answer before asking the next.

- **`[user]` calls**: one per AskUserQuestion, in plain language — what it decides and what each option costs — with the document's recommendation first.
- **`[default: …]` calls**: confirm or veto, up to four per AskUserQuestion round, "take the default (recommended)" first.
- A call that evidence has made moot is removed with a dated reason, not asked.
- "Skip" leaves the call open and tagged.

## 3. Record completely

For every answer, in the same pass:

- A dated **Decisions made** entry with whose call it was ("2026-11-02: Covers come from <source> (the user's call)").
- The call removed from **Open calls**.
- **Consequences propagated** to every Core constraint, Seam + files line, Guardrail and Acceptance criterion that branched on it — a decision recorded but not propagated is drift wearing a date.
- Flags elsewhere updated: index rows (🔒 → 🟢 where a `[user]` call was the only block), track preambles, ROADMAP's "Decisions needed" ("answered 2026-11-02").
- A SPEC-level answer (a non-goal, a principle) changes SPEC with a dated note.

## 4. Validate and report

- A search of the group's documents shows no `[user]` or `[default:` left except deliberate skips.
- `python3 scripts/validate_docs.py documentation` (from the repository root) is clean.
- **Commit and push** (CLAUDE.md → Committing and pushing): one commit, staging only this task's paths, its message exactly `v<x.y.z> : Title Case Summary` — no body, no trailers — then `git push origin v<x.y.z>`.
- Report each call and its answer in one line, and what still blocks what.
