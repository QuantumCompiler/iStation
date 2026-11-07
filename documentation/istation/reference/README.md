# iStation — Reference

The contracts iStation builds against and writes, each pinned by tests. Internals are in [DEVELOPER.md](../assistant/DEVELOPER.md); the rules are in the [ADRs](../adrs/README.md).

| Document | Contract | Pinned by |
|---|---|---|
| [trace-formats.md](trace-formats.md) | TraceKit's trace and checkpoint files, byte by byte: what the Swift port, ProjectPSX and SwanStation's recorder write | `DataTracingTests` |

The library app's two contracts — the installed emulators' command lines and `library.json` — retired with it in v0.0.1's item 3b ([Milestone F](../assistant/MILESTONES.md#milestone-f--the-skeleton-and-both-build-routines)).
