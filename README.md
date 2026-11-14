# iStation

iStation is two native Apple apps with PlayStation emulators written in Swift: a macOS app (Apple Silicon) for PS1 and PS2, and an iOS app for PS1, both meant for Apple's App Stores. The PS1 emulator is a Swift port of [ProjectPSX](https://github.com/BluestormDNA/ProjectPSX) (MIT); the PS2 emulator will be a Swift port of [Play!](https://github.com/jpd002/Play-) (BSD). Each port is checked against more accurate emulators run as black boxes — their behaviour recorded, their code never read.

iStation ships no BIOS files or games: you import your own.

## Status

v0.0.1, re-envisioned on 2026-11-07. JIT is verified under the App Store routine, and the skeleton is in place: the packages `PS1Core` and `EmuKit`, and the macOS and iOS apps, each in two build routines (App Store and personal). Both apps open to an empty player; the PS1's R3000A and the BIOS boot come next. See [the roadmap](lib/documentation/assistant/darwin/ROADMAP.md).

## Build and run

Requires macOS 14 or later on Apple Silicon and Xcode 16 or later (Swift 6).

In Xcode, open `lib/src/darwin/iStation.xcodeproj` and pick a scheme: `macOS Personal` or `iOS Personal` to run and debug (⌘R; ⌘U runs every test from `macOS Personal`), `macOS App Store` or `iOS App Store` to archive. From Terminal:

```bash
cd lib/src/darwin
swift test                              # every module's tests, plus the architecture checks
./scripts/build-personal.sh macOS       # the personal routine, "iStation Personal" (or iOS, for the Simulator)
./scripts/archive-appstore.sh macOS     # an App Store archive; signing and uploading are yours
```

## Licence

iStation's own code is MIT ([LICENSE](LICENSE)). Code ported from ProjectPSX keeps its MIT notice, and code from Play! keeps its BSD notices; every source file names its licence in an SPDX header, and each app lists the notices it carries in its acknowledgements ([lib/src/darwin/apps/Acknowledgements.json](lib/src/darwin/apps/Acknowledgements.json)).

## Contributing

The contributor docs start at [lib/documentation/CLAUDE.md](lib/documentation/CLAUDE.md).
