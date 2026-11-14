---
name: istation-backlog-investigate-spike
description: Investigate a design question about iStation with evidence, not opinion, and deliver a findings report in chat — walls, measurements, what already works, the backlog documents that would need creating, and the user-owned questions. Never builds and never writes backlog documents; the skill resolves which application the question belongs to and asks when it cannot. Use when the user says "spike this", "investigate whether…", "can iStation do X", "what would it take to…", "how would we add cover art / CHD / controllers / PCSX-Redux", "probe the emulators' flags", or asks a feasibility or design question before anything is specced.
---

# Investigate a spike — iStation

A spike answers a design question **with evidence, not opinion**. Its deliverable is a findings report in chat that maps each wall to the backlog document that would remove it, so that when the user later says "execute the spike", the documents practically write themselves. A spike that only reasons from memory of the code is an essay: run the real thing.

## 0. Which application?

iStation's documentation is split by kind, then by platform ([the router](../../../lib/documentation/CLAUDE.md)): `lib/documentation/{assistant,backlog,adrs,reference}/<app>/`. Today there is one application, **`darwin`**: the Apple apps, one Swift package at `lib/src/darwin/` with the macOS app (PS1 and PS2) and the iOS app (PS1); what binds one OS alone sits in that kind's `darwin/macos/` or `darwin/ios/`. A second application gets its own folder in each kind and a row in the router. Resolve which application this invocation means, and for work that binds one OS which OS folder, before reading anything else, in order:

1. **The arguments.** An id or table names its queue: `darwin`'s version tables (`v0.0.1`, `v0.1.0`, …) with their numeric tracks (`4e`), and its standing `M<n>` and `A<n>` tables. A named document resolves by the backlog that holds it, and by its folder (`macos/`, `ios/`) to one OS.
2. **The conversation.** What the work touches: the package, its cores, the apps, their build routines and their tools (`lib/src/darwin/`) are `darwin`'s; a screen, entitlement or setting of one app alone is that OS's folder; what both apps share is `darwin` itself.
3. **Still ambiguous? Ask.** One AskUserQuestion — which application, or whether the work binds macOS alone, iOS alone or both apps — before anything is treated as decided. Never guess between them. A request for an application that has no folder yet (a web or Windows app, say) is asked about too, never filed under `darwin`.

Everything below reads from the chosen application's folders, written `<app>` (today always `darwin`): its backlog index (`lib/documentation/backlog/<app>/README.md`) is the authority on that queue's tables, numbering, document format and link depths, and its contributor docs (`lib/documentation/assistant/<app>/CLAUDE.md` first) carry the invariants, the clean-room rule first among them. Where this skill says `<app>`, substitute the chosen application's folder name.

## 1. What a spike is — and is not

