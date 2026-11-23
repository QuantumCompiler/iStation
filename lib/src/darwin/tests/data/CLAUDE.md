# The Data tests

**Mirror.** `tests/data/<module>/` tests `source/data/<module>/` ([ADR 0019](../../../../documentation/adrs/darwin/tests-live-in-the-layer-of-what-they-test.md)); a new module brings its test directory in the same change.

**Builds as:** one Swift Testing target per module, `Data<Name>Tests`, depending on its module and its declared support; it may import its module's own edges (Data and Infrastructure) and nothing above: a Data test that imports Business fails `ArchitectureTests`.

**Support:** `SupportSandbox` (infrastructure) and `SupportDiscFixtures` (`tests/support/discfixtures/`) — `makeISO(files:raw:)` builds a tiny ISO 9660 image, cooked or raw 2352-byte. Tests never use real disc images.

**Conventions:** hermetic — no network, files only inside a `Sandbox`, never the real home folder. A persisted format gets a recorded fixture of each released shape, never edited ([ADR 0016](../../../../documentation/adrs/darwin/two-build-routines-and-a-fresh-start.md) §5): a module's fixtures sit in its test directory's `Fixtures/`, read from the repository by `#filePath` and named in `Package.swift`'s `testFixtures`, which keeps them out of the test target. Today that is `library/Fixtures/`: `library-v1.json`, the recorded shape `library.json`'s version 1 (5c's) was written in, which every later build still loads; `library-v1-no-checked.json`, a made-up version-1 record missing a field, which no build writes — it stood in for an older shape before one existed, so its defaults are tested; and `library-v2.json`, the recorded shape of version 2 (5d's, with the games), which this build writes as the same JSON, every key and value, and loads back. A game's folder of files is built in the test, tiny cue sheets, playlists and tracks of a few bytes.

**Depth:** [ADR 0019](../../../../documentation/adrs/darwin/tests-live-in-the-layer-of-what-they-test.md) · [ADR 0024](../../../../documentation/adrs/darwin/four-layers-and-business-holds-the-session.md) · [DEVELOPER.md](../../../../documentation/assistant/darwin/DEVELOPER.md) (the test table).
