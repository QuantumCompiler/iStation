---
name: istation-backlog-create-item
description: Spec one iStation work item into the backlog table the user names (a version table like v0.1.0, Maintenance, or Architecture) — one document to the house format, its index row, preamble and ROADMAP line — without implementing it. Use when the user says "add an item for…", "spec this", "write a backlog item", "put X on the v0.2.0 table", "queue a maintenance item", "create a ticket for…", or describes a feature to be built later.
---

# Create a backlog item — iStation

One item, specced so an agent can build it straight from its document. Never start implementing.

The docs home is [`documentation/istation/`](../../../documentation/istation/README.md); the index and the document format are in [`backlog/README.md`](../../../documentation/istation/backlog/README.md).

## 1. The destination

The user names the table (a version — `v0.0.1`, `v0.1.0` … `v2.0.0` per the [ROADMAP](../../../documentation/istation/assistant/ROADMAP.md) — or Maintenance, or Architecture) and the position. Ask only if they haven't. The id follows the index rules: a track letter for a release item, the next `M<n>`/`A<n>` for a standing one; never reuse a spent id.

## 2. Read before writing

1. The backlog README — format, tags, gates, numbering, the ids spent.
2. [CLAUDE.md](../../../documentation/istation/assistant/CLAUDE.md) — the `⚠` invariants, the codebase map, code style.
3. [SPEC.md](../../../documentation/istation/assistant/SPEC.md) — a collision with a non-goal or a shape change → stop and raise it with the user first.
4. [ROADMAP.md](../../../documentation/istation/assistant/ROADMAP.md) — the phase's checklist line it fulfils.
5. **Every existing item, for overlap**: one concern has one home — extend an existing document instead of writing a near-duplicate.

## 3. Write the document

In the table's directory (`backlog/v<x.y.z>/`, `maintenance/` or `architecture/`), kebab-case filename, sections in the README's order, to this bar:

- **What / why** concrete enough to build from, with evidence (`file:line`, measurements). Too big for one focused session → **split first**, listing the sub-documents.
- **Core constraint(s)**: every invariant it touches. Typical for iStation: emulators driven only by their flags (ADR 0008) — a new flag is checked against the emulator's own source; the library file read compatibly (ADR 0007) — a new field is `decodeIfPresent` with a recording; view-models UI-free and visuals from `styles` (ADR 0005); tests hermetic over a `Sandbox` (ADR 0004); a new dependency licence-reviewed onto ADR 0008's allow-list.
- **Seam + files**: the **layer and module** from the codebase map (or a new module with its `Module(.<layer>, "<Name>", uses: […])` row), the interfaces it extends, the planned files and their tests in `src/istation/tests/<layer>/<module>/`.
- **Reference**: in-house precedents and prior art, and each deliberate divergence.
- **Decisions made**, dated and attributed — including this placement.
- **Open calls**, every one tagged: `[user]` (blocks the build), `[default: …]` (taken by the builder, veto-able), `(consumed decision)` (owned elsewhere — cite the owner).
- **Guardrail(s)** that make a regression loud (a named test).
- **Acceptance criteria**, observable.
- **Scope note**: the version or queue, the gate (pending ids only), what is out of scope.

## 4. Place it

The index row (in build order, the right status: 🟢, or 🔒 with its gate ids), a line in the table's preamble, the ROADMAP line linking it, and the "Ids spent so far" line. SPEC only for a real scope change, with a dated note. Never MILESTONES.

## 5. Validate and report

`python3 scripts/validate_docs.py documentation` (from the repository root) is clean. Report the path, id, position, gate, the docs updated, and every `[user]` call.
