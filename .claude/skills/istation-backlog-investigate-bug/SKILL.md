---
name: istation-backlog-investigate-bug
description: Turn an iStation symptom into a root cause with evidence and a Maintenance backlog item whose guardrail pins the reproduction — reproduced in a sandbox, the seam found, the blast radius measured, the fix specced and queued, never built here; the skill resolves which application is meant and asks when it cannot. Use when the user reports a bug or odd behavior — "this game shows up as PS1 but it's PS2", "the emulator doesn't launch", "play time isn't counted", "iStation didn't come back after the game", "my library disappeared", "the scan misses .m3u sets", "the BIOS never reaches the shell", "the trace diverges", "investigate this crash" — or pastes a log, a trace or a screenshot.
---

# Investigate a bug — iStation

A bug arrives as a symptom — a log, a hang, a wrong frame, a trace that parts from the oracle's. This skill turns it into two things: a **root cause with evidence**, and a **Maintenance item** an agent can later build from without this conversation. It differs from `/istation-backlog-investigate-spike` on purpose: a spike only reports; a bug investigation ends with the fix **specced and queued** in one pass, because a diagnosed bug with no queued fix is how evidence gets lost. Never fix it here.

## 0. Which application?

iStation's documentation is split by kind, then by platform ([the router](../../../lib/documentation/CLAUDE.md)): `lib/documentation/{assistant,backlog,adrs,reference}/<app>/`. Today there is one application, **`darwin`**: the Apple apps, one Swift package at `lib/src/darwin/` with the macOS app (PS1 and PS2) and the iOS app (PS1); what binds one OS alone sits in that kind's `darwin/macos/` or `darwin/ios/`. A second application gets its own folder in each kind and a row in the router. Resolve which application this invocation means, and for work that binds one OS which OS folder, before reading anything else, in order:

1. **The arguments.** An id or table names its queue: `darwin`'s version tables (`v0.0.1`, `v0.1.0`, …) with their numeric tracks (`4e`), and its standing `M<n>` and `A<n>` tables. A named document resolves by the backlog that holds it, and by its folder (`macos/`, `ios/`) to one OS.
2. **The conversation.** What the work touches: the package, its cores, the apps, their build routines and their tools (`lib/src/darwin/`) are `darwin`'s; a screen, entitlement or setting of one app alone is that OS's folder; what both apps share is `darwin` itself.
3. **Still ambiguous? Ask.** One AskUserQuestion — which application, or whether the work binds macOS alone, iOS alone or both apps — before anything is treated as decided. Never guess between them. A request for an application that has no folder yet (a web or Windows app, say) is asked about too, never filed under `darwin`.

Everything below reads from the chosen application's folders, written `<app>` (today always `darwin`): its backlog index (`lib/documentation/backlog/<app>/README.md`) is the authority on that queue's tables, numbering, document format and link depths, and its contributor docs (`lib/documentation/assistant/<app>/CLAUDE.md` first) carry the invariants, the clean-room rule first among them. Where this skill says `<app>`, substitute the chosen application's folder name.

## 1. Ground first

1. `lib/documentation/backlog/<app>/README.md` — the Maintenance table (`M<n>`, Version `maint.`), the document format, the tag semantics, the "Ids spent so far" line.
2. **Scan the backlog for an existing home.** A pending item that already owns this seam gets the evidence added to *its* document instead of a near-duplicate — one concern, one home. Check `lib/documentation/assistant/<app>/MILESTONES.md` too: a bug in something just shipped may be a regression against a recorded guarantee, which is worth saying.
3. `lib/documentation/assistant/<app>/CLAUDE.md` and `SPEC.md` — the invariants the fix must honor, the codebase map to find the seam, and the principles that bound it.

## 2. Investigate — symptom, root cause, blast radius

Evidence, not inference; the probing rules are the spike skill's.

