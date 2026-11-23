# Bookmark probe

Under the macOS App Store build's App Sandbox, does a **security-scoped bookmark** to a file you chose still open after the app quits and opens again, with only the entitlement the App Store build holds today, `com.apple.security.files.user-selected.read-only` ([`apps/macos/AppStore.entitlements`](../../apps/macos/AppStore.entitlements)), or does it also need `com.apple.security.files.bookmarks.app-scope`, the entitlement Apple documents for app-scoped bookmarks?

The app keeps your BIOS, and later your games, by bookmark and never copies them, so this decides whether a relaunch still finds them. It is the design's contract row C11 ("Keep access to the BIOS and games across launches", tagged verify on the [`Contract` board](../../../../documentation/design/darwin/html/Contract.dc.html)). v0.1.0 item 5c decided on 2026-11-22 that the App Store entitlements gain `files.bookmarks.app-scope` **only if this run shows the need**, and that the item ships without it, leaving the run to you, as the [JIT probe](../jit-probe/README.md)'s signed runs are.

iStation's own code, MIT. No emulator code: Apple's APIs only (`NSOpenPanel`, URL bookmarks, security-scoped access, `FileHandle`). Not part of any shipped app. It reads the chosen file's first 16 bytes to prove it can, and never copies the file or shows what it read.

## What it does

The probe is one sandboxed window, signed with the hardened runtime ([ADR 0016](../../../../documentation/adrs/darwin/two-build-routines-and-a-fresh-start.md)), in two variants:

| Variant | Entitlements | Identifier (its own container) |
|---|---|---|
| `appstore` (the default) | `AppStore.entitlements`, a byte copy of the App Store app's, which `build.sh` compares with `apps/macos/AppStore.entitlements` before it builds either variant: App Sandbox, `files.user-selected.read-only`, `cs.allow-jit` | `local.istation.bookmark-probe` |
| `appscope` (the control) | `AppScope.entitlements`: the same plus `files.bookmarks.app-scope` | `local.istation.bookmark-probe.appscope` |

Neither is ever the App Store app's own identifier (`local.istation.macos`) or its container. The control's identifier is its own so its container, and its bookmark, never mix with the `appstore` variant's.

