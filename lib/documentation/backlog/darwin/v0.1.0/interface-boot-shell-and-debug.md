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
- The interface stays narrow and serializable: values, never references to the machine. ADR 0015 §5's five crossings are video frames, audio buffers, input state, save states and settings: `boot(exe:)` is given between frames as a setting is, and `bootIsPending` and `reachedShell` are plain values read between frames, as today's `isPoweredOn` and `frame` are. The debug snapshot and the tracing console are personal-build tools ([ADR 0016](../../../adrs/darwin/two-build-routines-and-a-fresh-start.md)), outside the App Store build's interface.

**Seam + files.** Business, `ps1`: `PS1Console.swift`'s `name` becomes "PS1" — today's player still shows it (`PlayerView.swift:21`, through `PlayerViewModel.consoleName`) until 5b replaces that player, so its doc comment stays — with `ProgramTests` and `PlayerViewModelTests` expecting "PS1". It gains `boot(exe: PSEXE)`, `bootIsPending`, `reachedShell`, and under `PERSONAL_BUILD` a `debugSnapshot: PS1DebugSnapshot?`, one `Sendable` value (pc, 32 registers, hi, lo, sr, cause, epc, cycles, frame, tty) taken between frames. `PS1Machine.swift` watches for 0x80030000 from power-on — today it watches only once `boot(_:)` is called or putchar is captured (`watchesPC`, `PS1Machine.swift:38–49, :145`) — until it is first reached, then stops, leaving the PC watch to putchar capture alone. Under `PERSONAL_BUILD`, a tracing console type beside `PS1Console`, generic over its tracer, with the same members, for 5f's recordings; `PS1Console` itself stays `NoTracer`. Tests in `tests/business/ps1/`, building their BIOS images and EXEs in code with `SupportMIPS`. The design: the `Contract` board's G6 change (`html/Contract.dc.html`) names `debugSnapshot`, one `Sendable` value taken between frames, and the personal-only tracing console beside `PS1Console`, and its Branding call drops `PS1Console.name` (answered 2026-11-22), in the same change.

**Reference.** The design: contract rows C10, C19, C40–C42, C49 and gaps G5, G6, G10 on the `Contract` board; the debug values the `Mac-ToolsConsole` and `Mac-PlayerDebug` boards show are a recorded full-state record from `istation-run`'s CPU-check trace. In-house: `istation-run`'s `run` (`lib/src/darwin/tools/istation-run/Sources/main.swift`) already drives `PS1Machine` with a tracer, and its exit 3 is the never-started state. ProjectPSX side-loads an EXE by patching SCPH-1001's LoadRunShell at 0xBFC06FF0; iStation watches the PC instead, which holds for any BIOS (`PS1Machine.swift:141–145`).

**Decisions made** (dated):
- 2026-11-21: each screen's gaps get interface items, track 6, and the screens are gated on them (the user's call).
- 2026-11-21: the design's Today parts are v0.1.0's (the user's call).
- 2026-11-22: `PS1Console.name` becomes "PS1", the design's wording, keeping Sony's trademark out of a value a screen could show (the user's call).
- 2026-11-22: `reachedShell` watches for 0x80030000 from power-on until it is first reached, then stops watching, so the boot pays one compare per instruction and play pays nothing (the default, confirmed by the user).
- 2026-11-22: the debug values are one `Sendable` snapshot taken between frames, not live accessors, so the narrow interface stays serializable (the default, confirmed by the user).
- 2026-11-22: trace recording in the app uses a personal-only console type, generic over its tracer, beside `PS1Console`; `PS1Console` stays fixed to `NoTracer`, so the App Store build's specialization is untouched (the default, confirmed by the user).

**Open calls:** none — all answered 2026-11-22.

**Guardrail(s).** Hermetic tests: an EXE given to `boot(exe:)` starts once a code-built BIOS jumps to 0x80030000, and `bootIsPending` stays true for an image that never does (as `istation-run`'s exit 3 shows); `reachedShell` flips once and stays; the snapshot's registers match `PS1Machine.cpu` after a known program. `ArchitectureTests` (`toolsArePersonalOnly`) keep the snapshot and tracing console out of App Store builds. The gate's instructions-per-second line doesn't fall (136 M/s on the CPU-check image, release, 2026-11-21).

**Acceptance criteria:**
- [ ] `PS1Console.name` is "PS1", and "PlayStation" appears nowhere under `lib/src/darwin/source/`, `lib/src/darwin/apps/` or `lib/src/darwin/tests/` (on 2026-11-22 it was only `PS1Console.swift:13` and the two tests that expect it).
- [ ] `PS1Console.boot(exe:)`, `bootIsPending` and `reachedShell` exist and are tested as above.
- [ ] Under `PERSONAL_BUILD`, `PS1Console` gives a debug snapshot, and a tracing console records TraceKit instruction and frame records the way `istation-run run` does.
- [ ] An App Store build compiles with neither; `swift test` and the strict build pass.

**Scope note.** v0.1.0, track 6. Unblocks 5c (the shell), 5d (playing a PS-EXE) and 5f (Tools). The picture (G1) is 6b's.