- It **produces a report, and only a report**: walls, measurements, what already works, the documents that would need creating, and the questions only the user can answer.
- It **never builds** code, never creates backlog documents, never edits SPEC, ROADMAP or the backlog index — even when the split is obvious — and never saves a write-up file unless the user asks. It changes no file, so it commits nothing.
- **"Execute the spike" means create the documents** — `/istation-backlog-create-spike`, the whole split in one pass; a single stray item can go through `/istation-backlog-create-item` — never implement. Building comes later, through `/istation-backlog-execute-item`.
- **Superpowers** ([Superpowers fits the docs-first lifecycle](../../../lib/documentation/assistant/darwin/CLAUDE.md#superpowers-fits-the-docs-first-lifecycle)): `superpowers:brainstorming` may carry the conversation around a spike, but its write-up is this report: nothing goes to `docs/superpowers/specs/`, and its hard gate's hand-off to `writing-plans` gives way. A throwaway build it offers is a probe in the scratchpad, over a `Sandbox`, never the real home folder or a real game. `superpowers:dispatching-parallel-agents` may run independent probes side by side; each probe's prompt carries the GPL rule and points at no oracle's build folder, and a session that has read a GPL emulator's source dispatches no core work.

## 2. Ground first

1. `lib/documentation/backlog/<app>/README.md` — what is queued, the gate convention, and where a split would land (Architecture `A<n>`, Maintenance `M<n>`, or a version table; an item for one OS in `<os>/`; the ids spent so far).
2. `lib/documentation/assistant/<app>/CLAUDE.md` — the six `⚠` invariants, the codebase map, the layer law. A design that needs an upward edge, shipped code from a non-permissive source, any reading of a GPL emulator's source or disassembly, a debug tool reaching an App Store build, a Sony file in the repository, a UI import in a view-model, a test touching the real home folder, or a persisted format (settings, memory cards, save states) that stops reading the user's data is colliding with a rule: that collision is a finding.
3. `SPEC.md` — scope and **non-goals** (no GPL emulator's source read or copied, no Sony files, no PS3 core yet, no PS2 on iOS, no Intel Macs, no launching other emulators, Apple platforms only). A collision with a non-goal is itself a finding; changing SPEC is the user's call, made before any items exist.
4. `ROADMAP.md` — the phase the question belongs to and its "Decisions needed".
5. **Precedents**: `MILESTONES.md`, `lib/documentation/adrs/<app>/`, `lib/documentation/reference/<app>/`, and prior art — ProjectPSX, Play! and public documentation (psx-spx, ps2tek), never a GPL emulator's source. A shipped item that solved an analog tells you which walls are real.

## 3. Probe the real thing

Prefer a probe over an argument: run the actual code, drive it the way the question implies, or parse the actual sources — and **measure**.

- **Run the actual code**: build it (`cd lib/src/darwin && swift build`), drive the module the question touches from a scratch test or script, parse `Package.swift`'s module rows and the import lines; the console runs from the command line through `lib/src/darwin/tools/istation-run`.
- **Sandbox everything.** Probe scripts and files stay in the scratchpad; promote one into `lib/src/darwin/tests/` only when the user asks to keep it. Files go in a `Sandbox`, programs and images are built in code (`SupportMIPS`, `SupportDiscFixtures`), and nothing reads or writes the real home or Application Support folders. Shell facts: Bash stdin is a pipe (`</dev/null`), macOS has no `timeout` (deadlines inside the script), absolute paths.
- **Play the naive outsider** when the question is "can X be driven by Y" (a disc format, a controller, a file the user imports): try it the way a newcomer would, with no insider shortcuts, and record every wall exactly as it is hit.
- **Real runs are the user's.** A run against the user's games, BIOS files or signing identity is theirs to start, unless they give the files' paths: then each is passed by path where they keep it, never copied or committed, and named in the report only by its size and hash. Building and running the references and oracles on open content (homebrew, ps1-tests, content built in code) is the agent's, under `lib/src/darwin/tools/` or in the scratchpad. A probe that runs an app runs the personal build, "iStation Personal", never the App Store build ([Development runs on the personal channel](../../../lib/documentation/assistant/darwin/CLAUDE.md#development-runs-on-the-personal-channel)).
- **The clean room** (ADR 0013): a GPL oracle (SwanStation, PCSX2) is only built unmodified and run, as a black box — its own debugger, trace and logging first, else LLDB or Frida for guest state only; never open, read or disassemble its source, and never point `revula_disassemble` or `revula_decompile` at it. A session that has read one writes no core code.

## 4. Frame the findings as walls

Number them **W1, W2, …** so the report and the eventual split can cite them. Each has its **evidence** (the command and its output, or `file:line`), the **wall** in one plain sentence, and the **smallest capability that removes it**.

Just as important: record what **already works** with zero changes. A spike that lists only problems hides the shortest path and over-scopes the split.

Quantify: "by frame 600 the two consoles' RAM differs in 1,424 of 2,097,152 bytes, and the shell waits on one GPUSTAT bit" decides an item; "the boot is mostly right" decides nothing.

## 5. Report, then wait

In the final chat message:

1. **The question**, as asked.
2. **Method** — what was run or read, in one short paragraph, naming the sandbox.
3. **Walls**, each with its evidence and the capability that removes it, and the **already-works** list.
4. **The proposed documents** — the walls grouped into right-sized items (one focused session each): for each, a working title, its target table (a version, Architecture or Maintenance, and its OS folder if it binds one app), its gate, the walls it closes, and its layer and module(s) per the codebase map. Note where one root-cause fix collapses several walls. This list is the hand-off: on "execute", each entry becomes one document with nothing left to decide but its open calls.
5. **The user-owned questions**, in plain language, each with what it decides — and a recommended default for everything agent-decidable. If the user asks to be interviewed, use AskUserQuestion; otherwise list the questions.

Then **stop**: no documents, items or code until the user says what to execute.
