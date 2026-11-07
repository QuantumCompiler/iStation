# The Presentation tests

**Mirror.** `tests/presentation/<module>/` tests `source/presentation/<module>/` ([ADR 0004](../../../../documentation/istation/adrs/tests-mirror-architecture.md)); a new module brings its test directory in the same change.

**Builds as:** one Swift Testing target per module, `Presentation<Name>Tests`, depending on its module and its declared support; it may import its module's own edges.

**View-models are the proof.** A module's tests construct its view-models over real or scripted inputs, call their intents and assert their named states — every state, the failures included. No UI automation; views are seen through their previews ([ADR 0006](../../../../documentation/istation/adrs/presentation-previews.md)).

**Support:** none yet; a fake two modules' tests need lives at the lowest test layer that needs it.

**Conventions:** hermetic — no network, files only inside a `Sandbox`, never the real home folder.

**Depth:** [ADR 0004](../../../../documentation/istation/adrs/tests-mirror-architecture.md) · [ADR 0005](../../../../documentation/istation/adrs/presentation-mvvm.md) · [DEVELOPER.md](../../../../documentation/istation/assistant/DEVELOPER.md) (the test table).
