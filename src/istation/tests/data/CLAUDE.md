# The Data tests

**Mirror.** `tests/data/<module>/` tests `source/data/<module>/` ([ADR 0004](../../../../documentation/istation/adrs/tests-mirror-architecture.md)); a new module brings its test directory in the same change.

**Builds as:** one Swift Testing target per module, `Data<Name>Tests`, depending on its module and its declared support; it may import its module's own edges (Data and Infrastructure) and nothing above: a Data test that imports Business fails `ArchitectureTests`.

**Support:** `SupportSandbox` (infrastructure) and `SupportDiscFixtures` (`tests/support/discfixtures/`) — `makeISO(files:raw:)` builds a tiny ISO 9660 image, cooked or raw 2352-byte. Tests never use real disc images.

**Conventions:** hermetic — no network, files only inside a `Sandbox`, never the real home folder. A persisted format gets a recorded fixture of each released shape, never edited ([ADR 0016](../../../../documentation/istation/adrs/two-build-routines-and-a-fresh-start.md) §5).

**Depth:** [ADR 0004](../../../../documentation/istation/adrs/tests-mirror-architecture.md) · [ADR 0001](../../../../documentation/istation/adrs/layer-enforcement.md) · [DEVELOPER.md](../../../../documentation/istation/assistant/DEVELOPER.md) (the test table).
