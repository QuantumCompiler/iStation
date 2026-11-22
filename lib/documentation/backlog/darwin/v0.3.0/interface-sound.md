# The narrow interface: sound

**What / why.** **Split first.** Gap G3 of the design: the console's audio reaches the speakers (contract row C26). Audio buffers are one of ADR 0015 §5's five crossings. Today the SPU is a stub (`source/business/ps1/DeviceStubs.swift:39`). ProjectPSX's SPU (`Devices/SPU/SPU.cs`, `Voice.cs`) mixes its voices and CD audio and hands the host a byte buffer through `IHostWindow.Play(byte[] samples)` (`SPU.cs:854`, `Host/IHostWindow.cs`). Two ROADMAP lines own the work: v0.2.0's "The GTE, SPU and MDEC" (the SPU's port) and v0.3.0's "Audio through Core Audio / AVAudioEngine" (output). Split before building:
- **The SPU**: its own document under v0.2.0's line, ported from ProjectPSX.
- **This document**: the interface member that drains the SPU's samples, and the app's AVAudioEngine output with its volume and muting.

**Core constraint(s).**
- **The clean room**: the SPU comes only from ProjectPSX, iStation's own code and psx-spx; an oracle's audio may be recorded and compared, never read ([ADR 0013](../../../adrs/darwin/shipped-code-derives-only-from-permissive-references.md)).
- Business imports no Apple framework: the core hands samples as plain values; AVAudioEngine is the app's.
- Per-sample code is concrete and allocation-free ([ADR 0015](../../../adrs/darwin/a-core-is-a-cpu-module-and-a-console-module.md) §4): the drain writes into a buffer the caller owns.

**Seam + files.**
- Business, `ps1`: `PS1Console.drainAudio(into:)` writes the 44.1 kHz stereo 16-bit samples made since the last call and returns their count.
- Business `session` (5b): drains after each frame into a ring buffer.
- The app side: an AVAudioEngine source node reading the ring buffer, with volume and mute.
- Tests: `tests/business/ps1/` (a code-built program keys a voice on; the drained samples are not silent and have the expected count per frame), `tests/business/session/` (the ring buffer neither overruns nor underruns at 60 frames a second).

**Reference.** The design: contract row C26 and gap G3 on the `Contract` board. ProjectPSX: the files above. Public documentation: psx-spx's SPU chapter. In-house: TraceKit's frame records carry an `audioChecksum`, written as 0 today (`tools/istation-run/Sources/main.swift`), ready for oracle comparison once samples exist.

**Decisions made** (dated):
- 2026-11-21: each screen's gaps get interface items, track 6, with core internals left as open calls, and the screens are gated on them (the user's call).

**Open calls:**
- [default: 44,100 Hz, two channels, 16-bit, the SPU's own rate, with no resampling in the core]
- [default: the split happens before anyone builds: the SPU's document is written under v0.2.0's line first]

**Guardrail(s).** The tests above; frame records' audio checksums compared with the oracle's recorded ones once the SPU is ported.

**Acceptance criteria:**
- [ ] The split's documents exist, and the SPU is built.
- [ ] `drainAudio(into:)` gives samples per frame; the app plays them through AVAudioEngine.
- [ ] `swift test` and the strict build pass.

**Scope note.** v0.3.0, track 6, split first. Unblocks 5m.
