# iStation

iStation is a personal, native macOS app (Swift + SwiftUI, macOS 14+) that gives DuckStation, PCSX2 and RPCS3 one shared game library and one Play button. Each emulator still does the emulating; iStation finds your games, works out which console each belongs to by reading the disc itself, and launches the right emulator with the right flags — then comes back to the front when the game closes, and adds the session to your play time.

iStation ships no BIOS files, PS3 system software or games: you supply your own, and your own installed emulators.

## Build and run

Requires macOS 14 or later, Xcode 16 or later (Swift 6), and DuckStation, PCSX2 and/or RPCS3 installed as `.app` bundles.

In Xcode, open `iStation.xcodeproj` at the root of the repository: the `iStation` scheme runs the app (⌘R) and every test, the architecture checks included (⌘U).

From Terminal:

```bash
cd src/istation
swift run iStation            # build and run
swift test                    # every module's tests, plus the architecture checks
./scripts/build-app.sh        # makes build/iStation.app, ad-hoc signed, for /Applications
```

## Status

v0.0.1, the first build. The library, disc identification and launching are in place; booting a real game from each console is the open gate. See [the roadmap](documentation/istation/assistant/ROADMAP.md).

## Contributing

The contributor docs start at [documentation/CLAUDE.md](documentation/CLAUDE.md).
