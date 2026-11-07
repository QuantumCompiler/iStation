# Each module carries its licence — tags, the boundary check, SPDX headers, licence files

**What / why.** [ADR 0011](../../adrs/each-module-carries-its-licence.md) (2026-11-07) splits iStation into shared infrastructure (GPL-2.0-or-later, written from scratch) and ported cores (GPLv3, derived from SwanStation and later PCSX2), and forbids a module from depending on one under a stricter licence — so a later GPLv2-only PS3 core can reuse the shared modules from its own executable. Today that is a rule without teeth: no module states a licence, no source file has a header, and the repository has no licence file at all (checked 2026-11-07: no `LICENSE` or `COPYING` at the root; SwanStation's own sources carry no per-file headers either, so its credit has to be written into ours). This item gives the rule its check before the first GPL-3.0 module (2c) lands — it is that item's gate.

**Core constraint(s).** The layer law: the module map stays the one declaration ([ADR 0002](../../adrs/module-map.md)) and each `Module(…)` row stays on one line, because `ArchitectureTests` parses it. Ported code on its side of the licence line (⚠ in CLAUDE.md; [ADR 0010](../../adrs/cores-are-ports-of-open-references.md)). Every architecture rule is proven against a planted violation (DEVELOPER.md → "Proving an architecture rule").

**Seam + files.**
- `src/istation/Package.swift`: a `Licence` enum (`gpl2OrLater`, `gpl3Only`), a `licence:` parameter on `Module`, `Support` and `EntryPoint`, set on every row — every one of today's 21 modules, 3 support targets and the entry point is `.gpl2OrLater`.
- `src/istation/tests/architecture/Repository.swift`: the row parser reads the licence.
- `src/istation/tests/architecture/ProjectRulesTests.swift` (or `LayeringTests.swift`): two rules — no edge (source, test or support) from a module to one under a stricter licence; every Swift file under `source/` and `tests/` starts with an `SPDX-License-Identifier` line equal to its module's licence.
- An SPDX header on every Swift file (about 110 files today).
- Licence texts: `LICENSES/GPL-2.0-or-later.txt`, `LICENSES/GPL-3.0-only.txt`, and a root `LICENSE` stating that the app as a whole is GPLv3.
- Docs: ADR 0011's Enforcement, CLAUDE.md's invariant and checklist, DEVELOPER.md's "Adding a module" recipe (a row now names its licence), the root README's Licence section.

**Reference.** The [REUSE](https://reuse.software) layout (`LICENSES/<SPDX-id>.txt`, SPDX headers). In-house precedent: the module-map parser and the planted-violation discipline of Milestone A (44 plants, 44 caught). PCSX2's own files carry SPDX headers (`GPL-3.0+`); SwanStation's carry none.

**Decisions made** (dated):
- 2026-11-07: shared infrastructure is GPL-2.0-or-later (the user's call); ported cores are GPLv3 and the app as a whole is GPLv3 (the user's brief).
- 2026-11-07: queued as Architecture A1, gating 2c, so no GPL-3.0 module lands unchecked (the re-vision's default, taken).

**Open calls:**
- [default: `GPL-3.0-only` for modules ported from SwanStation, because its `LICENSE` grants no "or later"; a PCSX2-derived module takes the id its source files carry, decided in v2.x] The SPDX id of a ported module.
- [default: three comment lines — `// SPDX-License-Identifier: <id>`, `// SPDX-FileCopyrightText: <holders>`, and, in a ported file, `// Ported from <reference>/<path> — <its authors>`] The header's form.
- [default: "iStation contributors" in the copyright line of iStation's own files, with the git history as the record of who] The copyright holder named for shared infrastructure.
- [default: the entry point and `PresentationApp` stay GPL-2.0-or-later until the composition root constructs a core (v0.1.0); they become GPL-3.0 then, as ADR 0011 says] The composition root's licence.

**Guardrail(s).** Each new rule fails on a planted violation and passes once it is removed: a GPL-2.0-or-later module whose row names a GPL-3.0 module; a test importing a stricter module; a Swift file with no header; a header disagreeing with its module's row. A rule SwiftPM won't load is planted in a manifest copy through `ISTATION_ARCHITECTURE_MANIFEST`.

**Acceptance criteria:**
- [ ] Every `Module`, `Support` and `EntryPoint` row names its licence, on one line.
- [ ] Every Swift file under `source/` and `tests/` starts with its SPDX header.
- [ ] `swift test` fails on each planted violation above, naming the rule and the file, and passes clean.
- [ ] `LICENSES/` holds both texts and the root `LICENSE` names GPLv3 for the app as a whole.
- [ ] ADR 0011's Enforcement says "enforced", and CLAUDE.md's invariant names the check.

**Scope note.** Architecture, claimable any time; no gate. It gates v0.0.1's 2c (the first GPL-3.0 module). Out of scope: headers on files outside `src/istation/` (the tools in 2b state their licence in their README), and any licence for a PS3 core.
