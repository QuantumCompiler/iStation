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
- Nothing starts a process ([ADR 0022](../../../adrs/darwin/nothing-starts-a-process-or-loads-code-at-runtime.md)): the app never runs `istation-run`; it shows the command to copy, and records traces in-process through 6a's tracing console, `PS1TracingConsole`.
- Never a real BIOS or game in tests: programs and images are built in code.
- Nothing in the package reaches the real home or Application Support folders (`noRealHome`): the macOS app target resolves the default trace folder in its own data folder and hands `tools` the URL; another folder comes only through the file picker.
- The rule's wording follows the decision: a record superseding [ADR 0019](../../../adrs/darwin/tests-live-in-the-layer-of-what-they-test.md) restates its §6 — the apps' targets reach the user's folders through the file picker and their own containers, and the unsandboxed macOS personal build also through its own Application Support folder, `local.istation.macos.personal` (decided 2026-11-22) — and ADR 0019's Status line, the ADR index, CLAUDE.md's ⚠ "Tests and previews never touch the real home folder" Rule and its "Development runs on the personal channel" line on the personal build's "own container" say so, in this item's change.

**Seam + files.**
- Presentation, new module `tools`, everything under `Debug/` and `#if PERSONAL_BUILD`: `ToolsViewModel` (tabs, the `PS1DebugSnapshot` that 6a's `debugSnapshot` gives, TTY), `TraceRecorderViewModel` (form, the equivalent `istation-run` command, the job through `JobSheet`), `TraceCompareViewModel` (`TraceDiff.firstDivergence`), and views with previews per state.
- Presentation `player`: the debug drawer as the player's `.inspector`, personal builds only.
- Presentation `library` (5d's): the sidebar's Tools place (⌘7), personal builds only, under the "Personal build" heading the design draws — `LibraryPlace` gains it and its section under `#if PERSONAL_BUILD`, its pane handed to `LibraryView` through a view builder as the BIOS pane is (so `library` doesn't import `tools`), and the View menu's ⌘7 through `LibraryMenuItem.place`. 5d left it out: there is nothing to show in it before this item.
- Settings › Personal (5e): the trace folder (the app's own `Traces` folder by default, another chosen through the file picker and kept by bookmark), the drawer's default and keeping the BIOS's putchar output.
- The design: every `~/Traces` changes to the app's own folder in the same change, as the design's CLAUDE.md asks — in `html/main.html`, the Settings › Personal row (gaining Show in Finder beside Choose…), the Trace form's folder and its equivalent command (`T.folder`, `T.command`), the recording job's subtitle, both Compare pickers' `where`, and the Today board's Terminal commands; in `html/Processes.dc.html`, the Traces row, and its container row, which says the unsandboxed personal build keeps its data in its own Application Support folder rather than a sandbox container. Paths in commands are double-quoted, written `"$HOME/Library/Application Support/local.istation.macos.personal/Traces/…"` (and `"$HOME/…"` for the BIOS) when they lie under the home folder, never a quoted `~`, which a shell doesn't expand.
- Tests: `tests/presentation/tools/` over fakes and small traces written in a `Sandbox`.

**Reference.** The design: boards `Mac-ToolsConsole`, `Mac-ToolsTty`, `Mac-ToolsTraceRunning`, `Mac-ToolsTraceDone`, `Mac-ToolsCompare`, `Mac-PlayerDebug`, `Mac-TodayTools` (the commands before 6a) and `Mac-SettingsPersonal`; contract rows C40–C44 and C46. In-house: `istation-run`'s options and output (`lib/src/darwin/tools/istation-run/README.md`), TraceKit's formats ([reference/trace-formats.md](../../../reference/darwin/trace-formats.md)).

**Decisions made** (dated):
- 2026-11-21: the design's Today parts are v0.1.0's, the Tools pane among them (the user's call).
- 2026-11-21: each screen's gaps get interface items, track 6, and the screens are gated on them (the user's call).
- 2026-11-22: a stopped recording deletes its unfinished files and says why — TraceKit's writer can't resume a trace, and the job says "A trace can't be resumed" (the default, confirmed by the user).
- 2026-11-22: traces go to the personal build's own data folder, `Traces` in its Application Support folder (`local.istation.macos.personal`), with Show in Finder, unless Settings › Personal picks another folder through the file picker, kept by bookmark. The default `~/Traces` was confirmed first, then replaced once it was seen to break CLAUDE.md's ⚠ "Tests and previews never touch the real home folder" (the apps reach the user's folders only through the file picker and their own containers) (the user's call).
- 2026-11-22: Compare shows TraceDiff's result in the words `istation-run diff` prints, records quoted as TraceKit formats them (the default, confirmed by the user).
- 2026-11-22: the Console tab's values come from 6a's snapshot between frames, refreshed while paused or on each frame when running (the default, confirmed by the user).
- 2026-11-22: the design's changes land in its local mirror, pass its checks and are published to the canvas as this item lands, keeping the two identical (the user's call, before the group run).
- 2026-11-22: each screen is checked against its board by rendering its previews to images and comparing them with the board in the built-in browser; no app is launched for the check (the user's call, before the group run).
- 2026-11-22: the Console tab's and the drawer's instructions per second, and Settings › Personal's BIOS putchar output, come from the personal build's session console: in personal builds 5b's `ConsoleSession` runs a `PS1TracingConsole` with an instruction-counting tracer — the way `istation-run` counts with its `Counter` — powered on with `capturesBIOSPutchar` as Settings › Personal says (from the next power-on); the App Store build's session runs `PS1Console`, and 6a's interface doesn't grow. A recording runs its own `PS1TracingConsole` with TraceKit's tracer, apart from the player's (raised by 6a's review; the conservative choice, made in the group run without the user and left for the user's veto).

**Open calls:** none — all answered 2026-11-22.

**Guardrail(s).** `ArchitectureTests` (`toolsArePersonalOnly`) fail on any of this outside the guard. View-model tests: the form builds the same command `istation-run` takes, every path double-quoted, written from `$HOME` when it lies under the home folder URL the app target hands in, never a quoted `~`; a recording of a code-built image produces TraceKit records; Stop deletes the files; Compare on two small traces built in the test reports the expected record and fields.

**Acceptance criteria:**
- [ ] In a personal build, Tools (⌘7) shows Console, TTY, Trace and Compare matching their boards, and the player's debug drawer opens with ⌥⌘D.
- [ ] Recording 60 frames of a code-built image writes traces that `istation-run diff` reads as identical to its own run of the same image.
- [ ] Traces are written to the app's own `Traces` folder by default (Show in Finder opens it), or to a folder chosen in Settings › Personal through the file picker and kept by bookmark; the design names no `~/Traces`.
- [ ] The record superseding ADR 0019 allows the unsandboxed personal build's own Application Support folder; ADR 0019's Status, the index and CLAUDE.md say so.
- [ ] An App Store build has no Tools, no drawer and no TraceKit, and its checks pass.
- [ ] `swift test` and the strict build pass.

**Scope note.** v0.1.0, track 5, gated on 5b and 6a. The VRAM tab is 5g's.
