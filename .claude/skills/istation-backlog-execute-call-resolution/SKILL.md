---
name: istation-backlog-execute-call-resolution
description: Groom a group of iStation backlog items (a version table, a track, or Maintenance) so they build with nothing left to ask — inventory every open call, ask the user's [user] calls one by one, confirm or veto the [default: …] calls in rounds, and record every answer as a dated decision propagated through each document; the skill resolves which application's queue is meant and asks when it cannot. Use when the user says "resolve the open calls", "groom v0.1.0", "answer the questions in the backlog", "clear the [user] calls", "let's decide the open questions", or "get the table ready to build".
---

# Resolve the open calls — iStation

A group of items — one application's table (a version, `maintenance`, `architecture`) or a track within a version — groomed until it builds with nothing left to ask. This is the standalone grooming pass: walk every document in the group, surface every entry under **Open calls**, and resolve them **one by one**, each answer recorded before the next question is asked. It changes documents, never code: `/istation-backlog-execute-item` and `/istation-backlog-execute-group` still build, and after this pass their ask-first steps find nothing left to ask.

## 0. Which application?

iStation's documentation is split by kind, then by platform ([the router](../../../lib/documentation/CLAUDE.md)): `lib/documentation/{assistant,backlog,adrs,reference}/<app>/`. Today there is one application, **`darwin`**: the Apple apps, one Swift package at `lib/src/darwin/` with the macOS app (PS1 and PS2) and the iOS app (PS1); what binds one OS alone sits in that kind's `darwin/macos/` or `darwin/ios/`. A second application gets its own folder in each kind and a row in the router. Resolve which application this invocation means, and for work that binds one OS which OS folder, before reading anything else, in order:

1. **The arguments.** An id or table names its queue: `darwin`'s version tables (`v0.0.1`, `v0.1.0`, …) with their numeric tracks (`4e`), and its standing `M<n>` and `A<n>` tables. A named document resolves by the backlog that holds it, and by its folder (`macos/`, `ios/`) to one OS.
2. **The conversation.** What the work touches: the package, its cores, the apps, their build routines and their tools (`lib/src/darwin/`) are `darwin`'s; a screen, entitlement or setting of one app alone is that OS's folder; what both apps share is `darwin` itself.
3. **Still ambiguous? Ask.** One AskUserQuestion — which application, or whether the work binds macOS alone, iOS alone or both apps — before anything is treated as decided. Never guess between them. A request for an application that has no folder yet (a web or Windows app, say) is asked about too, never filed under `darwin`.

Everything below reads from the chosen application's folders, written `<app>` (today always `darwin`): its backlog index (`lib/documentation/backlog/<app>/README.md`) is the authority on that queue's tables, numbering, document format and link depths, and its contributor docs (`lib/documentation/assistant/<app>/CLAUDE.md` first) carry the invariants, the clean-room rule first among them. Where this skill says `<app>`, substitute the chosen application's folder name.

## 1. Ground and inventory

- Re-read the live index (`lib/documentation/backlog/<app>/README.md`) and `git status`: parallel sessions take and ship items. Skip 🚧 items — their builder owns their calls — and say so.
- Read every document in the group, in table order, those in the OS folders (`macos/`, `ios/`) included.
- Count the calls by tag: `[user]` (blocks the build), `[default: …]` (taken, recorded, veto-able), `(consumed decision)` (owned elsewhere).
- Verify each `(consumed decision)`'s owner still exists; if it shipped, repoint the citation to its MILESTONES entry — that is its whole resolution.
- Also take the lines of ROADMAP's "Decisions needed" (`lib/documentation/assistant/<app>/ROADMAP.md`) that belong to the group.
- **Show the user the map** before the first question: how many calls, in which documents, which are the user's, and what each blocks — the size of the sitting before it starts.

## 2. Resolve, one by one, in build order

In the table's build order, and within a document top to bottom. **Record each answer before asking the next**: the documents never hold a batch of unwritten decisions.

- **`[user]` calls**: one per AskUserQuestion, in plain language — what it decides and what each option costs — with the document's recommendation first. No jargon, no stacking three decisions into one question.
- **`[default: …]` calls**: confirm or veto, up to four per AskUserQuestion round, "take the default (recommended)" first and the default's own wording shown. A veto becomes the user's call, recorded as such; a confirmation locks the default.
- A call that evidence has made moot (the work shipped differently, the dependency went away) is removed with a dated reason, not asked, and said in the report. The evidence is the repository, the references (ProjectPSX, Play!), public documentation or an oracle run as a black box — never a GPL emulator's source.
- "Skip" is a real answer: the call stays open and tagged, and the report lists it as still blocking — never dropped, never guessed.

## 3. Record completely

For every answer, in the document, in the same pass:

- A dated **Decisions made** entry: what was decided and whose call it was ("2026-11-02: Covers come from <source> (the user's call)"; "(the default, confirmed by the user)").
- The call removed from **Open calls**.
- **Consequences propagated** to every Core constraint, Seam + files line, Guardrail and Acceptance criterion that branched on it — a decision recorded but not propagated is drift wearing a date.
- Flags elsewhere brought down: track preambles ("answered the same day" is the house phrasing), ROADMAP's "Decisions needed" ("answered 2026-11-02"). An answered call changes no Status cell: 🔒 names pending ids only.
- A SPEC-level answer (a non-goal, a principle) changes `lib/documentation/assistant/<app>/SPEC.md` with a dated note.

## 4. Validate, commit and report

- A search of the group's documents shows no `[user]` or `[default:` left except the deliberate skips and any default left for build time on purpose (say which and why).
- `python3 lib/scripts/validate_docs.py lib/documentation` (from the repository root) is clean — rows ↔ documents, gates and links: grooming edits documents, and this proves nothing tore.
- **Commit and push** ([Committing and pushing](../../../lib/documentation/assistant/darwin/CLAUDE.md#committing-and-pushing)): one commit on the release branch, staging only this task's paths, its message exactly `v<x.y.z> : Title Case Summary` — no body, no trailers, not even a session's attribution lines — then `git push origin v<x.y.z>`. Never force-push, never push `stable` or a tag; a failed push is reported with its error and left for the user.
- Report: each call and its answer, one line each; the decisions recorded per document and the consequences propagated; the skips (🚧 documents, declined calls) and what still blocks what; and the group's state now — ideally "nothing in this table waits on a question".
