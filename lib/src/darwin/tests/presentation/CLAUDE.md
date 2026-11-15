# The Presentation tests

**Mirror.** `tests/presentation/<module>/` tests `source/presentation/<module>/` ([ADR 0019](../../../../documentation/adrs/darwin/tests-live-in-the-layer-of-what-they-test.md)); a new module brings its test directory in the same change.

**Builds as:** one Swift Testing target per module, `Presentation<Name>Tests`, depending on its module and its declared support; it may import its module's own edges.

**View-models are the proof.** A module's tests construct its view-models over real or scripted inputs, call their intents and assert their named states — every state, the failures included. No UI automation; views are seen through their previews ([ADR 0021](../../../../documentation/adrs/darwin/presentation-modules-stand-alone-and-preview-sample-data.md)).

**Support:** none yet; a fake two modules' tests need lives at the lowest test layer that needs it.

**Conventions:** hermetic — no network, files only inside a `Sandbox`, never the real home folder.

**Depth:** [ADR 0019](../../../../documentation/adrs/darwin/tests-live-in-the-layer-of-what-they-test.md) · [ADR 0020](../../../../documentation/adrs/darwin/presentation-is-mvvm-with-one-styles-module.md) · [DEVELOPER.md](../../../../documentation/assistant/darwin/DEVELOPER.md) (the test table).
