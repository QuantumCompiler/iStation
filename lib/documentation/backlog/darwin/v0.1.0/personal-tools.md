# The personal build's Tools pane and debug drawer

**What / why.** The SPEC's fifth surface is the personal build's tools: CPU and VRAM viewers and trace recording, compiled out of every App Store build. The design puts them in a Tools pane (⌘7, personal builds only) and a debug drawer in the player (⌥⌘D):
- **Console:** the registers, PC, HI, LO, SR, CAUSE, EPC, cycles and instructions per second.
- **TTY:** what the console printed.
- **Trace:** a form that mirrors `istation-run run`'s options and shows the same run as a Terminal command. Recording is a job; Stop deletes the unfinished files.
- **Compare:** two traces, and their first divergence in TraceKit's own words.
- **VRAM:** 5g's, after the picture.

Today these exist only as the command-line tool. Recorded 2026-11-21 from `istation-run` (release) over images built in code, and used as the design's canned data:
- "[istation-run] 60 frames, 1698623 instructions, 33972213 CPU cycles, 33972249 system cycles, 0.012 s emulating, 136 M instructions/s"
- a two-frame instruction trace with full state every 1,000 records: 1,424,857 bytes
- `diff` of two different images: "first divergence at record 0 of 56689 and 56625: word", exit 1
- `diff` of a trace with itself: "identical: 60 records", exit 0
- the CPU-check image's TTY: 0 bytes.

**Core constraint(s).**
- Release builds carry no tools ([ADR 0016](../../../adrs/darwin/two-build-routines-and-a-fresh-start.md)): every view here sits in the module's `Debug/` under `#if PERSONAL_BUILD`, and TraceKit (`DataTracing`) is imported only there (`toolsArePersonalOnly`).
- Nothing starts a process ([ADR 0022](../../../adrs/darwin/nothing-starts-a-process-or-loads-code-at-runtime.md)): the app never runs `istation-run`; it shows the command to copy, and records traces in-process through 6a's tracing console.
- Never a real BIOS or game in tests: programs and images are built in code.

**Seam + files.**
- Presentation, new module `tools`, everything under `Debug/` and `#if PERSONAL_BUILD`: `ToolsViewModel` (tabs, snapshot from 6a, TTY), `TraceRecorderViewModel` (form, the equivalent `istation-run` command, the job through `JobSheet`), `TraceCompareViewModel` (`TraceDiff.firstDivergence`), and views with previews per state.
- Presentation `player`: the debug drawer as the player's `.inspector`, personal builds only.
- Settings › Personal (5e): the trace folder, the drawer's default and keeping the BIOS's putchar output.
- Tests: `tests/presentation/tools/` over fakes and small traces written in a `Sandbox`.

**Reference.** The design: boards `Mac-ToolsConsole`, `Mac-ToolsTty`, `Mac-ToolsTraceRunning`, `Mac-ToolsTraceDone`, `Mac-ToolsCompare`, `Mac-PlayerDebug`, `Mac-TodayTools` (the commands before 6a) and `Mac-SettingsPersonal`; contract rows C40–C44 and C46. In-house: `istation-run`'s options and output (`lib/src/darwin/tools/istation-run/README.md`), TraceKit's formats ([reference/trace-formats.md](../../../reference/darwin/trace-formats.md)).

**Decisions made** (dated):
- 2026-11-21: the design's Today parts are v0.1.0's, the Tools pane among them (the user's call).
- 2026-11-21: each screen's gaps get interface items, track 6, and the screens are gated on them (the user's call).

**Open calls:**
- [default: a stopped recording deletes its unfinished files and says why] TraceKit's writer can't resume a trace; the job says "A trace can't be resumed".
- [default: traces go to `~/Traces` or a folder chosen in Settings › Personal] The personal macOS routine isn't sandboxed (`apps/macos/Personal.entitlements` has no App Sandbox key), so a plain path works there.
- [default: Compare shows TraceDiff's result in the words `istation-run diff` prints, records quoted as TraceKit formats them]
- [default: the Console tab's values come from 6a's snapshot between frames, refreshed while paused or on each frame when running]

**Guardrail(s).** `ArchitectureTests` (`toolsArePersonalOnly`) fail on any of this outside the guard. View-model tests: the form builds the same command `istation-run` takes; a recording of a code-built image produces TraceKit records; Stop deletes the files; Compare on two small traces built in the test reports the expected record and fields.

**Acceptance criteria:**
- [ ] In a personal build, Tools (⌘7) shows Console, TTY, Trace and Compare matching their boards, and the player's debug drawer opens with ⌥⌘D.
- [ ] Recording 60 frames of a code-built image writes traces that `istation-run diff` reads as identical to its own run of the same image.
- [ ] An App Store build has no Tools, no drawer and no TraceKit, and its checks pass.
- [ ] `swift test` and the strict build pass.

**Scope note.** v0.1.0, track 5, gated on 5b and 6a. The VRAM tab is 5g's.
