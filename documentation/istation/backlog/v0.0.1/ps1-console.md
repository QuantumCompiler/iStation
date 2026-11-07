# The PS1 console — memory map, interrupts, timing, minimal DMA and timers, device stubs

**What / why.** The R3000A (2c) needs a PS1 around it before a BIOS can run: the memory map and its timing, the interrupt controller, the scheduler that drives every device (SwanStation's timing events), and enough of DMA, the timers and the other devices for OpenBIOS to boot. This item ports those pieces from SwanStation into one console module and stubs the rest. Sizes, counted 2026-11-07: `bus.cpp` 1,875 lines, `timing_event.cpp` 581, `dma.cpp` 783, `timers.cpp` 499, `interrupt_controller.cpp` 133.

It is one module because the reference's devices form one cycle: its include graph joins all 13 subsystems into one strongly connected group (measured 2026-11-07), and SwiftPM forbids cycles between modules. A device is carved into its own module later, only once the trace harness guards it ([ADR 0012](../../adrs/cores-shape-and-hot-paths.md) §3).

**Core constraint(s).** Ported code from its reference only, with SPDX and credit headers; GPL-3.0; never imported by shared infrastructure (⚠ in CLAUDE.md; [ADR 0011](../../adrs/each-module-carries-its-licence.md)). Hot paths use concrete types: the bus is a final type the R3000A is specialized over; guest memory is an unsafe buffer bounds-checked once at the bus ([ADR 0012](../../adrs/cores-shape-and-hot-paths.md) §4). No Sony files: tests build their memory images in code. The layer law, as for 2c.

**Seam + files.**
- New module, Business layer: `Module(.business, "PS1", uses: ["BusinessR3000A", "DataTracing"], licence: .gpl3Only),` — target `BusinessPS1`.
- `src/istation/source/business/ps1/`:
  - `Console.swift` — owns RAM, the BIOS image, the devices and the run loop (run the CPU until the next timing event, then dispatch it).
  - `Bus.swift` — the memory map from `bus.cpp`: 2 MB of RAM mirrored four times, the 1 KB scratchpad at `0x1F800000`, the 512 KB BIOS at `0x1FC00000` (read-only), the I/O ports at `0x1F801000`, expansion regions 1 and 2, the memory-control and cache-control registers; KUSEG/KSEG0/KSEG1 masking; access timing from the memory-control delays; bus errors where SwanStation raises them.
  - `InterruptController.swift`, `TimingEvents.swift`, `Timers.swift` — ported in full.
  - `DMA.swift` — the registers and the channels OpenBIOS uses (which, the reference trace of 2b shows).
  - `DeviceStubs.swift` — GPU, SPU, CD-ROM, MDEC and SIO registers answering as SwanStation's devices do at power-on, and the GPU's vertical-blank interrupt raised on SwanStation's NTSC schedule; replaced device by device from v0.1.0.
- `src/istation/tests/business/ps1/`: mirrors and segment masking, the scratchpad, the BIOS read-only, I/O access widths, interrupt status and mask, timing-event ordering, timer counting, DMA's ordering-table clear, the VBlank cadence.

**Reference.** SwanStation `src/core/bus.cpp`, `timing_event.cpp`, `interrupt_controller.cpp`, `dma.cpp`, `timers.cpp`, and the power-on register values in `gpu.cpp`, `spu.cpp`, `cdrom.cpp`, `mdec.cpp` and `sio.cpp`, at the pinned commit (2b).

**Decisions made** (dated):
- 2026-11-07: one console module, devices carved out only behind the trace harness (ADR 0012, the re-vision's default, taken).
- 2026-11-07: DMA and timers only as far as OpenBIOS needs; their full behavior and ps1-tests' `access-time` and `io-access-bitwidth` move to v0.1.0 (the user's call).

**Open calls:**
- [default: the reference trace of 2b decides which device registers OpenBIOS touches; a stub covers exactly those, answering SwanStation's power-on values, and anything else reads open bus as SwanStation does] How much each stub does.
- [default: NTSC timing only; PAL waits for the first picture] Video standard.

**Guardrail(s).** The tests above, plus a trace check: the console runs OpenBIOS (from 2e's fixture once it exists, or an image built in the test until then) for its first 1,000,000 instructions and matches 2b's checkpoints — the first divergence names the instruction.

**Acceptance criteria:**
- [ ] `BusinessPS1` wires `BusinessR3000A` to a concrete PS1 bus and runs it under its timing events.
- [ ] The memory map, interrupt controller, timing events and timers behave as SwanStation's, by the tests above.
- [ ] Every register OpenBIOS touches in 2b's trace answers as SwanStation does.
- [ ] Every file carries its SPDX and credit headers; the licence and layer checks pass.

**Scope note.** v0.0.1, track 2; gated on 2c. 2e boots OpenBIOS and PS-EXEs on it. Out of scope: the GPU's drawing, the SPU's sound, the CD-ROM's commands, MDEC, pads and memory cards (v0.1.0 and v0.2.0).
