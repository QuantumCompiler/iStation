# iStation — Spec

The product spec: what iStation is, what it is for, and the principles that shape it. The plan is in [ROADMAP.md](ROADMAP.md); the work queue is [`backlog/`](../backlog/README.md); shipped work is in [MILESTONES.md](MILESTONES.md).

*Source: the user's design documents of 2026-10-26 (Overview & Architecture, Build Roadmap, Code Scaffold), carried into this home at construction, 2026-10-31.*

---

## One-liner

**iStation** is a personal, native macOS app that gives DuckStation, PCSX2 and RPCS3 one shared game library and one Play button.

## Background

Playing PS1, PS2 and PS3 games on a Mac means three emulators, three libraries, three sets of folders and three UIs. iStation puts one library in front of them: each emulator still does the emulation; iStation finds the games, works out which console each belongs to, and launches the right emulator with the right flags.

Foundational choices (the user's design, 2026-10-26):

1. **A launcher, not a merged emulator.** The three consoles share almost no hardware (MIPS R3000A; the Emotion Engine with VU0/VU1; the Cell's PPU and six SPUs), and the three licences cannot be combined into one program: DuckStation is CC BY-NC-ND 4.0, PCSX2 GPLv3, RPCS3 GPLv2 only. Each emulator runs as a separate process, driven by its own command line ([ADR 0008](../adrs/emulators-are-separate-programs.md)). Emulator updates then arrive the normal way.
2. **Identify games by the disc, not the file name.** PS1 and PS2 share serial prefixes like SLUS; only the boot key in SYSTEM.CNF tells them apart reliably.
3. **A Mac app by choice.** Swift and SwiftUI, macOS 14+.
4. **Free, GPLv3, a notarized direct download** — not the Mac App Store, whose terms conflict with the GPL.

And at construction (2026-10-31): the four-layer architecture with mechanical checks, carving the scaffold's two targets into 21 modules (the user's call); one version per roadmap phase (the user's call).

## Surfaces

1. **The main window** — a sidebar (All Games, Recently Played, one place per console with its count), a search field over titles and serials, and a grid of game tiles: double-click (or Play) to launch, Show in Finder from the context menu. An empty library offers Add Library Folder….
2. **The File menu** — Add Library Folder… (⌘O) and Rescan Library (⌘R).
3. **The Settings window** (⌘,) — each emulator's app (Choose…, Detect Installed Emulators), launch options (fullscreen; skip the BIOS intro), library folders with a per-folder console hint, and RPCS3's installed games.
4. **Its files** — `~/Library/Application Support/iStation/library.json` ([reference/library-file.md](../reference/library-file.md)).
5. **The emulators' command lines** — what iStation passes, not a surface of its own ([reference/emulator-launch-contract.md](../reference/emulator-launch-contract.md)).

## Scope

### Goals

- One library across PS1, PS2 and PS3, with search and a console sidebar.
- Identify games by reading the disc itself, not the file name.
- Launch with one double-click, fullscreen, and return to iStation when the game closes.
- Track last played and total play time.
- Pick up upstream emulator updates with no changes to iStation.

### Game identification

The console is decided by what is on the disc. A folder hint (the folder's Console setting, or names like `PS2/`, `psx/`, `rpcs3/`) is used only when the contents cannot be read.

| Input | How iStation reads it | Result |
|---|---|---|
| `.iso` (2048-byte sectors) | ISO 9660 from sector 16, then the root directory | Finds `SYSTEM.CNF` or `PS3_GAME/PARAM.SFO` |
| `.bin` / `.img` (raw 2352-byte sectors) | Detects the 12-byte sync pattern; user data at offset 16 (Mode 1) or 24 (Mode 2) | Same as `.iso` |
| `SYSTEM.CNF` with `BOOT2 = cdrom0:\SLUS_200.62;1` | `BOOT2` key | PS2, serial `SLUS-20062` |
| `SYSTEM.CNF` with `BOOT = cdrom:\SCUS_944.55;1` | `BOOT` key | PS1, serial `SCUS-94455` |
| Disc with only `PSX.EXE` | Early PS1 boot file | PS1, no serial |
| PS3 disc folder or ISO | `PS3_GAME/PARAM.SFO`: `TITLE`, `TITLE_ID` | PS3, real title and ID |
| RPCS3 `dev_hdd0/game/<ID>` | `PARAM.SFO` with `CATEGORY = HG` (patches and DLC skipped) | PS3 installed title |
| `.cue` | First `FILE` entry is read; its `.bin` is hidden from the list | One entry per game (a cue is a CD: PS1, or PS2 by hint) |
| `.m3u` | First disc is identified; listed discs are hidden | One entry per multi-disc set |
| `.chd`, `.gz`, `.ecm` | Can't read inside yet (v0.2.0) | Folder hint, then size guess (over 800 MB → PS2) |
| `.cso`, `.zso` / `.pbp` | Extension only | PS2 / PS1 |

Titles come from PARAM.SFO for PS3 and from cleaned file names otherwise: `Final Fantasy VII (USA) (Disc 1).cue` becomes `Final Fantasy VII`.

### Launching

- iStation runs the binary inside each emulator's `.app` with that emulator's own flags ([reference/emulator-launch-contract.md](../reference/emulator-launch-contract.md)). PS1 runs in DuckStation, PS2 in PCSX2, PS3 in RPCS3.
- Emulators are found in /Applications, ~/Applications, or by bundle identifier; the user can choose any app in Settings.
- **Only one game runs at a time.** When its process exits, iStation adds the session to the game's play time and comes back to the front.

### Persistence

- Everything lives in one JSON file, saved whenever folders, settings or play history change.
- A rescan rebuilds the game list, then copies last played and play time across by game ID. A game's ID is its console plus its file path, or its title ID for installed PS3 games; moving a file starts its history over (whether history should follow a moved file is a decision needed, ROADMAP).
- Settings decode field by field, so adding a setting later never wipes an existing library file ([ADR 0007](../adrs/backwards-compatibility.md)).

### Distribution

Free and notarized, as a direct download, in two stages:

| Release | Emulators | What ships | Effort |
|---|---|---|---|
| v1.0.0 Launcher | User-installed: DuckStation or PCSX-Redux, PCSX2, RPCS3 | `iStation.app` only | Sign and notarize one app |
| v2.0.0 Bundled | PCSX-Redux, PCSX2, RPCS3 inside the app | `iStation.app` with 3 helper apps, plus published source | Build, sign and notarize all four |

- **Licensing.** iStation is GPLv3. Each bundled emulator stays a separate program (`Contents/Helpers/<Emulator>.app`), which the GPL treats as aggregation, so each keeps its own licence: PCSX-Redux GPL-2.0, PCSX2 GPL-3.0-or-later, RPCS3 GPL-2.0 only (never linked with PCSX2). DuckStation is never bundled; v1 only launches the user's own install. Each release ships each licence text (`Resources/Licenses/`) and the exact source of what it ships: emulator sources are pinned git submodules, so each release tag holds them. An Acknowledgements screen lists each component, its licence and a link to its source. *This is a plan, not legal advice: get a legal review before charging money or heavily modifying an emulator.*
- **BIOS and system software.** A first-run screen (v2.0.0) asks for a PS1 BIOS, a PS2 BIOS and the PS3 system software update file, each optional; they are copied to `~/Library/Application Support/iStation/BIOS` and each emulator is pointed at them through its own config (RPCS3 installs its file through its firmware-install option). iStation never bundles or downloads them, and the screen says so.
- **Signing.** A Developer ID Application certificate (paid Apple Developer Program). Sign inside-out — each helper's nested code, each helper, then `iStation.app` — with hardened runtime and a secure timestamp, never `get-task-allow`. No App Sandbox, no Mac App Store. Entitlements: iStation none beyond hardened runtime; PCSX2 `allow-jit`, `allow-unsigned-executable-memory`, `disable-library-validation`, `device.audio-input`, `device.camera` (its `PCSX2.entitlements`); RPCS3 and PCSX-Redux _TODO:_ to confirm (RPCS3's recompilers likely need `allow-jit` and `allow-unsigned-executable-memory`).
- **Updates.** Sparkle (MIT) from a signed appcast. An emulator update means bumping its submodule, rebuilding, re-running the phase-1 gate, signing and notarizing a new release.
- **Branding.** No Sony logos or artwork; describe compatibility only ("plays PS2 games"). Run a trademark check on "iStation" before a public launch.
- **The release pipeline**, every release (v1 skips 2 and 3): 1. tag the source, with pinned submodules, pushed to the public repo; 2. build the emulators from the submodules for Apple Silicon; 3. assemble the bundle (helpers into `Contents/Helpers`, licences into `Resources/Licenses`); 4. archive iStation; 5. sign every executable inside-out; 6. notarize and staple the app, then package, notarize and staple the `.dmg`; 7. publish the `.dmg` as a GitHub release next to the source tag, and update the appcast.

## Non-goals

- **Emulating any hardware, or embedding emulator code.** iStation is a launcher; the emulators do the emulating ([ADR 0008](../adrs/emulators-are-separate-programs.md)).
- **Shipping Sony BIOS files, PS3 system software or games.** Users supply their own; iStation never bundles or downloads them.
- **Cross-platform support.** This is a Mac app by choice.
- **The Mac App Store.** Its terms conflict with the GPL.
- **Bundling DuckStation.** Its licence forbids redistribution with modification or embedding; v1 launches the user's own copy, v2 bundles PCSX-Redux instead.

## Principles

- **Layered, and the law is mechanical.** Four layers, dependencies pointing down, enforced by a check — see [ADR 0001](../adrs/layer-enforcement.md).
- **The disc decides.** What is on the disc beats the folder hint, which beats the extension or size.
- **The emulators stay themselves.** iStation passes their own flags and reads their own exit; it never patches, links or reconfigures them beyond their documented config.
- **The user's history is sacred.** The library file is read compatibly, always ([ADR 0007](../adrs/backwards-compatibility.md)).
- **Phase 1 matters most.** Until the app boots a real game from each console and comes back, nothing else is worth building (the user's Build Roadmap).

## Success criteria

- One PS1, one PS2 and one PS3 game boot from iStation and return to it on exit (the v0.0.1 gate).
- The whole library shows real titles and covers (v0.1.0 gate).
- A game can be picked and launched from the sofa without touching the keyboard (v0.4.0 gate).
- The v1.0.0 `.dmg` installs and runs on a clean Mac with no warnings; the v2.0.0 bundle plays one game from each console with no separate installs.

---

*Revisions are dated notes inline where the text changed ("Revised YYYY-MM-DD (the user's call): …").*
