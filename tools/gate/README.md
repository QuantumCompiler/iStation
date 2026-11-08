# gate — v0.0.1's gate, the user's run

One command for every run v0.0.1 still needs from your BIOS (items 3d and 3g): `run.sh` boots it on the Swift console (`../istation-run`), ProjectPSX's traced build (`../projectpsx-trace`) and SwanStation (`../swanstation-oracle`), diffs their traces with TraceKit, runs ps1-tests' four CPU tests (`access-time`, `code-in-io`, `cop`, `io-access-bitwidth`) on each, compares every TTY with the test's `psx.log` — recorded on a real PS1 — and writes `report.md`. Nothing here ships, and the BIOS is passed by path, never copied; the output goes to a temporary folder.

## Your run

```sh
tools/projectpsx-trace/build.sh
tools/swanstation-oracle/build.sh
tools/ps1-tests/fetch.sh
tools/gate/run.sh /path/to/your/bios.bin              # add --scph1001 if it is SCPH-1001's; --out <new folder> to choose where
```

- **The boot**: 1,200 frames (20 seconds of console time) per frame on all three, and the first 60 per instruction on the Swift console and ProjectPSX — those two traces take about 1.1 GB together. `FRAMES`, `TRACE_FRAMES` and `TEST_FRAMES` change the lengths.
- **The tests**: 600 frames each, each program's TTY from its entry point on — the BIOS's own messages left out — against its `psx.log`. ProjectPSX runs them only with `--scph1001`: it side-loads an EXE by patching that BIOS, which is other code in any other. SwanStation could be heard only through libretro's log, which carried no TTY with images built in code; the report counts how many of `psx.log`'s lines its log holds with yours — a count, which can't tell a missing TTY from a different one. Both TTYs are compared as text: carriage returns, blank lines before the first line and a missing last newline don't count. An EXE that never starts — the BIOS not reaching its shell — is a failed run, not output.
- **A tool that fails** — exits non-zero, or stops partway — is listed at the top of the report, with the file holding its output, and the gate goes on; a trace cut short never reads as agreement.
- **The report** (`report.md`, printed at the end): the BIOS's size and hash, never its name; the Swift console's instructions and instructions per second for the boot (the emulation's time alone); ProjectPSX's cycles and time and SwanStation's time; the trace sizes; how often SwanStation's RAM changes and where it last does, and how many frames the Swift console matches; the first divergence of each diff; and each test's TTY against `psx.log`. Beside it, `frames.tsv` holds every frame's RAM checksum on all three, to find the boot's end (`-` past a trace's end, `?` unreadable; `frames.err` says why). Send both back (they are small), and the agent records them in the backlog documents and MILESTONES.

What the gate asks of the report (3g's guardrail): every frame up to the boot's end matches SwanStation's; every test's output matches; every per-instruction divergence from ProjectPSX is fixed or listed with psx-spx's evidence.
