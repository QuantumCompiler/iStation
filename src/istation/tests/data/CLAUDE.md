# The Data tests

**Mirror.** `tests/data/<module>/` tests `source/data/<module>/` ([ADR 0004](../../../../documentation/istation/adrs/tests-mirror-architecture.md)); a new module brings its test directory in the same change.

**Builds as:** one Swift Testing target per module, `Data<Name>Tests`, depending on its module and its declared support; it may import its module's own edges (Data and Infrastructure) and nothing above: a Data test that imports Business fails `ArchitectureTests`.

**Support:** `SupportSandbox` (infrastructure) and `SupportDiscFixtures` (`tests/support/discfixtures/`) — `makeISO(files:raw:)` builds a tiny ISO 9660 image, cooked or raw 2352-byte; `makeSFO(_:)` builds a PARAM.SFO. Tests never use real disc images.

**Conventions:** hermetic — no network, files only inside a `Sandbox`, never the real home folder. A recorded `library.json` from every released shape lives in `store/RecordedLibraryFileTests.swift` and is never edited ([ADR 0007](../../../../documentation/istation/adrs/backwards-compatibility.md)); a new shape adds a recording.

**Depth:** [ADR 0004](../../../../documentation/istation/adrs/tests-mirror-architecture.md) · [ADR 0001](../../../../documentation/istation/adrs/layer-enforcement.md) · [DEVELOPER.md](../../../../documentation/istation/assistant/DEVELOPER.md) (the test table).
