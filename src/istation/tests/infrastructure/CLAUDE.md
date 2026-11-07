# The Infrastructure tests

**Mirror.** `tests/infrastructure/<module>/` tests `source/infrastructure/<module>/` ([ADR 0004](../../../../documentation/istation/adrs/tests-mirror-architecture.md)); a new module brings its test directory in the same change.

**Builds as:** one Swift Testing target per module, `Infrastructure<Name>Tests`, depending on its module and its declared support only: a test that imports anything else fails `ArchitectureTests`.

**Support:** `SupportSandbox` (`tests/support/sandbox/`) — a fresh, uniquely named temporary folder per test, removed afterwards, with helpers to write files and folders into it.

**Conventions:** hermetic — no network, nothing written outside the test's `Sandbox`, never the real home folder (`ArchitectureTests` fails on any reach for it), no processes.

**Depth:** [ADR 0004](../../../../documentation/istation/adrs/tests-mirror-architecture.md) · [ADR 0001](../../../../documentation/istation/adrs/layer-enforcement.md) · [DEVELOPER.md](../../../../documentation/istation/assistant/DEVELOPER.md) (the test table).
