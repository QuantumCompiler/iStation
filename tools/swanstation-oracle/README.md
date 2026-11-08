# swanstation-oracle — SwanStation, unmodified, recorded from outside

The more accurate PS1 emulator the Swift core is checked against, [SwanStation](https://github.com/libretro/swanstation) (GPLv3), pinned at **`631f0fb31b809e0f889d7c551fe695788e39c1d3`**, built **unmodified** as a libretro core and run by a small frontend of iStation's own (v0.0.1 item 3d). **Its source is never opened, read or copied** ([ADR 0013](../../documentation/istation/adrs/shipped-code-derives-only-from-permissive-references.md)): `build.sh` clones and builds it without anyone looking inside, and nothing records more than what any libretro frontend sees — guest RAM after each frame. Nothing here ships; the clone and every build live in the git-ignored `.build/`, and no one opens `.build/swanstation` or `.build/build`.

- **`frontend.c`** — iStation's own (MIT), written only against libretro's public API: its `libretro.h` comes from [libretro-common](https://github.com/libretro/libretro-common) (MIT) at **`d9597c359a5ca8399a4e244f816e7e975a92a2aa`**, never from SwanStation's tree. It loads the core, logs every option the core declares and asks for, runs a number of frames headless, and writes a frame record of 3c's format after each ([reference/trace-formats.md](../../documentation/istation/reference/trace-formats.md)): the frame number and the FNV-1a 64 checksum of the 2 MB of guest RAM (the picture and sound checksums are 0 until v0.1.0 and v0.2.0 define them).
- **`build.sh`** — clones SwanStation at the pin into `.build/swanstation` and builds its libretro core into `.build/build` (`cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES=arm64`, target `swanstation_libretro`; no submodules; about 10 seconds), fetches `libretro.h` into `.build/include`, and compiles the frontend into `.build/oracle`. The core's build output goes to `.build/swanstation-build.log`, not the terminal: compiler messages can quote its source, so a session that writes core code never opens it. Its configure step writes a git-ignored `version.h` into the clone, which is the build's own doing, not an edit. Needs Xcode's command-line tools, `git`, `curl`, CMake and Ninja (`brew install cmake ninja`).

## Its options

The frontend learns the core's options from the requests it makes, never from its source. An option offering `Interpreter` or `Software` is answered with it, every other with its first value — and OpenBIOS is never chosen. Memory card options are answered `None`, and no controller is plugged into either port (`retro_set_controller_port_device`, `RETRO_DEVICE_NONE`): the Swift console it is compared with has neither, and a pad or card answering the BIOS would change guest RAM. On 2026-11-07 that gave `swanstation_CPU_ExecutionMode = Interpreter`, `swanstation_GPU_Renderer = Software` and `swanstation_MemoryCards_Card1Type = None`; the core asks for its NTSC-U BIOS as `scph5501.bin`, so the frontend links the BIOS it is given under every `.bin` name the core asks for, in a temporary system folder holding nothing else. The full list is in each run's `--log`.

## Using it

```sh
./build.sh
.build/oracle .build/build/swanstation_libretro.dylib --bios <image> [--exe <file>] [--frames <n>] [--frame-trace <trace>] [--log <file>]
```

`../istation-run/.build/release/istation-run diff <its trace> <the Swift console's> --min-records <frames>` compares its frame trace with the Swift console's; `--min-records` keeps a run cut short from reading as agreement. The frontend refuses an unknown flag and a bad number (exit 2), and a BIOS that isn't a 512 KB file — the core would run on without it — and fails loudly when the core refuses to start or a file can't be written (exit 1). Its temporary system folder is removed on every exit and on Ctrl-C or a kill. On the CPU-check image (`../istation-run/.build/release/istation-run cpu-check-image`, R3000A code built in code, never Sony's) the two are identical over 5 frames.

## Your runs (with your own BIOS)

A BIOS dump is yours to supply and to run; it is linked by path and never copied. With `BIOS=/path/to/your/bios.bin`:

1. **The boot**, per frame, long enough to reach the shell and sit there (3g's measure: the frame after which RAM stops changing in the boot's pattern for 60 frames):
   `.build/oracle .build/build/swanstation_libretro.dylib --bios "$BIOS" --frames 1200 --frame-trace /tmp/swanstation-boot-frames.trace --log /tmp/swanstation-boot.log`
2. **ps1-tests' `cop` and `code-in-io`**, after `../ps1-tests/fetch.sh`:
   `.build/oracle .build/build/swanstation_libretro.dylib --bios "$BIOS" --exe ../ps1-tests/.build/tests/cpu/cop/cop.exe --frames 600 --log /tmp/swanstation-cop.log`
   (and the same for `code-in-io`). The frontend could hear a program's TTY only through libretro's log, and with images built in code the core passes none to it — not the BIOS's putchar, not expansion 2's — at any log level: the oracle's known gap for 3d's guardrail. The run shows whether a real BIOS changes that; `../gate/run.sh` counts the `psx.log` lines the log holds.

(`fetch.sh` lists the EXEs' paths inside the release; adjust the paths above if they differ.)
