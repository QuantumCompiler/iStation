# iStation

iStation is a personal, native app for Apple platforms (Swift + SwiftUI; macOS 14+ on Apple Silicon first) that plays PS1 and PS2 games in its own Swift emulators, behind one game library and one Play button. Each emulator is a Swift port of an open-source reference — PS1 from [SwanStation](https://github.com/libretro/swanstation), then PS2 from [PCSX2](https://github.com/PCSX2/pcsx2) — checked against the reference's own build by trace. iStation finds your games, works out which console each belongs to by reading the disc itself, and keeps your play time. Until a console has its native emulator, iStation launches your installed DuckStation, PCSX2 or RPCS3 for it instead.

iStation ships no BIOS files, PS3 system software or games: you supply your own.

## Build and run

Requires macOS 14 or later and Xcode 16 or later (Swift 6). Until the PS1 core plays games, playing anything needs DuckStation, PCSX2 and/or RPCS3 installed as `.app` bundles.

In Xcode, open `iStation.xcodeproj` at the root of the repository: the `iStation` scheme runs the app (⌘R) and every test, the architecture checks included (⌘U).

From Terminal:

```bash
cd src/istation
swift run iStation            # build and run
swift test                    # every module's tests, plus the architecture checks
./scripts/build-app.sh        # makes build/iStation.app, ad-hoc signed, for /Applications
```

## Status

v0.0.1. Re-envisioned on 2026-11-07: the library, disc identification and launching of installed emulators are in place; v0.0.1 now builds the first native piece — the PS1's R3000A CPU booting the open-source OpenBIOS, its trace identical to SwanStation's. See [the roadmap](documentation/istation/assistant/ROADMAP.md).

## Licence

GPLv3 as a whole: the emulator cores are derivative works of their GPLv3 references and keep their credits; the shared infrastructure is GPL-2.0-or-later. The licence files arrive with Architecture item A1.

## Contributing

The contributor docs start at [documentation/CLAUDE.md](documentation/CLAUDE.md).
