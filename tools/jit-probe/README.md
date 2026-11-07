# JIT probe

Does a macOS app built the App Store way — **App Sandbox on, hardened runtime, `com.apple.security.cs.allow-jit`, never `allow-unsigned-executable-memory` or `get-task-allow`** ([ADR 0016](../../documentation/istation/adrs/two-build-routines-and-a-fresh-start.md)) — get a `MAP_JIT` region and run code it wrote there? The PS2's code generator depends on the answer (v0.0.1 item 3a, the brief's first task).

iStation's own code, MIT. No emulator code: Apple's APIs (`mmap` with `MAP_JIT`, `pthread_jit_write_protect_np`, `sys_icache_invalidate`) and two hand-written AArch64 instruction words, `mov w0, #42` (`0x52800540`) and `ret` (`0xD65F03C0`). Not part of any shipped app.

## Build and run

```bash
./build.sh            # App Store entitlements (sandbox + allow-jit), hardened runtime, ad-hoc signed
./build.sh nojit      # the control: sandbox and hardened runtime, no allow-jit
.build/appstore/JITProbe.app/Contents/MacOS/JITProbe --probe     # prints the result, exits 0 on PASS
open .build/appstore/JITProbe.app                                 # or the window: press "Run the JIT probe"
```

The probe maps one `MAP_JIT` region, makes it writable for its thread, writes the two instructions, makes it executable again, invalidates the instruction cache, calls it and expects 42; then it tries a second region the same way and records what happens. It also reports whether it runs inside an App Sandbox container. The first sandboxed run creates the container `~/Library/Containers/local.istation.jit-probe`.

## Results

| Run | Signing | Sandbox | `allow-jit` | macOS | Region 1 | Region 2 | Result |
|---|---|---|---|---|---|---|---|
| (0) control | ad-hoc, hardened runtime | on | **no** | 27.0.1 (26A434) | refused: `EINVAL` | refused: `EINVAL` | FAIL, as expected |
| (1) | ad-hoc, hardened runtime | on | yes | 27.0.1 (26A434) | mapped, ran, returned 42 | **mapped, ran, returned 42** | **PASS** |
| (2) | your Apple Development identity | on | yes | | | | _your run_ |
| (3) | TestFlight (App Store distribution) | on | yes | | | | _your run_ |

Run (1) was made 2026-11-07 by the agent, both from a shell and through Launch Services (`open`), with the same output. The control shows the entitlement is what grants the region. A second `MAP_JIT` region was **not** refused in run (1): Apple's porting guide describes one region per process, which ad-hoc signing does not enforce here — runs (2) and (3) say whether real signing does.

## Your runs

**(2) Signed with your Apple Development identity.** From this folder:

```bash
./build.sh appstore "Apple Development: Taylor Larrechea (729WQ7ML32)"
```

then run it and send the four result lines back:

```bash
.build/appstore/JITProbe.app/Contents/MacOS/JITProbe --probe
```

macOS may ask to let `codesign` use the key in your keychain.

**(3) TestFlight for macOS**, only once (2) passes. It needs three things this Mac doesn't hold yet (checked 2026-11-07: it has Apple Development and Developer ID Application identities only):

1. An **Apple Distribution** certificate (Xcode → Settings → Accounts → Manage Certificates → +).
2. An **App Store Connect app record** for the probe, with its own bundle identifier (for example `<your prefix>.jit-probe`, replacing `local.istation.jit-probe` in `Info.plist`).
3. A **Mac App Store provisioning profile** for that identifier; Xcode's automatic signing makes it once the target carries `AppStore.entitlements`.

Then wrap the probe in an Xcode macOS app target (add `Sources/JITProbe.swift`, set `Sources/OSCacheControl.h` as its Objective-C bridging header and `AppStore.entitlements` as its entitlements, hardened runtime on), archive it, upload it, install it from TestFlight, press "Run the JIT probe", and record the four result lines in the table above.
