# ADR 0003 — One concern per module

**Status:** Accepted · **Date:** 2026-10-31

## Context

Tangles start where two concerns share a module: the dependency one of them needs becomes the other's too, and an edge that would be visible between modules hides inside one. The scaffold's `iStationCore` held eleven concerns — four file formats, identification, scanning, launching, emulator lookup, persistence and the record types — in one target; carving it showed, for instance, that the store needed nothing of the launcher, and that the PS3 formats needed nothing of the PS1/PS2 ones.

## Decision

**A module is one concern, and stays one.** Within every layer:

- A module owns a single responsibility, nameable in a phrase; the directory name is that phrase.
- A module that accretes a second concern **splits** — ordinary maintenance, not an architecture event.
- New capability generally means a **new module**, not a bigger one: CHD support is a new Data module beside `iso9660`, not a branch inside it; cover art is a new module, not a field in `store`.
- Module boundaries are visible to the build: one SwiftPM target per module, so a dependency is a declared edge, never an accident of a shared target.

## Consequences

- Many small modules over few large ones — short files, per-module tests, a module a reviewer can hold in their head. iStation's 19 scaffold files became 21 modules on 2026-10-31.
- "Where does this go?" has a checkable answer: the module whose phrase describes it, or a new one.
- Chosen trade-off: more directories and targets, accepted because the real cost sits in tangles, not file count.

## Enforcement

The module map and its checks ([ADR 0002](module-map.md)); the review rule that a module description needing "and" is a split waiting; the codebase map in [CLAUDE.md](../assistant/CLAUDE.md#codebase-map) lists one concern per row — a row that can't be written that way fails the docs pass (`/istation-maintenance-update-documents`).
