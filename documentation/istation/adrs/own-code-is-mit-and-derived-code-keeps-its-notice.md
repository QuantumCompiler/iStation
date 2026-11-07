# ADR 0014 — iStation's own code is MIT; derived code keeps its reference's notice

**Status:** Accepted · **Date:** 2026-11-07 · Supersedes [ADR 0011](each-module-carries-its-licence.md)

## Context

[ADR 0011](each-module-carries-its-licence.md) split the code into GPL-2.0-or-later shared infrastructure and GPL-3.0 cores. With the App Store brief ([ADR 0013](shipped-code-derives-only-from-permissive-references.md)) no GPL code ships at all, and the brief lets the project choose its own licence. Asked on 2026-11-07, the user chose **MIT** (the user's call). The references' own terms still apply to what is ported from them: ProjectPSX's MIT licence and Play!'s BSD licences require their copyright notices to be kept in source and in binary distributions. The repository has no licence file yet.

## Decision

1. **iStation's own code is MIT**, under a root `LICENSE`.
2. **Every source file states its licence** in an SPDX header: `MIT` for iStation's own code and for code ported from ProjectPSX; `BSD-2-Clause` for code ported from Play! and its libraries.
3. **A ported file names its source and keeps its notice**: the reference repository and file it comes from, and that file's copyright line (ProjectPSX's holder for PS1 code; "Jean-Philip Desjardins" for Play! code), beside iStation's own.
4. **Every app shows every notice** it carries — ProjectPSX's MIT text, Play!'s and its libraries' BSD texts, and any audited dependency's — in its acknowledgements screen, generated from one list in the repository so source and screen can't drift.
5. **Nothing GPL ships.** Tools that run GPL oracles live outside the shipped package (`tools/`) and are never distributed.

## Consequences

- The licence boundary of ADR 0011 is gone: every shipped module is MIT or BSD, and a module may depend on any other the layer law allows.
- A file mixing ProjectPSX-derived and iStation-written code is MIT with both copyright lines; a file mixing in Play! code carries the BSD notice too.
- The acknowledgements list is part of each release; a new dependency adds its notice there in the same change.

## Enforcement

Enforced since Architecture item A2 (2026-11-07, [Milestone H](../assistant/MILESTONES.md#milestone-h--provenance-headers-and-notices)): `ArchitectureTests/ProjectRulesTests.swift` — `everyFileHasItsHeader` fails on a Swift file in the package or the apps without its two SPDX lines, or naming a licence with no text in `LICENSES/`; `portedModulesNameTheirSources` fails on a file in a module the map marks `derivedFrom:` without its `// Ported from <repository>/<path> — <copyright>` line or with another licence than its reference's; `everyLicenceIsAcknowledged` fails on a licence or a reference missing from `src/istation/apps/Acknowledgements.json`, or an entry without a notice. Each verified against a planted violation, 2026-11-07. That a ported file's code really comes from the file it names is held by review.
