# The Business tests

**Mirror.** `tests/business/<module>/` tests `source/business/<module>/` ([ADR 0004](../../../../documentation/istation/adrs/tests-mirror-architecture.md)); a new module brings its test directory in the same change.

**Builds as:** one Swift Testing target per module, `Business<Name>Tests`, depending on its module and its declared support; it may import its module's own edges and nothing in Presentation.

**Support:** `SupportSandbox` and `SupportDiscFixtures`, when a core test needs files; `SupportMIPS` (`tests/support/mips/`) — `MIPS`, a small R3000A assembler, and the registers by name; `SupportR3000ATrace` (`tests/support/r3000atrace/`) — `TraceKitTracer`, an R3000A tracer writing TraceKit's records, which brings TraceKit's files and diff with it. A core's tests build their programs and memory images in code — never a BIOS, never a game ([ADR 0013](../../../../documentation/istation/adrs/shipped-code-derives-only-from-permissive-references.md) §6).

**Conventions:** hermetic — no network, files only inside a `Sandbox`, never the real home folder, never a real BIOS or game. Expected results come from psx-spx or a permissive reference's recorded trace, never a GPL emulator's source. A behavior spanning layers is tested here, in the highest layer it touches.

**Depth:** [ADR 0004](../../../../documentation/istation/adrs/tests-mirror-architecture.md) · [ADR 0001](../../../../documentation/istation/adrs/layer-enforcement.md) · [DEVELOPER.md](../../../../documentation/istation/assistant/DEVELOPER.md) (the test table).
