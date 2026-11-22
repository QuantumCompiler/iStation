---
name: istation-backlog-create-item
description: Spec one iStation work item into the backlog table the user names (a version table like v0.1.0, Maintenance, or Architecture) — one document to the house format, its index row, preamble and ROADMAP line — without implementing it; the skill resolves which application is meant and asks when it cannot. Use when the user says "add an item for…", "spec this", "write a backlog item", "put X on the v0.2.0 table", "queue a maintenance item", "create a ticket for…", or describes a feature to be built later.
---

# Create a backlog item — iStation

One item, specced so an agent can build it straight from its document. A backlog document is a working spec, not a ticket: wrong or thin content goes straight into the built code. Never start implementing.

## 0. Which application?

iStation's documentation is split by kind, then by platform ([the router](../../../lib/documentation/CLAUDE.md)): `lib/documentation/{assistant,backlog,adrs,reference}/<app>/`. Today there is one application, **`darwin`**: the Apple apps, one Swift package at `lib/src/darwin/` with the macOS app (PS1 and PS2) and the iOS app (PS1); what binds one OS alone sits in that kind's `darwin/macos/` or `darwin/ios/`. A second application gets its own folder in each kind and a row in the router. Resolve which application this invocation means, and for work that binds one OS which OS folder, before reading anything else, in order:

1. **The arguments.** An id or table names its queue: `darwin`'s version tables (`v0.1.0`, `v0.2.0`, …) with their numeric tracks (`4e`), and its standing `M<n>` and `A<n>` tables. A named document resolves by the backlog that holds it, and by its folder (`macos/`, `ios/`) to one OS.
2. **The conversation.** What the work touches: the package, its cores, the apps, their build routines and their tools (`lib/src/darwin/`) are `darwin`'s; a screen, entitlement or setting of one app alone is that OS's folder; what both apps share is `darwin` itself.
3. **Still ambiguous? Ask.** One AskUserQuestion — which application, or whether the work binds macOS alone, iOS alone or both apps — before anything is treated as decided. Never guess between them. A request for an application that has no folder yet (a web or Windows app, say) is asked about too, never filed under `darwin`.

Everything below reads from the chosen application's folders, written `<app>` (today always `darwin`): its backlog index (`lib/documentation/backlog/<app>/README.md`) is the authority on that queue's tables, numbering, document format and link depths, and its contributor docs (`lib/documentation/assistant/<app>/CLAUDE.md` first) carry the invariants, the clean-room rule first among them. Where this skill says `<app>`, substitute the chosen application's folder name.

