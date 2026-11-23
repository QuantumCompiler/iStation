// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

// BookmarkProbe — under the macOS App Store build's App Sandbox, does a security-scoped bookmark to
// a file the user chose still open after the app quits and opens again, with only
// `com.apple.security.files.user-selected.read-only`, or does it need
// `com.apple.security.files.bookmarks.app-scope`? (The design's contract row C11, v0.1.0 item 5c.)
//
// iStation's own code (MIT). No emulator code: Apple's APIs only (NSOpenPanel, URL bookmarks,
// security-scoped access, FileHandle). It reads a chosen file's first 16 bytes and never copies it.
// Built and signed by ../build.sh; see ../README.md for the run.

import AppKit
import Foundation
import Security
import SwiftUI

/// The bookmark the probe keeps between launches, in its own container.
struct SavedBookmark: Codable {
    /// The bookmark itself.
    let data: Data
    /// True when a security-scoped `bookmarkData` call succeeded; false when both threw and a plain bookmark was kept.
    let securityScoped: Bool
    /// The options the kept bookmark was made with, e.g. `.withSecurityScope`, or `none (plain)`.
    let options: String
    /// What each security-scoped call that threw said: its options, domain, code and description.
    let scopeErrors: [String]
    /// The chosen file's name, to tell runs apart.
    let fileName: String
    /// When the file was chosen.
    let created: Date
    /// The macOS the bookmark was made on.
    let macOS: String
    /// Whether the process that made it held the app-scope entitlement.
    let madeWithAppScope: Bool
}

/// The probe: keep a bookmark to a chosen file, and at each launch try to open it again.
enum Probe {
    /// What a launch's check concluded.
    enum Verdict: String {
        /// The bookmark resolved and the file's first bytes were read.
        case opens = "OPENS"
        /// The bookmark was found but didn't resolve, or the file couldn't be read.
        case doesNotOpen = "DOES NOT OPEN"
        /// No bookmark has been saved yet.
        case noBookmark = "NO BOOKMARK"
    }

    /// The App Sandbox, which both variants hold.
    static let sandbox = "com.apple.security.app-sandbox"
    /// Read-only access to files the user chose, which the App Store build holds today.
    static let userSelectedReadOnly = "com.apple.security.files.user-selected.read-only"
    /// App-scoped bookmarks: the entitlement in question, held only by the control.
    static let appScope = "com.apple.security.files.bookmarks.app-scope"
    /// How many of the file's first bytes are read: enough to prove access, never the file.
    static let headLength = 16

    /// The security-scoped bookmarks tried, in order, each with its name for the report: first
    /// `.withSecurityScope` alone, the call the app's `KeptFile.bookmark(for:)` makes; then, only if
    /// that throws, read-only as well, which an app holding only the read-only user-selected
    /// entitlement might need instead.
    static var scopedAttempts: [(name: String, options: URL.BookmarkCreationOptions)] {
        [
            (".withSecurityScope", [.withSecurityScope]),
            (".withSecurityScope, .securityScopeAllowOnlyReadAccess", [.withSecurityScope, .securityScopeAllowOnlyReadAccess]),
        ]
    }

    /// How a saved bookmark is resolved: security-scoped, as `KeptFile.resolve(_:)` does, with no UI and no mounting.
    static var resolution: URL.BookmarkResolutionOptions { [.withSecurityScope, .withoutUI, .withoutMounting] }

    /// The launch's report, worked out once, before the window opens.
    static let launchLines: [String] = report()

    /// Where the saved bookmark lives: the probe's Application Support folder, inside its container when sandboxed.
    static func recordURL() throws -> URL {
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return support.appendingPathComponent(Bundle.main.bundleIdentifier ?? "local.istation.bookmark-probe", isDirectory: true)
            .appendingPathComponent("bookmark.plist")
    }

    /// True when this process holds the entitlement, read from its own code signature.
    static func holds(_ entitlement: String) -> Bool {
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        return (SecTaskCopyValueForEntitlement(task, entitlement as CFString, nil) as? Bool) ?? false
    }

