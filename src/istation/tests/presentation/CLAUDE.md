# The Presentation tests

**Mirror.** `tests/presentation/<module>/` tests `source/presentation/<module>/` ([ADR 0004](../../../../documentation/istation/adrs/tests-mirror-architecture.md)); a new module brings its test directory in the same change.

**Builds as:** one Swift Testing target per module, `Presentation<Name>Tests`, depending on its module and its declared support; it may import its module's own edges.

**View-models are the proof.** A module's tests construct its view-models over scripted fakes, call their intents and assert their named states — every state, the failures included. No UI automation; views are seen through their previews ([ADR 0006](../../../../documentation/istation/adrs/presentation-previews.md)).

**Support:** `SupportLibraryFakes` (`LibraryHarness` and its fakes) for `shell`, `library` and `settings`; `SupportSandbox` for `app`, whose tests build the real composition over a sandbox home with a non-running `ProcessRunning` and a table `AppLookup`.

**Conventions:** hermetic — no network, files only inside a `Sandbox`, never the real home folder, no real processes, no Launch Services lookups.

**Depth:** [ADR 0004](../../../../documentation/istation/adrs/tests-mirror-architecture.md) · [ADR 0005](../../../../documentation/istation/adrs/presentation-mvvm.md) · [DEVELOPER.md](../../../../documentation/istation/assistant/DEVELOPER.md) (the test table).
