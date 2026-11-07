# Provenance headers and notices — SPDX headers, provenance lines, the acknowledgements list, the root licence

**What / why.** [ADR 0014](../../adrs/own-code-is-mit-and-derived-code-keeps-its-notice.md) (2026-11-07): iStation's own code is MIT (the user's call), code ported from ProjectPSX keeps its MIT notice, code from Play! and its libraries keeps their BSD notices, and every app shows every notice it carries. Today none of it exists: no source file has a header and the repository has no licence file (checked 2026-11-07). ProjectPSX's MIT licence and Play!'s BSD licences require their copyright notices in source and in binary distributions, so the check lands before the first ported module (3e), which it gates.

**Core constraint(s).** Shipped code only from permissive sources (⚠ in CLAUDE.md; [ADR 0013](../../adrs/shipped-code-derives-only-from-permissive-references.md)): the provenance line is the record review relies on. The layer law: the module map stays the one declaration and each row stays on one line, because `ArchitectureTests` parses it ([ADR 0002](../../adrs/module-map.md)). Every new rule is proven against a planted violation.

**Seam + files.**
- `src/istation/Package.swift`: a `derivedFrom:` field on `Module` rows — `.none` (iStation's own), `.projectPSX`, `.play` — on one line.
- `src/istation/tests/architecture/Repository.swift`: the row parser reads it.
- `src/istation/tests/architecture/ProjectRulesTests.swift`: three rules — every Swift file under `source/` and `tests/` starts with an SPDX header; every file in a module derived from a reference carries a provenance line naming its source file and that file's copyright; every licence a header names appears in the acknowledgements list.
- The acknowledgements list, one file the apps' screen reads from 3b on: each entry's name, licence id, notice text and source URL (ProjectPSX, Play!, Play--Framework, Play--CodeGen, Nuanceur, and each audited dependency as it arrives).
- Licence texts: a root `LICENSE` (MIT, iStation contributors); `LICENSES/MIT.txt` and `LICENSES/BSD-2-Clause.txt`.
- An SPDX header on every Swift file present when this lands.
- Docs: ADR 0014's Enforcement, CLAUDE.md's invariant and checklist, DEVELOPER.md's "Adding a module" recipe, the root README.

**Reference.** The [REUSE](https://reuse.software) layout (`LICENSES/<SPDX-id>.txt`, SPDX headers). ProjectPSX's `LICENSE` (MIT) and Play!'s `License.txt` files (BSD, © Jean-Philip Desjardins), read 2026-11-07. In-house: the module-map parser and Milestone A's planted-violation discipline.

**Decisions made** (dated):
- 2026-11-07: iStation's own code is MIT (the user's call); derived code keeps its reference's notice; nothing GPL ships (the user's brief).
- 2026-11-07: the header is three comment lines — `// SPDX-License-Identifier: <id>`, `// SPDX-FileCopyrightText: <holders>`, and in a ported file `// Ported from <repository>/<path> — <its copyright line>` (the default, confirmed by the user).
- 2026-11-07: "iStation contributors" is the copyright holder of iStation's own files, with the git history as the record of who (the default, confirmed by the user).
- 2026-11-07: the acknowledgements list is one JSON file in the package, so source, tests and both apps read the same entries (the default, confirmed by the user).
- 2026-11-07: a file mixing ProjectPSX-derived and iStation-written code is MIT with both copyright lines; a file with Play!-derived code is `BSD-2-Clause` (the default, confirmed by the user).
- 2026-11-07: built in the `/istation-backlog-execute-group v0.0.1` run, before 3e, because it gates it (the user's call).

**Open calls:** none — all answered 2026-11-07.

**Guardrail(s).** Each rule fails on a planted violation and passes once it is removed: a Swift file without a header; a file in a `.projectPSX` module without a provenance line; a header naming a licence missing from the list.

**Acceptance criteria:**
- [ ] Every Swift file under `source/` and `tests/` starts with its SPDX header.
- [ ] Every `Module` row states what it derives from, on one line.
- [ ] `swift test` fails on each planted violation, naming the rule and the file, and passes clean.
- [ ] The root `LICENSE`, `LICENSES/` and the acknowledgements list exist, the list holding ProjectPSX's and Play!'s notices.
- [ ] ADR 0014's Enforcement says "enforced".

**Scope note.** Architecture, claimable any time; no gate. It gates v0.0.1's 3e (the first ported module). Out of scope: the acknowledgements screen itself (EmuKit, v1.0.0), and headers in `tools/` (each tool's README states its licence).
