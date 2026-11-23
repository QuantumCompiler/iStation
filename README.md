# iStation

iStation is two native Apple apps with PlayStation emulators written in Swift: a macOS app (Apple Silicon) for PS1 and PS2, and an iOS app for PS1, both meant for Apple's App Stores. The PS1 emulator is a Swift port of [ProjectPSX](https://github.com/BluestormDNA/ProjectPSX) (MIT); the PS2 emulator will be a Swift port of [Play!](https://github.com/jpd002/Play-) (BSD). Each port is checked against more accurate emulators run as black boxes — their behaviour recorded, their code never read.

iStation ships no BIOS files or games: you import your own.

## Status

v0.1.0, the first picture, is in progress; [v0.0.1](https://github.com/QuantumCompiler/iStation/releases/tag/v0.0.1) is released. JIT is verified under the App Store routine, and the macOS and iOS apps build in two routines (App Store and personal) over one Swift package, whose library products are `PS1Core`, `EmuKit` and `TraceKit` (personal builds only). `PS1Core` holds the R3000A interpreter and the PS1 console around it, ported from ProjectPSX: run from the command line (`lib/src/darwin/tools/istation-run`), it boots the user's 23 BIOS images to the shell, passes ps1-tests' CPU tests up to known gaps and agrees with ProjectPSX instruction by instruction. The macOS app opens on Welcome: it checks your own BIOS and keeps it by a bookmark without copying it. Then it opens on your library of games: add disc images and PS-EXE programs, a few files or a whole folder at a time, search, rename and remove them, and find a file that has moved, all read where you keep them. Disc images are listed but don't play yet; a PS-EXE plays, and so does the BIOS, in the player, which has no picture yet. The iOS app still opens to an empty player. See [the roadmap](lib/documentation/assistant/darwin/ROADMAP.md).

## Build and run

Requires macOS 14 or later on Apple Silicon and Xcode 16 or later (Swift 6).

In Xcode, open `lib/src/darwin/iStation.xcodeproj` and pick a scheme: `macOS Personal` or `iOS Personal` to run and debug (⌘R; ⌘U runs every test from `macOS Personal`), `macOS App Store` or `iOS App Store` to archive. From Terminal:

```bash
cd lib/src/darwin
swift test                              # every module's tests, plus the architecture checks
./scripts/build.sh personal macOS       # the personal routine, "iStation Personal" (or iOS, for the Simulator)
./scripts/build.sh appstore macOS       # an App Store archive; signing and uploading are yours
```

## Licence

iStation's own code is MIT ([LICENSE](LICENSE)). Code ported from ProjectPSX keeps its MIT notice, and code from Play! keeps its BSD notices; every Swift file of the package's sources and tests and of the apps names its licence in an SPDX header, and each app lists the notices it carries in its acknowledgements ([lib/src/darwin/apps/Acknowledgements.json](lib/src/darwin/apps/Acknowledgements.json)).

## Contributing

The contributor docs start at [lib/documentation/CLAUDE.md](lib/documentation/CLAUDE.md).