- **Choose a File…** (⌘O) opens the system's file picker. Inside the picked file's access, the probe makes a bookmark to it — first with `.withSecurityScope`, the call the app's `KeptFile.bookmark(for:)` makes; only if that throws, with `.withSecurityScope, .securityScopeAllowOnlyReadAccess`; and if both throw, a plain bookmark, recording each error — saves it in its own container (`Application Support/<identifier>/bookmark.plist`) and checks it once. That first check proves little: the picker's grant still holds until the probe quits.
- **At every launch** it reads the saved bookmark, resolves it with `.withSecurityScope` (with `.withoutUI` and `.withoutMounting`, as the app's `KeptFile.resolve(_:)` does; if that fails, once more without the security scope, to tell the two failures apart), starts security-scoped access and reads the file's first 16 bytes. The window and standard output show each step; **Copy Report** puts the lines on the clipboard, and **Check Again** repeats the check.
- `--report` prints the launch check and exits: `0` when the bookmark opened, `1` when it didn't, `2` when none is saved yet.

A report reads, line by line:

| Line | Says |
|---|---|
| `macOS`, `app`, `sandboxed`, `entitlements` | the system, the variant and its container, and the three entitlements the process holds, read from its own signature |
| `bookmark` | found or not; the file's name, when it was chosen, on which macOS, and whether the app-scope entitlement was held then |
| `security-scoped bookmark refused` | only when a security-scoped call threw: its options and the error's domain, code and description |
| `created with security scope` | `yes` with the options that made it, or `no`: a plain bookmark was kept |
| `resolved` | `yes, with .withSecurityScope`, or `no` with the error; then whether it resolves without the security scope |
| `stale` | whether macOS reports the bookmark stale (the file moved or changed; the app would make it again) |
| `security-scoped access` | whether `startAccessingSecurityScopedResource()` granted access |
| `readable` | `yes` with how many of the first 16 bytes it read, or `no` with the error, its domain and code (and its underlying error) |
| `result` | `OPENS`, `DOES NOT OPEN` or `NO BOOKMARK` |

## Build

From this folder:

```bash
./build.sh            # appstore: the App Store entitlements, hardened runtime, ad-hoc signed, into .build/appstore/
./build.sh appscope   # the control, into .build/appscope/
./build.sh appstore "Apple Development: <Name> (<ID>)"   # optionally signed with your identity
```

`build.sh` prints the signature and the entitlements it signed with. The agent built both variants on 2026-11-22 and launched neither: the run is yours.

## Your run

1. **Build** the `appstore` variant: `./build.sh`.
2. **Open it**: `open .build/appstore/BookmarkProbe.app`. Its first launch creates its container, `~/Library/Containers/local.istation.bookmark-probe`, and reports `result: NO BOOKMARK`.
3. **Choose a File…** — any file of your own that isn't Sony's: a text file or a photo will do. Pick it from a folder where you'd keep a BIOS (your Documents folder, say), so the run is the app's real case. The report shows whether the bookmark was made with security scope.
4. **Quit** the probe (⌘Q, or close its window).
5. **Open it again**, the same way, without rebuilding it in between (a rebuild changes an ad-hoc signature, and a security-scoped bookmark belongs to the app that made it).
6. **Read the report** at launch, or press **Copy Report**. From a shell, `.build/appstore/BookmarkProbe.app/Contents/MacOS/BookmarkProbe --report` prints the same check.
7. **Repeat with the control**: `./build.sh appscope`, then steps 2–6 with `.build/appscope/BookmarkProbe.app` (its container is `~/Library/Containers/local.istation.bookmark-probe.appscope`).
8. **Record** both runs in [Results](#results), and send the two reports back.

If macOS asks whether to let the probe open the file or reach data, say what it asked in the row's notes.

## What each outcome means

| `appstore` after the relaunch | `appscope` after the relaunch | Means | What follows |
|---|---|---|---|
| `OPENS` | `OPENS` | `files.user-selected.read-only` is enough: a security-scoped bookmark keeps access across launches without the app-scope entitlement. | `apps/macos/AppStore.entitlements` stays as it is. The run closes C11's verify for macOS (the 5c decision of 2026-11-22): the tag is dropped for macOS and the run recorded in the `Contract` board's `EVIDENCE`, a design change published by the design's sync rule. |
| `DOES NOT OPEN` (the security-scoped bookmark wasn't made, didn't resolve, or didn't read) | `OPENS` | The App Store build needs `files.bookmarks.app-scope`. | Add `com.apple.security.files.bookmarks.app-scope` to `apps/macos/AppStore.entitlements` by [DEVELOPER.md's "Changing an entitlement"](../../../../documentation/assistant/darwin/DEVELOPER.md#changing-an-entitlement) recipe (`appStoreEntitlementsAreClean` must still pass); name app-scoped bookmarks in CLAUDE.md's Stack line and SPEC.md's Build routines table in the same change; and drop C11's verify tag for macOS, with the run as its evidence. |
| `DOES NOT OPEN` | `DOES NOT OPEN` | The entitlement isn't what decides it: the run is inconclusive (the signing, the file's folder, or the probe). | Leave both as they are: the entitlements unchanged and C11 still verify. Record the two reports; the next step is a bug investigation, perhaps a rerun signed with your Apple Development identity (`./build.sh appstore "<identity>"`). |
| `OPENS` | `DOES NOT OPEN` | Unexpected: the control lost what the App Store variant kept. | Leave both as they are, and record the reports for an investigation. |

A `stale: yes` with `readable: yes` still counts as opening: the app makes the bookmark again when macOS says it's stale. If the `appstore` run opens only through the read-only attempt (`.withSecurityScope` alone refused, `.securityScopeAllowOnlyReadAccess` accepted), the entitlements still stay as they are, and the app's `KeptFile.bookmark(for:)` takes the read-only option in the follow-up instead.

## Results

| Date | macOS | Variant | Created with security scope? | After relaunch: resolved? | Readable? | Stale? | Notes (signing, the file's folder, prompts) |
|---|---|---|---|---|---|---|---|
| | | `appstore` | | | | | |
| | | `appscope` (control) | | | | | |
