// JITProbe — does a hardened-runtime, App Sandbox macOS app with `allow-jit` get a `MAP_JIT`
// region and run code it wrote there? And is a second region refused?
//
// iStation's own code (MIT). No emulator code: Apple's APIs and two hand-written AArch64
// instruction words. Built and signed by ../build.sh; see ../README.md for the runs.

import Darwin
import Foundation
import SwiftUI

/// The probe: map a `MAP_JIT` region, write `mov w0, #42; ret`, run it, then try a second region.
enum Probe {
    /// `mov w0, #42` then `ret`.
    static let program: [UInt32] = [0x5280_0540, 0xD65F_03C0]
    /// One 16 KB page, the page size on Apple silicon.
    static let regionSize = 16_384

    /// What happened to one region.
    struct Outcome {
        let detail: String
        let returned: Int32?
    }

    /// Runs the whole probe and describes it in lines; the last line is `result: PASS` or `result: FAIL`.
    static func run() -> [String] {
        let home = NSHomeDirectory()
        var lines = [
            "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "sandboxed: \(home.contains("/Library/Containers/") ? "yes (container \(URL(fileURLWithPath: home).deletingLastPathComponent().lastPathComponent))" : "no")",
        ]
        let first = tryRegion()
        lines.append("region 1: \(first.detail)")
        let second = tryRegion()
        lines.append("region 2: \(second.detail)")
        lines.append("result: \(first.returned == 42 ? "PASS" : "FAIL")")
        return lines
    }

    /// Maps one `MAP_JIT` region and, if it is granted, writes the program into it and calls it.
    static func tryRegion() -> Outcome {
        guard let region = mmap(nil, regionSize, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_PRIVATE | MAP_ANON | MAP_JIT, -1, 0),
              region != MAP_FAILED
        else {
            let code = errno
            return Outcome(detail: "mmap(MAP_JIT) refused: errno \(code) (\(String(cString: strerror(code))))", returned: nil)
        }
        pthread_jit_write_protect_np(0)
        let words = region.bindMemory(to: UInt32.self, capacity: program.count)
        for (index, word) in program.enumerated() {
            words[index] = word
        }
        pthread_jit_write_protect_np(1)
        sys_icache_invalidate(region, program.count * MemoryLayout<UInt32>.size)
        let function = unsafeBitCast(region, to: (@convention(c) () -> Int32).self)
        let value = function()
        return Outcome(detail: "mapped, wrote \(program.count) instructions, ran them: returned \(value)", returned: value)
    }
}

/// The window: one button and the probe's lines.
struct ProbeView: View {
    @State private var lines: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("Run the JIT probe") { lines = Probe.run() }
            ForEach(lines, id: \.self) { line in
                Text(line).font(.system(.body, design: .monospaced))
            }
        }
        .padding(24)
        .frame(minWidth: 560, minHeight: 240, alignment: .topLeading)
    }
}

struct JITProbeApp: App {
    var body: some Scene {
        WindowGroup("JIT Probe") { ProbeView() }
    }
}

/// `--probe` prints the probe's lines and exits (0 on PASS); otherwise the app opens its window.
@main
enum Entry {
    @MainActor
    static func main() {
        if CommandLine.arguments.contains("--probe") {
            let lines = Probe.run()
            lines.forEach { print($0) }
            exit(lines.last == "result: PASS" ? 0 : 1)
        }
        JITProbeApp.main()
    }
}
