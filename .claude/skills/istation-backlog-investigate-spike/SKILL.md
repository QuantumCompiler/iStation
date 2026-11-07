---
name: istation-backlog-investigate-spike
description: Investigate a design question about iStation with evidence, not opinion, and deliver a findings report in chat — walls, measurements, what already works, the backlog documents that would need creating, and the user-owned questions. Never builds and never writes backlog documents. Use when the user says "spike this", "investigate whether…", "can iStation do X", "what would it take to…", "how would we add cover art / CHD / controllers / PCSX-Redux", "probe the emulators' flags", or asks a feasibility or design question before anything is specced.
---

# Investigate a spike — iStation

A spike answers a design question **with evidence**. Its deliverable is a report in chat. It never builds code, never creates backlog documents, never edits SPEC, ROADMAP or the backlog index, and never saves a write-up file unless asked. "Execute the spike" afterwards means `/istation-backlog-create-spike` — create the documents — never implement.

The docs home is [`documentation/istation/`](../../../documentation/istation/README.md); the code is `src/istation/`.

## 1. Ground

Read, before probing anything:

1. [The backlog index](../../../documentation/istation/backlog/README.md) — what is queued, and where a split would land (Architecture `A<n>`, Maintenance `M<n>`, or a version table; the ids spent so far are listed there).
2. [CLAUDE.md](../../../documentation/istation/assistant/CLAUDE.md) — the six `⚠` invariants, the codebase map, the layer law. A design that needs an upward edge, shipped code from a non-permissive source, any reading of a GPL emulator's source or disassembly, a debug tool reaching an App Store build, a Sony file in the repository, a UI import in a view-model, an incompatible library-file change, or a test touching the real home folder is colliding with an invariant: that collision is a finding.
3. [SPEC.md](../../../documentation/istation/assistant/SPEC.md) — scope and **non-goals** (no GPL emulator's source read or copied, no Sony files, no PS3 core yet, no PS2 on iOS, no Intel Macs, no launching other emulators, Apple platforms only). A collision with a non-goal is itself a finding; changing SPEC is the user's call.
4. [ROADMAP.md](../../../documentation/istation/assistant/ROADMAP.md) — the phase the question belongs to and its "Decisions needed".
5. Precedents: [MILESTONES.md](../../../documentation/istation/assistant/MILESTONES.md), the [ADRs](../../../documentation/istation/adrs/README.md), the [reference contracts](../../../documentation/istation/reference/README.md), and external prior art (the emulators' own sources for any flag or config file).

## 2. Probe the real thing

- **Run the actual code**: build it (`cd src/istation && swift build`), drive the module the question touches from a scratch test or script, parse the actual sources (`Package.swift`'s module rows, the import lines), and **measure**.
- **Sandbox everything.** Probe scripts and files stay in the session's scratchpad. Never read or write the user's real `~/Library/Application Support/iStation/library.json`: build `Locations.sandbox(root:)` over a scratch folder, and to run the app itself, give it a scratch home (`CFFIXED_USER_HOME=<scratch>/home swift run iStation`).
- **Play the naive outsider** when the question is "can X be driven by Y" (an emulator flag, a metadata service, a controller config file): try it the way a newcomer would and record every wall exactly as it is hit.
- **Real runs are the user's.**\1 A GPL oracle (SwanStation, PCSX2) is only built unmodified and run: never open, read or disassemble its source, and a session that has read one writes no core code (ADR 0013).

## 3. Frame the findings as walls

Number them **W1, W2, …**. Each wall has its evidence (the command and its output, or `file:line`), the wall in one sentence, and the smallest capability that removes it. Record what **already works** with zero changes. Quantify: counts, sizes, timings, the share of a sample that passes.

## 4. Report, then wait

In chat:

1. **The question**, restated.
2. **Method** — what was run or read, and the sandbox used.
3. **Walls** and **already works**.
4. **The proposed documents**: for each, a working title, its target table (Architecture, Maintenance, or a version), its gate, the walls it closes, and its layer and module(s) per the codebase map. Note where one root-cause fix collapses several walls.
5. **The user-owned questions**, in plain language, each with what it decides — and a recommended default for everything agent-decidable.

Then stop. The user decides what happens next.
