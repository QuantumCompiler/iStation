# iStation — Reference

The contracts iStation builds against and writes, each pinned by tests. Internals are in [DEVELOPER.md](../../assistant/darwin/DEVELOPER.md); the rules are in the [ADRs](../../adrs/darwin/README.md).

| Document | Contract | Pinned by |
|---|---|---|
| [trace-formats.md](trace-formats.md) | TraceKit's trace and checkpoint files, byte by byte: what the Swift port, ProjectPSX and SwanStation's recorder write | `DataTracingTests` |

The library app's two contracts — the installed emulators' command lines and `library.json` — retired with it in v0.0.1's item 3b ([Milestone F](../../assistant/darwin/MILESTONES.md#milestone-f--the-skeleton-and-both-build-routines)). Today's `library.json` (v0.1.0's items 5c and 5d) is a new format, unrelated to it: the app's own record of the user's BIOS, kept by a bookmark and never copied, and from 5d of the games, written by `DataLibrary`'s `LibraryStore` from version 1 and pinned by `DataLibraryTests`' recorded fixtures ([DEVELOPER.md](../../assistant/darwin/DEVELOPER.md#data)).