    /// The process: macOS, the app's identifier, the sandbox and the three entitlements that matter.
    static func environment() -> [String] {
        let home = NSHomeDirectory()
        let container = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"]
            ?? (home.contains("/Library/Containers/") ? URL(fileURLWithPath: home).deletingLastPathComponent().lastPathComponent : nil)
        let variant = holds(appScope) ? "appscope, the control" : "appstore"
        func yesNo(_ entitlement: String) -> String { holds(entitlement) ? "yes" : "no" }
        return [
            "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "app: \(Bundle.main.bundleIdentifier ?? "no bundle identifier") (\(variant))",
            "sandboxed: \(container.map { "yes (container \($0))" } ?? "no")",
            "entitlements: app-sandbox \(yesNo(sandbox)), files.user-selected.read-only \(yesNo(userSelectedReadOnly)), files.bookmarks.app-scope \(yesNo(appScope))",
        ]
    }

    /// The whole launch report; its last line is `result: OPENS`, `result: DOES NOT OPEN` or `result: NO BOOKMARK`.
    static func report() -> [String] {
        let check = checkSaved()
        return environment() + check.lines + ["result: \(check.verdict.rawValue)"]
    }

    /// The exit status `--report` ends with: 0 when the bookmark opened, 1 when it didn't, 2 when there is none.
    static func status(of lines: [String]) -> Int32 {
        switch lines.last {
        case "result: \(Verdict.opens.rawValue)": 0
        case "result: \(Verdict.doesNotOpen.rawValue)": 1
        default: 2
        }
    }

    /// Finds the saved bookmark and tries to open the file it points to.
    static func checkSaved() -> (lines: [String], verdict: Verdict) {
        let url: URL
        do {
            url = try recordURL()
        } catch {
            return (["bookmark: not found — the probe has no Application Support folder: \(describe(error))"], .noBookmark)
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            return (["bookmark: none saved yet — press Choose a File…"], .noBookmark)
        }
        let saved: SavedBookmark
        do {
            saved = try PropertyListDecoder().decode(SavedBookmark.self, from: Data(contentsOf: url))
        } catch {
            return (["bookmark: saved but unreadable — \(describe(error)); press Choose a File… again"], .noBookmark)
        }
        var lines = [
            "bookmark: found — “\(saved.fileName)”, chosen \(saved.created.ISO8601Format()) on macOS \(saved.macOS), "
                + "\(saved.madeWithAppScope ? "with" : "without") files.bookmarks.app-scope, \(saved.data.count) bytes of bookmark",
        ]
        lines += saved.scopeErrors.map { "security-scoped bookmark refused: \($0)" }
        lines.append(saved.securityScoped
            ? "created with security scope: yes (\(saved.options))"
            : "created with security scope: no — a plain bookmark was kept")
        let opening = open(saved.data)
        lines += opening.lines
        return (lines, opening.opened ? .opens : .doesNotOpen)
    }

    /// Resolves a bookmark with `.withSecurityScope`, starts access and reads the file's first bytes.
    static func open(_ bookmark: Data) -> (lines: [String], opened: Bool) {
        var lines: [String] = []
        var stale = false
        let file: URL
        do {
            file = try URL(resolvingBookmarkData: bookmark, options: resolution, relativeTo: nil, bookmarkDataIsStale: &stale)
            lines.append("resolved: yes, with .withSecurityScope (.withoutUI, .withoutMounting)")
        } catch {
            lines.append("resolved: no — \(describe(error))")
            do {
                file = try URL(resolvingBookmarkData: bookmark, options: [.withoutUI, .withoutMounting], relativeTo: nil, bookmarkDataIsStale: &stale)
                lines.append("resolved without .withSecurityScope: yes")
            } catch {
                lines.append("resolved without .withSecurityScope: no — \(describe(error))")
                return (lines, false)
            }
        }
        lines.append("stale: \(stale ? "yes" : "no")")
        let accessing = file.startAccessingSecurityScopedResource()
        defer {
            if accessing { file.stopAccessingSecurityScopedResource() }
        }
        lines.append("security-scoped access: \(accessing ? "started" : "not started (startAccessingSecurityScopedResource returned false)")")
        do {
            let handle = try FileHandle(forReadingFrom: file)
            defer { try? handle.close() }
            let head = try handle.read(upToCount: headLength) ?? Data()
            lines.append("readable: yes — read \(head.count) of its first \(headLength) bytes")
            return (lines, true)
        } catch {
            lines.append("readable: no — \(describe(error))")
            return (lines, false)
        }
    }

