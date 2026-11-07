# ADR 0007 — A library file written by an older iStation keeps loading

**Status:** Superseded by [ADR 0016](two-build-routines-and-a-fresh-start.md) (2026-11-07): the library file retires with the library app; the rule carries to the new apps' settings and memory cards · **Date:** 2026-10-31

## Context

iStation persists state its user owns — `~/Library/Application Support/iStation/library.json`: the library folders and their console hints, every game with its last-played date and total play time, and the settings ([reference/library-file.md](../reference/library-file.md)). Play history cannot be rebuilt by a rescan; an upgrade that cannot read the file, or silently rewrites it, costs the user their history. The scaffold already decoded settings field by field "so adding a setting later doesn't wipe an existing library file" (the user's design, 2026-10-26).

## Decision

**State written by an older version is read compatibly, or migrated by a named, tested step.** The format changes additively:

- A new field is optional or has a default, and decodes with `decodeIfPresent` (`AppSettings`, `LaunchOptions` and `LibraryState` already do; `Game` and `LibraryFolder` gain a custom decoder with their first added field).
- Unknown fields are tolerated (Swift's keyed decoding ignores them).
- Nothing is renamed, retyped or removed without a migration and a superseding record. A game's ID format (console plus path, or plus title ID) is part of the format: changing it orphans every game's history.

## Consequences

- Every shape change ships with a recording of the previous shape's file and a test reading it.
- A breaking change is a new ADR with its migration, never a silent edit.
- Known gap: a file that fails to decode loads as an empty library, and the next save replaces it — Maintenance item M1.

## Enforcement

`DataStoreTests/RecordedLibraryFileTests.swift` loads `library.json` exactly as v0.0.1 writes it (recorded 2026-10-31 from `LibraryStore.save`) and asserts every field's meaning; a new shape adds a recording and never edits an old one. `LibraryStoreTests` loads files missing whole sections and single settings fields.
