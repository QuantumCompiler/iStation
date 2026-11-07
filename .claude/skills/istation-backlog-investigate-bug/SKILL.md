---
name: istation-backlog-investigate-bug
description: Turn an iStation symptom into a root cause with evidence and a Maintenance backlog item whose guardrail pins the reproduction. Use when the user reports a bug or odd behavior — "this game shows up as PS1 but it's PS2", "the emulator doesn't launch", "play time isn't counted", "iStation didn't come back after the game", "my library disappeared", "the scan misses .m3u sets", "investigate this crash" — or pastes a log or screenshot.
---

# Investigate a bug — iStation

A symptom becomes a root cause with evidence, and a Maintenance item to fix it. Never fix it here.

The docs home is [`documentation/istation/`](../../../documentation/istation/README.md); the code is `src/istation/`.

## 1. Ground

- [The backlog](../../../documentation/istation/backlog/README.md): an existing item that owns this seam gets the evidence added instead of a duplicate item.
- [MILESTONES.md](../../../documentation/istation/assistant/MILESTONES.md): a regression against a recorded guarantee is worth saying.
- [CLAUDE.md](../../../documentation/istation/assistant/CLAUDE.md): the invariants the fix must honor, and the codebase map to find the seam.

## 2. Investigate

- **Reproduce honestly, in a sandbox.** Build a minimal case in the scratchpad: fixture discs come from `SupportDiscFixtures` (`makeISO`, `makeSFO`) — never a real game image; folders and library files go in a scratch folder via `Locations.sandbox(root:)`; the app runs over a scratch home (`CFFIXED_USER_HOME=<scratch>/home swift run iStation`). The user's own log, screenshot or `library.json` is real evidence: keep its exact bytes, and never write to their real file.
- **Find the seam, not just the symptom**: the `file:line` where the wrong decision is made, and the one module where the fix belongs (identification, scanning, launching, library, store, a view-model…). Verify a pattern-match in the code before naming it.
- **Measure the blast radius**: which consoles, file types, emulators or settings it hits, how often, what is lost (play history is irreplaceable — say so when it is at stake).
- Note what already works.
- A real emulator or game run is the user's to start; ask, or read the emulator's source instead.

## 3. Write the Maintenance item

To `/istation-backlog-create-item`'s bar, in `backlog/maintenance/`, with the next `M<n>`, plus:

- **What / why** opens with the evidence and the root-cause chain.
- **The guardrail pins the reproduction as a regression fixture** — the minimal case as a test in the seam module's `tests/<layer>/<module>/`.
- **Acceptance** includes the inverted symptom.

Bigger than one focused session, or really a feature or product-shape question → stop and say so: that is `/istation-backlog-investigate-spike` or `/istation-backlog-create-item` territory.

## 4. Place and validate

The index row in the Maintenance table, a line in its preamble, the ROADMAP Maintenance line, the "Ids spent so far" line; never MILESTONES. `python3 scripts/validate_docs.py documentation` (from the repository root) is clean. **Commit and push** (CLAUDE.md → Committing and pushing): one commit, staging only this task's paths, its message exactly `v<x.y.z> : Title Case Summary` — no body, no trailers — then `git push origin v<x.y.z>`.

## 5. Report

The symptom → root-cause chain with its evidence; the item's path and id; the fixture; every `[user]` call; adjacent findings deliberately left out.
