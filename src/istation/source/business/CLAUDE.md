# The Business layer

**Position.** Third of the four ([ADR 0001](../../../../documentation/istation/adrs/layer-enforcement.md)): the cores — what a console does. Today the R3000A interpreter, ported from ProjectPSX, and the PS1 console as a powered-off placeholder that the memory map and devices (item 3f) fill in.

**Modules:** `r3000a` (the R3000A interpreter: the PS1's CPU and the PS2's I/O processor), `ps1` (the PS1 console)

**May depend on:** Business, Data and Infrastructure — and no UI or Apple framework: the Swift standard library, and nothing else without a recorded reason ([ADR 0015](../../../../documentation/istation/adrs/a-core-is-a-cpu-module-and-a-console-module.md)). A CPU family is one module generic over its bus; a console is one module owning its memory map; hot paths use concrete types or `@inlinable` generics, never protocol-typed values, and a class's stored `var`s on a hot path are `@exclusivity(unchecked)` (the dynamic check cost the R3000A 15×). Shipped code comes only from permissive sources, with its notice ([ADR 0013](../../../../documentation/istation/adrs/shipped-code-derives-only-from-permissive-references.md), [ADR 0014](../../../../documentation/istation/adrs/own-code-is-mit-and-derived-code-keeps-its-notice.md)).

**Enforced by:** one SwiftPM target per module, generated from the module map in `src/istation/Package.swift`, and `ArchitectureTests` (`src/istation/tests/architecture/`), run by `swift test`.

**Changing this layer:**
- A new module: its directory `source/business/<module>/`, its `Module(.business, "<Name>", uses: […])` row in `Package.swift`, its tests in `tests/business/<module>/` (and in the `macOS Personal` scheme of `iStation.xcodeproj`), its name on this card and in [ADR 0002](../../../../documentation/istation/adrs/module-map.md)'s table — in the same change.
- A core reaches TraceKit only through a generic tracer a release build specializes to nothing, its imports under `#if PERSONAL_BUILD` ([ADR 0016](../../../../documentation/istation/adrs/two-build-routines-and-a-fresh-start.md)).

**Depth:** [the ADRs](../../../../documentation/istation/adrs/README.md) · [CLAUDE.md](../../../../documentation/istation/assistant/CLAUDE.md) · [DEVELOPER.md](../../../../documentation/istation/assistant/DEVELOPER.md).
