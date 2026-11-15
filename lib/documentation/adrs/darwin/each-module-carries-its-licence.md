# ADR 0011 — Each module carries its licence, and never depends on a stricter one

**Status:** Superseded by [ADR 0014](own-code-is-mit-and-derived-code-keeps-its-notice.md) (2026-11-07, the same day: the App Store brief) · **Date:** 2026-11-07

## Context

The re-vision ([ADR 0010](cores-are-ports-of-open-references.md)) puts two kinds of code in one app: cores ported from GPLv3 references, and shared infrastructure — the library, the frontend, the renderer layer, audio, input and the trace harness — written from scratch. The user's brief (2026-11-07) requires the shared infrastructure to be MIT or GPL-2.0-or-later and never to contain emulator code, so a later PS3 core, ported from GPLv2-only RPCS3 and shipped as a separate executable, can use it. Asked the same day, the user chose **GPL-2.0-or-later** for it (the user's call).

Today every module is shared infrastructure: all 21 were written for iStation, none from an emulator. The repository has no licence file yet. The module map in `Package.swift` ([ADR 0002](module-map.md)) already declares each module's layer and edges, and `ArchitectureTests` already parses it.

## Decision

1. **Every module has a licence**: `GPL-2.0-or-later` for shared infrastructure — every module written from scratch for iStation, including all 21 today — or `GPL-3.0` for a module that ports code from a GPLv3 reference.
2. **A module depends only on modules under the same or a more permissive licence.** A GPL-2.0-or-later module never imports a GPL-3.0 module, and its tests and test support follow the same rule. A core may import shared infrastructure, never the other way round: the frontend reaches a core only through the interface in [ADR 0012](cores-shape-and-hot-paths.md) and the composition root.
3. **Every source file states its licence** in an SPDX header. A ported file also names the reference file it comes from and that file's copyright holders — the credit the reference's licence requires, and the provenance record ADR 0010 asks for.
4. **The repository carries both licence texts**, and the app as a whole is distributed under GPLv3.

## Consequences

- The licence boundary is visible in the same place as the layer law: one row, one licence.
- Moving code across the boundary is a licence change, not a refactor: shared code may never be "promoted" out of a core.
- The composition root (`PresentationApp`) is where the two meet; it is GPL-3.0 as soon as it constructs a core, while the rest of the frontend stays GPL-2.0-or-later.
- A GPLv2-only executable later links only GPL-2.0-or-later modules.

## Enforcement

Planned, Architecture item A1: a `licence:` field on every `Module(…)` and `Support(…)` row, and an `ArchitectureTests` rule that fails on any edge from a module to one under a stricter licence and on any source file without an SPDX header — each verified against a planted violation. Until A1 ships, no GPL-3.0 module may be added (A1 gates the first ported module, v0.0.1 item 2c), so the boundary cannot be crossed before it is checked.
