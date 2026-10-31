# The Business tests

**Mirror.** `tests/business/<module>/` tests `source/business/<module>/` ([ADR 0004](../../../../documentation/istation/adrs/tests-mirror-architecture.md)); a new module brings its test directory in the same change.

**Builds as:** one Swift Testing target per module, `Business<Name>Tests`, depending on its module and its declared support; it may import its module's own edges and nothing in Presentation.

**Support:** `SupportSandbox`, `SupportDiscFixtures`, and `SupportLibraryFakes` (`tests/support/libraryfakes/`, business layer) — `LibraryHarness` builds a `Library` over `MemoryStore`, `ScriptedScanner`, `ScriptedStarter` and `FixedDetector`, with `FixtureGames` (real-shaped games) and `settle(until:)` to let a session's end land on the main actor.

**Conventions:** hermetic — no network, files only inside a `Sandbox`, never the real home folder, never a real emulator: launching is tested over a recording `ProcessRunning` and a fake `.app` in the sandbox. A behavior spanning layers (scan a folder of fixture discs into games) is tested here, in the highest layer it touches.

**Depth:** [ADR 0004](../../../../documentation/istation/adrs/tests-mirror-architecture.md) · [ADR 0001](../../../../documentation/istation/adrs/layer-enforcement.md) · [DEVELOPER.md](../../../../documentation/istation/assistant/DEVELOPER.md) (the test table).
