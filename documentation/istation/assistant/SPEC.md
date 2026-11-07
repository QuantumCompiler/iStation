# iStation — Spec

The product spec: what iStation is, what it is for, and the principles that shape it. The plan is in [ROADMAP.md](ROADMAP.md); the work queue is [`backlog/`](../backlog/README.md); shipped work is in [MILESTONES.md](MILESTONES.md).

*Source: the user's design documents of 2026-10-26 (Overview & Architecture, Build Roadmap, Code Scaffold), carried into this home at construction, 2026-10-31. **Re-envisioned 2026-11-07 (the user's call)** by the user's brief "Port PS1 and PS2 emulators to Swift": iStation stops being only a launcher and becomes native Swift emulators ported from open-source references, with the library app as their frontend. The evidence behind the re-vision is in [Milestone C](MILESTONES.md#milestone-c--the-re-vision).*

---

## One-liner

**iStation** is a personal, native Apple-platform app that plays PS1 and PS2 games in its own Swift emulators — ports of SwanStation and PCSX2 — behind one game library and one Play button.

## Background

Playing PS1, PS2 and PS3 games on a Mac means three emulators, three libraries, three sets of folders and three UIs. iStation began (2026-10-26) as one library in front of the user's installed DuckStation, PCSX2 and RPCS3. On 2026-11-07 the user re-envisioned it: iStation ports the emulators themselves to Swift, using open-source C++ emulators as reference implementations, so the library, the emulation, the picture, the sound and the controls are one native app. A console without a native core yet is still played through the user's installed emulator.

Foundational choices:

