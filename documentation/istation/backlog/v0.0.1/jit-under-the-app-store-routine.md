# JIT under the App Store routine — a sandboxed `allow-jit` macOS app that maps one `MAP_JIT` region and runs code it wrote

**What / why.** The brief's first task (2026-11-07). The PS2 needs a code generator for usable speed, and the Mac App Store build runs under the App Sandbox. Developers report `com.apple.security.cs.allow-jit` accepted on the Mac App Store, but one report says JIT failed under the App Sandbox on macOS 26; Apple's porting guide says a hardened-runtime app with this entitlement can create only one `MAP_JIT` region. The user's Mac runs macOS 27. Before any PS2 work this must be known, because a failure changes how the PS2 reaches the Mac App Store ([SPEC.md](../../assistant/SPEC.md) → Apple constraints; ROADMAP → Decisions needed).

**Core constraint(s).** The App Store routine as [ADR 0016](../../adrs/two-build-routines-and-a-fresh-start.md) defines it: App Sandbox on, hardened runtime, `allow-jit`, never `com.apple.security.cs.allow-unsigned-executable-memory` or `get-task-allow`. No emulator code of any kind: the probe uses only Apple's APIs and a few hand-written AArch64 instruction words. A signing identity is the user's: anything signed with it is the user's run.

**Seam + files.** No module. A new `tools/jit-probe/`:
- a minimal SwiftUI macOS app (its own small Xcode project, or a script that bundles and signs it) whose button runs the probe and shows the result;
- the probe: `mmap` one region with `MAP_JIT`; `pthread_jit_write_protect_np(0)`; write `mov w0, #42` and `ret` (`0x52800540`, `0xD65F03C0`); `pthread_jit_write_protect_np(1)`; `sys_icache_invalidate`; call it and check 42; then try a second `MAP_JIT` region and record what happens;
- `AppStore.entitlements` (`com.apple.security.app-sandbox`, `com.apple.security.cs.allow-jit`) and a `README.md` with the results table.

**Reference.** Apple's "Porting just-in-time compilers to Apple silicon" and the `MAP_JIT` / `pthread_jit_write_protect_np` documentation. In-house: none — the first App Sandbox build.

**Decisions made** (dated):
- 2026-11-07: verify JIT under the App Store routine first; if it fails, rethink the PS2 on the Mac App Store before starting PS2 work (the user's brief).

**Open calls:**
- [default: three runs — (1) ad-hoc signed with hardened runtime, sandbox and `allow-jit`, run by the agent; (2) signed with the user's Apple Development identity, the user's run; (3) a TestFlight build for macOS, the user's run, if (1) and (2) pass] How far to verify.
- [default: a failure is recorded with the exact error and the macOS version, and raises ROADMAP's PS2 decision; nothing else in v0.0.1 waits on it except 3b's choice of entitlements] What a failure means.

**Guardrail(s).** The probe checks its own result (the return value 42, and the second region's outcome) and prints both; its README records every run's signing, sandbox state, macOS version and result.

**Acceptance criteria:**
- [ ] The probe app builds with the App Store routine's entitlements and the hardened runtime.
- [ ] Run (1)'s result is recorded; runs (2) and (3) are prepared for the user, and their results recorded when the user reports them.
- [ ] Whether a second `MAP_JIT` region is refused is recorded.
- [ ] MILESTONES records the outcome and, on failure, ROADMAP's PS2 decision is raised with the user.

**Scope note.** v0.0.1, track 3, first; no gate. 3b takes its result into the macOS App Store entitlements. Out of scope: a code generator (v2.x), iOS (which can't JIT).
