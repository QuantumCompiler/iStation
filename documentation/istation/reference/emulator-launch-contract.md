# The emulator launch contract

How iStation finds and starts each installed emulator — for a console without a native core yet (since 2026-11-07, iStation ports its own cores: [ADR 0010](../adrs/cores-are-ports-of-open-references.md)). iStation passes only flags the emulator's own argument parser reads, checked against each project's source on 2026-10-25 (the user's design), and learns that a session has ended only from the process exiting ([ADR 0010](../adrs/cores-are-ports-of-open-references.md) §5). Implemented in `src/istation/source/data/emulators/LaunchContract.swift` (the flags) and `src/istation/source/business/launching/GameLauncher.swift` (the command).

## Which emulator runs which console

| Console | Emulator | Bundle identifier | App names looked for |
|---|---|---|---|
| PS1 | DuckStation | `com.github.stenzek.duckstation` | `DuckStation.app` |
| PS2 | PCSX2 | `net.pcsx2.pcsx2` | `PCSX2.app` |
| PS3 | RPCS3 | `net.rpcs3.rpcs3` | `RPCS3.app`, `rpcs3.app` |

An emulator's app is the one chosen in Settings; otherwise the first of its app names found in /Applications, then ~/Applications; otherwise wherever Launch Services knows its bundle identifier. PCSX-Redux replaces DuckStation as the recommended PS1 emulator in v1.0.0, once its flags are checked against its source.

## The command

The binary is the bundle's executable (`CFBundleExecutable`), else the first file in `Contents/MacOS`:

| Emulator | Binary | Arguments iStation passes | Source file |
|---|---|---|---|
| DuckStation | `DuckStation.app/Contents/MacOS/DuckStation` | `-batch [-fullscreen] [-fastboot] -- <path>` | `src/duckstation-qt/qthost.cpp` |
| PCSX2 | `PCSX2.app/Contents/MacOS/PCSX2` | `-batch [-fullscreen] [-fastboot] -- <path>` | `pcsx2-qt/QtHost.cpp` |
| RPCS3 | `RPCS3.app/Contents/MacOS/rpcs3` | `--no-gui [--fullscreen] <path or %RPCS3_GAMEID%:<TITLE_ID>>` | `rpcs3/rpcs3.cpp`, `Emu/System.h` |

- `-batch` makes DuckStation and PCSX2 quit when the game shuts down, so the process exit marks the end of a session. Whether RPCS3 with `--no-gui` exits with its game is unverified (item 1a).
- `--` ends option parsing, so a path that starts with `-` still boots.
- `-fullscreen` / `--fullscreen` follow Settings → "Start games in fullscreen"; `-fastboot` follows "Skip BIOS intro (PS1 / PS2)". Both default on.
- `<path>` is the game's boot target: a disc image, a `.cue`, an `.m3u` playlist, or a PS3 disc folder. The `%RPCS3_GAMEID%:` prefix boots a PSN title installed in RPCS3's `dev_hdd0/game` by its title ID.
- Only one game runs at a time. When the process exits, iStation adds the wall-clock session length to the game's play time and comes back to the front. The exit status is not interpreted.

## RPCS3's installed games

RPCS3 keeps its virtual HDD in `~/Library/Application Support/rpcs3/dev_hdd0` on macOS. iStation lists the titles in `dev_hdd0/game/<TITLE_ID>/` whose `PARAM.SFO` has `CATEGORY = HG` (patches, DLC and save data are skipped), when Settings → "Include games installed in RPCS3" is on.

## Changing this contract

A flag changes only against the emulator's own argument parser, with this document, `LaunchContractTests` and, where the command shape changes, `GameLauncherTests` updated in the same change. Per-game flags (PCSX2 `-gamecfg`, RPCS3 `--config`) are v0.3.0's.
