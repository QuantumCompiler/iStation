# The Presentation tests

**Mirror.** `tests/presentation/<module>/` tests `source/presentation/<module>/` ([ADR 0019](../../../../documentation/adrs/darwin/tests-live-in-the-layer-of-what-they-test.md)); a new module brings its test directory in the same change.

**Builds as:** one Swift Testing target per module, `Presentation<Name>Tests`, depending on its module and its declared support; it may import its module's own edges.

**View-models are the proof.** A module's tests construct its view-models over real or scripted inputs, call their intents and assert their named states — every state, the failures included. No UI automation; views are seen through their previews ([ADR 0021](../../../../documentation/adrs/darwin/presentation-modules-stand-alone-and-preview-sample-data.md)). `styles` has no view-model: its tests read the design's [`json/tokens.json`](../../../../documentation/design/darwin/json/tokens.json) by its repository path, read-only, and fail while a token differs from its Swift value or a contrast pair, recomputed from the Swift values, falls below its minimum; they also resolve the theme under each appearance ([ADR 0023](../../../../documentation/adrs/darwin/presentation-is-mvvm-and-styles-carries-the-design.md)). `bios`'s tests drive the check and the pane over an in-memory library and a scripted console session — one that can hold a power-on or a stop, so a Stop can land mid-way — every wait ending after two seconds, so a regression fails instead of hanging; they read the design's [`html/main.html`](../../../../documentation/design/darwin/html/main.html) the same way, read-only, so the first run's words stay the design's.

**Support:** `SupportSandbox` (Infrastructure), for `bios`' `LibraryBIOSStorageTests`, which keep a BIOS in a real `library.json` inside a `Sandbox`; a fake two modules' tests need lives at the lowest test layer that needs it.

**Conventions:** hermetic — no network, files only inside a `Sandbox`, never the real home folder. The one file read outside the repository is the system's own record of when each SF Symbol arrived, read-only, by `styles`' symbol test, which skips itself when the file is missing or unlike what it expects.

**Depth:** [ADR 0019](../../../../documentation/adrs/darwin/tests-live-in-the-layer-of-what-they-test.md) · [ADR 0023](../../../../documentation/adrs/darwin/presentation-is-mvvm-and-styles-carries-the-design.md) · [DEVELOPER.md](../../../../documentation/assistant/darwin/DEVELOPER.md) (the test table).
