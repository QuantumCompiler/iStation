# iStation

iStation is two native Apple apps with PlayStation emulators written in Swift: a macOS app (Apple Silicon) for PS1 and PS2, and an iOS app for PS1, both meant for Apple's App Stores. The PS1 emulator is a Swift port of [ProjectPSX](https://github.com/BluestormDNA/ProjectPSX) (MIT); the PS2 emulator will be a Swift port of [Play!](https://github.com/jpd002/Play-) (BSD). Each port is checked against more accurate emulators run as black boxes — their behaviour recorded, their code never read.

iStation ships no BIOS files or games: you import your own.

## Status

v0.0.1, re-envisioned on 2026-11-07. JIT is verified under the App Store routine, and the skeleton is in place: the packages `PS1Core` and `EmuKit`, and the macOS and iOS apps, each in two build routines (App Store and personal). Both apps open to an empty player; the PS1's R3000A and the BIOS boot come next. See [the roadmap](documentation/istation/assistant/ROADMAP.md).

## Build and run

Requires macOS 14 or later on Apple Silicon and Xcode 16 or later (Swift 6).

In Xcode, open `iStation.xcodeproj` at the root of the repository and pick a scheme: `macOS Personal` or `iOS Personal` to run and debug (⌘R; ⌘U runs every test from `macOS Personal`), `macOS App Store` or `iOS App Store` to archive. From Terminal:

```bash
cd src/istation
swift test                              # every module's tests, plus the architecture checks
./scripts/build-personal.sh macOS       # the personal routine (or iOS, for the Simulator)
./scripts/archive-appstore.sh macOS     # an App Store archive; signing and uploading are yours
```

## Licence

iStation's own code is MIT. Code ported from ProjectPSX keeps its MIT notice, and code from Play! keeps its BSD notices; each app lists them in its acknowledgements. The licence files arrive with Architecture item A2.

## Contributing

The contributor docs start at [documentation/CLAUDE.md](documentation/CLAUDE.md).