- **Reproduce honestly, in a sandbox.** The minimal case lives in the scratchpad and is built in code: files in a `Sandbox` (`SupportSandbox`), disc images from `SupportDiscFixtures`'s `makeISO`, R3000A programs from `SupportMIPS` — never a real game image, and never the real home or Application Support folders. A UI bug reproduces as a view-model test over its module's fakes. A core bug reproduces better as a trace than a live run: `lib/src/darwin/tools/istation-run` records the Swift console, and its `diff` finds the first divergence from ProjectPSX's trace or SwanStation's. The user's own log, trace, TTY output or screenshot is real evidence: keep its exact bytes, in the scratchpad, never in the repository. Shell facts: Bash stdin is a pipe (`</dev/null`), macOS has no `timeout` (deadlines inside the script), absolute paths.
- **The user's files stay theirs.** A run with their BIOS or games is the user's to start, unless they give its files' paths: then each is passed by path where they keep it, never copied or committed, and named in reports only by its size and hash. The open suites (ps1-tests), homebrew and content built in code are the agent's to run.
- **The clean room.** SwanStation and PCSX2 are only built unmodified and run, as black boxes: their source is never opened, read or disassembled — recorded with their own debugger, trace and logging first, else LLDB or Frida for guest state only, never `revula_disassemble` or `revula_decompile`. For how a device should behave, read ProjectPSX, Play! and public documentation (psx-spx, ps2tek). A subagent dispatched here is told the GPL rule in its prompt.
- **Root-cause with `superpowers:systematic-debugging`** ([Superpowers fits the docs-first lifecycle](../../../lib/documentation/assistant/darwin/CLAUDE.md#superpowers-fits-the-docs-first-lifecycle)): its Phases 1–3 are this step's. Its Phase 4, the fix, becomes the queued item, with the reproduction as its failing test, and is built only when the user asks.
- **Find the seam, not just the symptom**: the root cause as `file:line`, and the one module where the fix belongs, per the codebase map (3g's precedent: frame checksums couldn't say why the Swift console's shell waited where SwanStation's ran on; a RAM dump and a trace from that frame showed it polling GPUSTAT's bit 27). A signal that pattern-matches a known failure may have another cause — verify in the code before naming it.
- **Measure the blast radius** where numbers exist: which consoles, cores, devices, apps (macOS, iOS) and routines (personal, App Store) it hits, how often, how wrong. Say when the user's data is at stake — a memory card, a save state or settings that stop decoding are irreplaceable. Record what *already works* around the bug; it bounds the item's scope.
- Probe scripts live in the scratchpad; promote one into `lib/src/darwin/tests/` only if the user asks.

## 3. Write the Maintenance item

One document in `lib/documentation/backlog/<app>/maintenance/` (an item for one OS alone in `<os>/maintenance/`), kebab-case, to `/istation-backlog-create-item`'s full bar, plus:

- **What / why** opens with the evidence, verbatim where it matters (the log's bytes, the measured numbers, the first divergence), and the root-cause chain with its `file:line` — "measured, not guessed (date, method)".
- **Guardrail(s): the bug becomes a fixture.** The minimal case is a hermetic test in the seam module's `tests/<layer>/<module>/` — a program or image built in code, or a trace recorded only from one or from an open suite — so the bug cannot return silently. Never commit a trace, RAM dump, TTY log or screenshot from a run over the user's BIOS or a game: it carries their code. The document cites such a run by size, hash, frame and the first divergence's fields. A fix without the pinned reproduction is half an item.
- **Acceptance criteria** include the inverted symptom: the exact failing case from the evidence, now passing, stated observably.
- Open calls tagged as ever — `[user]` only for genuinely user-owned calls, `[default: …]` elsewhere; the diagnosis itself is recorded as dated **Decisions made** entries.
- Bigger than one focused session, not release-agnostic, or really a feature, a SPEC collision or a product-shape question → stop and say so with the evidence: that is `/istation-backlog-investigate-spike` or `/istation-backlog-create-item` territory, and the user decides where it goes. Split-first is available for a genuinely two-session fix.

## 4. Place, validate, commit and push

1. **Index**: the row in the Maintenance table of `lib/documentation/backlog/<app>/README.md`, with the next `M<n>` ever assigned, at the table's end (claimable by name at any time; a gate only if it truly consumes a pending item); the table's preamble gains the item's one-sentence origin; the "Ids spent so far" line gains the id.
2. **ROADMAP**: one line in `lib/documentation/assistant/<app>/ROADMAP.md`'s Maintenance section, in its style — the evidence summarized, the fix's shape, the link.
3. **MILESTONES is never touched**; SPEC only if the user agreed a principle changed (rare: a bug is behavior diverging from the docs, not the docs changing).
4. `python3 lib/scripts/validate_docs.py lib/documentation` (from the repository root) is clean.
5. **Commit and push** ([Committing and pushing](../../../lib/documentation/assistant/darwin/CLAUDE.md#committing-and-pushing)): one commit on the release branch, staging only this task's paths, its message exactly `v<x.y.z> : Title Case Summary` — no body, no trailers, not even a session's attribution lines — then `git push origin v<x.y.z>`. Never force-push, never push `stable` or a tag; a push that fails is reported with its error and left for the user.

## 5. Report

The symptom → root-cause chain with its evidence (`file:line`, numbers, the probe, the first divergence); the new item's id, path and position; the regression fixture its guardrail pins; every `[user]` call; the commit and the push; and what the investigation found that is deliberately *not* in this item (bigger-than-maintenance findings, adjacent oddities worth their own look). The user's files appear only by size and hash.
