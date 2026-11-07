# ADR 0009 — Previews show the sample games, never the user's own library

**Status:** Accepted · **Date:** 2026-11-02 · Supersedes the preview-data plan in [ADR 0006](presentation-previews.md) §3

## Context

[ADR 0006](presentation-previews.md) planned for previews to swap their real-shaped sample games for a recorded `library.json` from the user's own library once the v0.0.1 gate had run (item 1a). That recording would carry the user's game titles and serials into a repository that goes public at v1.0.0. Asked on 2026-11-02, the user chose to keep the sample games (the user's call).

## Decision

**Preview data is the sample games — the titles, serials and boot targets `LibraryScanner` reports for the disc fixtures in `tests/support/discfixtures` — and nothing derived from the user's own library is committed**: not as preview data, not as a test fixture, not as a recorded `library.json`. A preview state with no sample to show it is previewed from the samples, never from a real library.

Everything else in ADR 0006 stands.

## Consequences

- Previews and tests keep showing the same three sample games (Crash Bandicoot, a PS2 sample, Demon's Souls); a new visible state gets new sample data, built like the existing samples.
- The recorded `library.json` in `RecordedLibraryFileTests` ([ADR 0007](backwards-compatibility.md)) stays a recording of the real encoder writing sample data, never a copy of the user's file.
- Runs against the user's library (item 1a and later gates) record only versions, consoles, serials and file types in MILESTONES, never titles or paths.

## Enforcement

Until a check can tell sample data from real data, this record and review hold the line: a change that adds a `library.json`, a title list or paths from a real library to the repository is rejected by citing it.
