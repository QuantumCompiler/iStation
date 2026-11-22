# The narrow interface: boot a PS-EXE, the BIOS's shell, and personal-build debug values

**What / why.** The app reaches the core only through `PS1Console` ([ADR 0015](../../../adrs/darwin/a-core-is-a-cpu-module-and-a-console-module.md) §5), which today offers `name`, `isPoweredOn`, `powerOn(bios:)`, `runFrame()` and `frame` (`source/business/ps1/PS1Console.swift:13–33`). `PS1Machine` already has what three of the design's gaps need, but only the command-line tool can reach it:
- **G5, boot a PS-EXE** (contract rows C19, C49): `PS1Machine.boot(_:)` (`PS1Machine.swift:143`) and `bootIsPending` (`:67`). v0.1.0's gate draws a homebrew PS-EXE in the macOS app, so this is v0.1.0's.
- **G10, the BIOS reached its shell** (C10): `PS1Machine` already watches for the shell's address, 0x80030000, while an EXE waits (`:94`, `:111`). The BIOS check (5c) needs it to say "it reached its shell" rather than "it ran 60 frames".
- **G6, debug values for personal builds** (C40–C42): `cpu` (`:25`), `cycles` (`:33`), `tty` (`:53`) and `ttySinceEXE` (`:57`), for the Tools pane and the debug drawer (5f); and trace recording, for which `PS1Console` is fixed to `NoTracer`.
Measured, not guessed, 2026-11-21, with a probe package linking `PS1Core` by path over the CPU-check image built in code: `PS1Console` powered on, ran 60 frames in 0.014 s, and refused 1,000 bytes with `biosSize(1000)`; `istation-run` booting a PS-EXE built in code on that image exited 3, "the EXE never started: the BIOS didn't reach its shell in 30 frames", which is the state `bootIsPending` must report.

**Core constraint(s).**
- **The clean room**: this is core code. Shipped code comes only from ProjectPSX, iStation's own code and public documentation; the source of a GPL emulator is never opened ([ADR 0013](../../../adrs/darwin/shipped-code-derives-only-from-permissive-references.md)). A session that has read one builds none of this.
- Business only: `ps1` imports the standard library and `r3000a`, nothing else.
- Hot paths stay concrete ([ADR 0015](../../../adrs/darwin/a-core-is-a-cpu-module-and-a-console-module.md) §4): the shell watch must not slow `runSlice()` once the shell is reached.
- Release builds carry no tools ([ADR 0016](../../../adrs/darwin/two-build-routines-and-a-fresh-start.md)): the debug values and any tracing console exist only under `#if PERSONAL_BUILD`, and the App Store build's console stays specialized to `NoTracer`.
- The interface stays narrow and serializable: values, never references to the machine.

**Seam + files.** Business, `ps1`: `PS1Console.swift` gains `boot(exe: PSEXE)`, `bootIsPending`, `reachedShell`, and under `PERSONAL_BUILD` a `debugSnapshot: PS1DebugSnapshot?` value (pc, 32 registers, hi, lo, sr, cause, epc, cycles, frame, tty); `PS1Machine.swift` keeps watching for 0x80030000 until it is first reached. Tests in `tests/business/ps1/`, building their BIOS images and EXEs in code with `SupportMIPS`.

**Reference.** The design: contract rows C10, C19, C40–C42, C49 and gaps G5, G6, G10 on the `Contract` board; the debug values the `Mac-ToolsConsole` and `Mac-PlayerDebug` boards show are a recorded full-state record from `istation-run`'s CPU-check trace. In-house: `istation-run`'s `run` (`lib/src/darwin/tools/istation-run/Sources/main.swift`) already drives `PS1Machine` with a tracer, and its exit 3 is the never-started state. ProjectPSX side-loads an EXE by patching SCPH-1001's LoadRunShell at 0xBFC06FF0; iStation watches the PC instead, which holds for any BIOS (`PS1Machine.swift:141–145`).

**Decisions made** (dated):
- 2026-11-21: each screen's gaps get interface items, track 6, and the screens are gated on them (the user's call).
- 2026-11-21: the design's Today parts are v0.1.0's (the user's call).

**Open calls:**
- [user] `PS1Console.name` is "PlayStation" (`PS1Console.swift:13`). The design never shows it and says PS1 and PS2 instead. Keep it, rename it to "PS1", or remove it before the v1.0.0 trademark check?
- [default: `reachedShell` watches for 0x80030000 from power-on until it is first reached, then stops watching, so the boot pays for it and play doesn't] The cost is one compare per instruction until the shell.
- [default: the debug values are one `Sendable` snapshot taken between frames, not live accessors] The narrow interface stays serializable.
- [default: trace recording in the app uses a personal-only console type generic over its tracer, beside `PS1Console`] Making `PS1Console` itself generic would leak into the App Store build's specialization.

**Guardrail(s).** Hermetic tests: an EXE given to `boot(exe:)` starts once a code-built BIOS jumps to 0x80030000, and `bootIsPending` stays true for an image that never does (as `istation-run`'s exit 3 shows); `reachedShell` flips once and stays; the snapshot's registers match `PS1Machine.cpu` after a known program. `ArchitectureTests` (`toolsArePersonalOnly`) keep the snapshot and tracing console out of App Store builds. The gate's instructions-per-second line doesn't fall (136 M/s on the CPU-check image, release, 2026-11-21).

**Acceptance criteria:**
- [ ] `PS1Console.boot(exe:)`, `bootIsPending` and `reachedShell` exist and are tested as above.
- [ ] Under `PERSONAL_BUILD`, `PS1Console` gives a debug snapshot, and a tracing console records TraceKit instruction and frame records the way `istation-run run` does.
- [ ] An App Store build compiles with neither; `swift test` and the strict build pass.

**Scope note.** v0.1.0, track 6. Unblocks 5c (the shell), 5d (playing a PS-EXE) and 5f (Tools). The picture (G1) is 6b's.