1. **Swift ports of open-source references.** *(Revised 2026-11-07, the user's call; it replaces "a launcher, not a merged emulator".)* Each console's core is a Swift port of one reference implementation — PS1 from [SwanStation](https://github.com/libretro/swanstation), PS2 from [PCSX2](https://github.com/PCSX2/pcsx2), both GPLv3. The reference's C++ source is the primary reference, and its compiled build is traced to check the port. The PS2's I/O processor is the PS1's CPU, so the Swift R3000A serves both ([ADR 0010](../adrs/cores-are-ports-of-open-references.md)).
2. **Identify games by the disc, not the file name.** PS1 and PS2 share serial prefixes like SLUS; only the boot key in SYSTEM.CNF tells them apart reliably.
3. **An Apple-platform app by choice.** Swift and SwiftUI; macOS 14+ on Apple Silicon first. iOS later, for PS1 only: iOS apps can't generate code at run time, and only the PS1 is playable with an interpreter. *(Revised 2026-11-07.)*
4. **Free, GPLv3, distributed outside the App Store**, signed with a Developer ID and notarized. The app is GPLv3 as a whole because its cores are; whether the App Store's terms fit the GPL is contested, and the project doesn't own the copyright needed to grant an exception. *(Revised 2026-11-07.)*
5. **A licence boundary inside the app.** Shared infrastructure — the library, the frontend, the renderer layer, audio, input and the trace harness — is written from scratch under GPL-2.0-or-later and never contains emulator code, so a later GPLv2-only core could use it ([ADR 0011](../adrs/each-module-carries-its-licence.md)). *(2026-11-07, the user's call.)*

And at construction (2026-10-31): the four-layer architecture with mechanical checks, carving the scaffold's two targets into 21 modules (the user's call); one version per roadmap phase (the user's call).

## Surfaces

1. **The main window** — a sidebar (All Games, Recently Played, one place per console with its count), a search field over titles and serials, and a grid of game tiles: double-click (or Play) to play, Show in Finder from the context menu. An empty library offers Add Library Folder….
2. **The game view** (from v0.1.0) — a native core's picture, sound and controls inside iStation.
3. **The File menu** — Add Library Folder… (⌘O) and Rescan Library (⌘R).
4. **The Settings window** (⌘,) — each installed emulator's app (Choose…, Detect Installed Emulators) for the consoles without a native core, launch options, library folders with a per-folder console hint, RPCS3's installed games, and (from v0.2.0) the user's own BIOS file for each native core.
5. **Its files** — `~/Library/Application Support/iStation/library.json` ([reference/library-file.md](../reference/library-file.md)).
6. **The installed emulators' command lines** — for consoles without a native core; what iStation passes, not a surface of its own ([reference/emulator-launch-contract.md](../reference/emulator-launch-contract.md)).

## Scope

### Goals

- Play PS1 games in iStation's own Swift emulator, ported from SwanStation and checked against it by trace.
- Then PS2, ported from PCSX2, reusing the Swift R3000A for the PS2's I/O processor.
- One library across consoles, with search and a console sidebar.
- Identify games by reading the disc itself, not the file name.
- Track last played and total play time.
- macOS on Apple Silicon first; iOS for PS1 later.
- Keep every console playable meanwhile: one without a native core launches the user's installed emulator.

### Consoles and references

| Console | Native core | Reference | Reference's licence | Until the native core plays games |
|---|---|---|---|---|
| PS1 | first (v0.x) | [libretro/swanstation](https://github.com/libretro/swanstation) — DuckStation's history up to 2022-01-11, before DuckStation's relicense | GPLv3 | the user's installed DuckStation |
| PS2 | second (v2.x) | [PCSX2](https://github.com/PCSX2/pcsx2) | GPLv3 | the user's installed PCSX2 |
| PS3 | out of scope | RPCS3 | GPLv2 only | the user's installed RPCS3 |

### Porting

- **Order inside a core:** the CPU interpreter, the memory map and the BIOS boot first; then the devices a picture needs; the software renderer before the Metal renderer; the interpreter before any recompiler. A recompiler is macOS-only, emits AArch64, and needs the `com.apple.security.cs.allow-jit` entitlement, `MAP_JIT` memory and `pthread_jit_write_protect_np` toggling.
- **Checked against the reference by trace.** The reference is built locally (never vendored) and made to write the guest's state — per instruction for a CPU, per frame or per command for a device — while it runs test content; the Swift port writes the same format, and the first divergence is the bug. The reverse-engineering MCP server Revula maps and profiles the compiled reference; it never decompiles, because the sources are open.
- **Test content** is open: OpenBIOS (MIT, an open replacement BIOS that SwanStation itself boots when no BIOS is found), homebrew, and open suites such as [ps1-tests](https://github.com/JaCzekanski/ps1-tests) (MIT) and [ps2autotests](https://github.com/unknownbrackets/ps2autotests) (ISC). The user's own BIOS dumps are used only on the user's Mac.
- **Hot paths** use concrete types, never protocol-typed values ([ADR 0012](../adrs/cores-shape-and-hot-paths.md)).

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

### Playing

*(Revised 2026-11-07: "Launching" becomes "Playing".)*

- A console with a native core plays inside iStation, in the game view.
- A console without one runs the binary inside its installed emulator's `.app` with that emulator's own flags ([reference/emulator-launch-contract.md](../reference/emulator-launch-contract.md)): PS1 in DuckStation until the native core plays games, PS2 in PCSX2, PS3 in RPCS3. Installed emulators are found in /Applications, ~/Applications, or by bundle identifier; the user can choose any app in Settings.
- **Only one game runs at a time.** When it ends, iStation adds the session to the game's play time and comes back to the front.

### Persistence

- Everything lives in one JSON file, saved whenever folders, settings or play history change.
- A rescan rebuilds the game list, then copies last played and play time across by game ID. A game's ID is its console plus its file path, or its title ID for installed PS3 games; moving a file starts its history over (whether history should follow a moved file is a decision needed, ROADMAP).
- Settings decode field by field, so adding a setting later never wipes an existing library file ([ADR 0007](../adrs/backwards-compatibility.md)).

### Distribution

*(Rewritten 2026-11-07, the user's call: the bundled-emulators plan is replaced by native cores.)*

A free GPLv3 app, signed with a Developer ID, notarized, and offered as a direct download (a notarized `.dmg`) — not the Mac App Store.

- **Licensing.** Each core is a derivative work of its GPLv3 reference: it is released under GPLv3, keeps the reference's copyright notices and credits, and its source is published. The shared infrastructure is GPL-2.0-or-later ([ADR 0011](../adrs/each-module-carries-its-licence.md)). The app as a whole is GPLv3, and the repository goes public with v1.0.0. DuckStation is never bundled, ported or read. Every third-party library in a reference is licence-checked before it is ported or linked. *This is a plan, not legal advice: get a legal review before charging money.*
- **PS3, later.** RPCS3 is GPLv2-only, so its code can never be linked into this GPLv3 program. A PS3 core would ship as a separate executable inside the app bundle that the frontend starts and talks to over XPC, pipes or sockets — which is why the frontend-to-core interface stays narrow and serializable: video frames, audio buffers, input state, save states and settings. Nothing PS3-specific is built.
- **BIOS and system software.** Never bundled, mirrored or downloaded. The user supplies their own dumps and iStation reads them where they are. Whether the app also ships OpenBIOS as a fallback is a decision for v0.2.0 (ROADMAP).
- **Signing.** A Developer ID Application certificate (paid Apple Developer Program) with hardened runtime and a secure timestamp, never `get-task-allow`; no App Sandbox. Entitlements: none until a recompiler exists, then `com.apple.security.cs.allow-jit` (macOS only).
- **Updates.** Sparkle (MIT) from a signed appcast, after a licence review onto [ADR 0010](../adrs/cores-are-ports-of-open-references.md)'s allow-list.
- **iOS** (PS1 only): the channel outside the App Store is a decision for v0.4.0 (ROADMAP).
- **Branding.** No Sony logos or artwork; describe compatibility only ("plays PS2 games"). Run a trademark check on "iStation" before a public launch.
- **The release pipeline**, every release: 1. tag the source and push it to the public repository; 2. archive iStation; 3. sign every executable inside-out; 4. notarize and staple the app, then package, notarize and staple the `.dmg`; 5. publish the `.dmg` as a GitHub release next to the source tag, and update the appcast.

## Non-goals

*(Revised 2026-11-07, the user's call: "emulating any hardware, or embedding emulator code" is no longer a non-goal.)*

- **Reading or copying the current DuckStation** (stenzek/duckstation, CC BY-NC-ND since its 2024 relicense, which forbids derivatives). PS1 code comes only from SwanStation.
- **Linking GPLv2-only code** (RPCS3) into the app.
- **A PS3 core, for now.** Only the frontend-to-core interface stays ready for one.
- **Shipping, mirroring or downloading Sony BIOS files, PS3 system software or games.** Users supply their own.
- **Platforms other than Apple's.** This is an Apple-platform app by choice.
- **The Mac App Store.** Its terms and the GPL are contested; the project can't grant an exception.
- **The PS2 on iOS.** It needs a recompiler for usable speed, and iOS forbids generating code at run time.
- **Bundling DuckStation.** Its licence forbids redistribution with modification.

## Principles

- **Layered, and the law is mechanical.** Four layers, dependencies pointing down, enforced by a check — see [ADR 0001](../adrs/layer-enforcement.md).
- **The reference decides.** A ported subsystem is right when its trace matches the reference's compiled build; the first divergence is the bug. *(2026-11-07.)*
- **Provenance stays clean and visible.** Every ported file names the reference file it comes from and its authors; nothing is read from a source the licence rules exclude. *(2026-11-07.)*
- **The licence boundary holds.** Shared infrastructure never contains emulator code, and never imports a core. *(2026-11-07.)*
- **The disc decides.** What is on the disc beats the folder hint, which beats the extension or size.
- **Installed emulators stay themselves.** For a console without a native core, iStation passes the emulator's own flags and reads its own exit; it never patches, links or reconfigures it beyond its documented config.
- **The user's history is sacred.** The library file is read compatibly, always ([ADR 0007](../adrs/backwards-compatibility.md)).
- **The first milestone matters most.** Until the Swift R3000A boots OpenBIOS with a trace identical to SwanStation's, nothing else in a core is worth building. *(Revised 2026-11-07; it replaces "Phase 1 matters most".)*

## Success criteria

*(Revised 2026-11-07.)*

- **v0.0.1:** OpenBIOS boots to its shell in the Swift core with an instruction trace identical to SwanStation's, and ps1-tests' `cop` and `code-in-io` pass.
- PS1 games boot and play in iStation, with no installed emulator (v0.2.0).
- The v1.0.0 `.dmg` installs and plays PS1 games on a clean Mac with no warnings.
- PS2: the EE and IOP interpreters boot the user's BIOS to its first screen with traces matching PCSX2.

---

*Revisions are dated notes inline where the text changed ("Revised YYYY-MM-DD (the user's call): …").*