**From a brainstorm.** When the idea came out of `superpowers:brainstorming`, this document **is** its written design ([Superpowers fits the docs-first lifecycle](../../../lib/documentation/assistant/darwin/CLAUDE.md#superpowers-fits-the-docs-first-lifecycle)): its approaches, goals, non-goals and the user's decisions land in this format's sections, never in `docs/superpowers/specs/`. Brainstorming's builder check may read the draft before it is placed; the subagent it dispatches is told the GPL rule in its prompt. A throwaway build it offers is a probe in the scratchpad; keeping it is a new item. **The brainstorm ends when the user approves the placed document**: its hard gate's hand-off to `superpowers:writing-plans` gives way, and planning and building wait for a later `/istation-backlog-execute-item`.

## 1. The destination

The user names the table (a version — `v<x.y.z>`, the release in progress or one `lib/documentation/assistant/<app>/ROADMAP.md` plans — or Maintenance, or Architecture) and the position: their placement call. Take it from the request; ask only if they genuinely haven't said. An item that binds one OS alone goes in that OS's folder (`lib/documentation/backlog/<app>/macos/` or `ios/`), listed in the same index. The id follows the index rules, ever-assigned: a release item takes its track's next letter, or the next track number for a new theme; a standing one the next `M<n>`/`A<n>`; never reuse a spent id.

## 2. Read before writing

1. `lib/documentation/backlog/<app>/README.md` — the format (section order), the open-call tags, the gate convention, the index format and numbering, the ids spent, the current index.
2. `lib/documentation/assistant/<app>/CLAUDE.md` — the working process, the `⚠` invariants, the codebase map, code style: constraints the item must carry where they apply.
3. `lib/documentation/assistant/<app>/SPEC.md` — scope, non-goals, principles. A collision with a non-goal or a shape change → **stop and raise it with the user first**: a SPEC revision is its own decision, made before the item exists.
4. `lib/documentation/assistant/<app>/ROADMAP.md` — where the releases stand, the phase's checklist line it fulfils, what is already queued or parked.
5. **Every existing item, for overlap**: one concern has one home — extend an existing document instead of writing a near-duplicate.

## 3. Write the document

In the table's directory of `lib/documentation/backlog/<app>/` (`v<x.y.z>/`, `maintenance/` or `architecture/`, or the same under `macos/` or `ios/` for one OS; created with a table's first item), kebab-case filename, sections in the README's order. Links out of the backlog climb to `lib/documentation/` and back down (`../../../assistant/<app>/…` from a version folder, one level more from an OS folder); same-table links are bare filenames, cross-table ones `../<table-dir>/<file>`. To this bar:

- **What / why** concrete enough to build from, with evidence (`file:line`, measurements). Too big for one focused session → **split first**, listing the sub-documents.
- **Core constraint(s)**: every invariant it touches — a constraint the item doesn't state is one the builder won't honor. Typical for iStation: shipped code only from a permissive source (ProjectPSX, Play!, iStation's own, public documentation), each ported file naming its source and keeping its notice (ADRs 0013, 0014) — checked against the reference's and the oracle's traces, never against a GPL emulator's source; no BIOS, disc image or game in the repository; hot paths with concrete types (ADR 0015); tools only under `PERSONAL_BUILD` (ADR 0016); the user's data read compatibly (ADR 0016 §5) — a new persisted field decodes with a default, a save state carries its version; view-models UI-free and visuals from `styles` (ADR 0023); tests hermetic over a `Sandbox` (ADR 0019); a new dependency audited onto ADR 0013's allow-list.
- **Seam + files**: the **layer and module** from the codebase map (or a new module with its `Module(.<layer>, "<Name>", uses: […])` row), the interfaces it extends, the items it consumes decisions from, the planned files and their tests in `lib/src/darwin/tests/<layer>/<module>/`.
- **Reference**: in-house precedents (shipped items, existing seams) and prior art, cited by name — the ProjectPSX or Play! file a port follows, public documentation (psx-spx, ps2tek); an oracle only by the behaviour recorded from it, never its source. Each deliberate divergence. Omit it rather than cite vaguely.
- **Decisions made**, dated and attributed — including this placement (the user's call).
- **Open calls**, every one tagged: `[user]` only for what is genuinely the user's (blocks the build), `[default: …]` with its recommendation (taken by the builder, veto-able), `(consumed decision)` (owned elsewhere — cite the owner; never reopened).
- **Guardrail(s)** that make a regression loud (a named test), hermetic: a `Sandbox`, programs and memory images built in code, never the real home, a real game or a BIOS. A core's is a trace check — ProjectPSX's trace instruction by instruction, or the oracle's recorded guest state, TraceKit naming the first divergence. A run with the user's BIOS or games is optional, said, and the user's to start — or the agent's when the user gives the paths: the files passed by path, named in reports only by size and hash.
- **Acceptance criteria**, observable — no vibes.
- **Scope note**: the version or queue, the gate (pending ids only, no cycles), what is out of scope.

## 4. Place it

1. **The index row** in the table the user named (creating the table and its directory with its first item), at the position they gave: rows are in build order, and the id stays the next in sequence wherever the row sits — this house does not renumber. The Status cell 🟢, or 🔒 with its gate ids; a **split first** item says so. A line in the table's preamble, and the "Ids spent so far" line.
2. **ROADMAP** (`lib/documentation/assistant/<app>/ROADMAP.md`): the item's line linking its document, in the matching section — the release in progress, a planned release, Architecture, Maintenance, or Ideas.
3. **SPEC** (`lib/documentation/assistant/<app>/SPEC.md`) only for a real scope change, with a dated note.
4. **Never MILESTONES** (finished work only), and never start building: that is `/istation-backlog-execute-item`'s, later.

## 5. Validate, commit and report

- `python3 lib/scripts/validate_docs.py lib/documentation` (from the repository root) is clean.
- **Commit and push** ([Committing and pushing](../../../lib/documentation/assistant/darwin/CLAUDE.md#committing-and-pushing)): one commit on the release branch, staging only this task's paths, its message exactly `v<x.y.z> : Title Case Summary` — no body, no trailers, not even a session's attribution lines — then `git push origin v<x.y.z>`. Never force-push, never push `stable` or a tag; a failed push is reported with its error and left for the user.
- Report: the document's path, its id, position and gate, the docs updated, and **every `[user]` call** it carries — those block the build later, so surfacing them now is the point.