    /// Makes a bookmark to the chosen file — security-scoped first, plain if every security-scoped
    /// call throws — inside the picked URL's access, as `KeptFile.bookmark(for:)` does, saves it and checks it once.
    static func keep(_ chosen: URL) -> [String] {
        var lines = ["chose: “\(chosen.lastPathComponent)”"]
        let accessing = chosen.startAccessingSecurityScopedResource()
        defer {
            if accessing { chosen.stopAccessingSecurityScopedResource() }
        }
        var made: (data: Data, options: String)?
        var scopeErrors: [String] = []
        for attempt in scopedAttempts where made == nil {
            do {
                made = (try chosen.bookmarkData(options: attempt.options, includingResourceValuesForKeys: nil, relativeTo: nil), attempt.name)
            } catch {
                scopeErrors.append("\(attempt.name) threw \(describe(error))")
            }
        }
        lines += scopeErrors.map { "security-scoped bookmark refused: \($0)" }
        let scoped = made != nil
        if let made {
            lines.append("created with security scope: yes (\(made.options))")
        } else {
            lines.append("created with security scope: no")
            do {
                made = (try chosen.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil), "none (plain)")
                lines.append("fell back to a plain bookmark: yes")
            } catch {
                lines.append("fell back to a plain bookmark: no — \(describe(error)); nothing saved")
                return lines
            }
        }
        guard let made else { return lines }
        let bookmark = made.data
        let saved = SavedBookmark(
            data: bookmark, securityScoped: scoped, options: made.options, scopeErrors: scopeErrors,
            fileName: chosen.lastPathComponent, created: Date(), macOS: ProcessInfo.processInfo.operatingSystemVersionString,
            madeWithAppScope: holds(appScope)
        )
        do {
            let url = try recordURL()
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try PropertyListEncoder().encode(saved).write(to: url, options: .atomic)
            lines.append("saved: yes, in the probe’s own container (\(bookmark.count) bytes of bookmark)")
        } catch {
            lines.append("saved: no — \(describe(error))")
            return lines
        }
        lines.append("this launch, while the picker’s grant still holds (it proves little):")
        lines += open(bookmark).lines.map { "  " + $0 }
        lines.append("next: quit the probe (⌘Q) and open it again — the report at launch is the answer")
        return lines
    }

    /// An error as its domain, code and description, with its underlying error when it has one.
    static func describe(_ error: any Error) -> String {
        let error = error as NSError
        var text = "\(error.domain) \(error.code): \(error.localizedDescription)"
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            text += " (underlying \(underlying.domain) \(underlying.code): \(underlying.localizedDescription))"
        }
        return text
    }

    /// Writes lines to standard output, unbuffered, so a quit never loses them.
    static func emit(_ lines: [String]) {
        FileHandle.standardOutput.write(Data((lines.joined(separator: "\n") + "\n").utf8))
    }
}

/// The window: what to do, Choose a File…, Check Again, Copy Report, and the report's lines.
struct ProbeView: View {
    @State private var lines = Probe.launchLines

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Does a bookmark to a file you choose still open after the probe quits and opens again?")
                .font(.headline)
            Text("""
                Choose any file of your own that isn’t Sony’s — a text file or a photo will do. The probe keeps \
                a bookmark to it, reads only its first 16 bytes and never copies it. Then quit the probe (⌘Q) and \
                open it again: the report at launch is the answer.
                """)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Choose a File…") { choose() }
                    .keyboardShortcut("o")
                Button("Check Again") {
                    lines = Probe.report()
                    Probe.emit(lines)
                }
                Button("Copy Report") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
                }
            }
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line).font(.system(.body, design: .monospaced))
                    }
                }
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(24)
        .frame(minWidth: 720, minHeight: 440, alignment: .topLeading)
    }

    /// Opens the system's file picker and keeps a bookmark to the file chosen.
    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose any file of your own that isn’t Sony’s. The probe reads only its first 16 bytes."
        panel.prompt = "Keep a Bookmark"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        lines = Probe.environment() + Probe.keep(url)
        Probe.emit(lines)
    }
}

/// Closing the window quits the probe, so "quit and open it again" means one thing.
@MainActor
final class QuitsWithItsWindow: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

/// The probe's one window.
struct BookmarkProbeApp: App {
    @NSApplicationDelegateAdaptor(QuitsWithItsWindow.self) private var delegate

    var body: some Scene {
        Window("Bookmark Probe", id: "probe") { ProbeView() }
    }
}

/// The launch check runs first and prints its lines; `--report` then exits (0 when the bookmark
/// opened, 1 when it didn't, 2 when none is saved); otherwise the window opens.
@main
enum Entry {
    @MainActor
    static func main() {
        let lines = Probe.launchLines
        Probe.emit(lines)
        if CommandLine.arguments.contains("--report") {
            exit(Probe.status(of: lines))
        }
        BookmarkProbeApp.main()
    }
}
