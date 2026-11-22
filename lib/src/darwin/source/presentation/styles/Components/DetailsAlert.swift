// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import SwiftUI

/// The design's alert with a Details disclosure: a symbol in its tone, the question or what happened,
/// an explanation in plain words, the exact call behind it under Details (closed until the person
/// opens it), and its buttons. SwiftUI's `.alert` can't hold a disclosure, so present it with
/// `.sheet`; each button's action decides what happens next. Cancel is bound to Escape and the
/// primary button to Return; a destructive button is never the default.
public struct DetailsAlert: View {
    /// One of the alert's buttons.
    public struct Action: Sendable {
        /// How a button is drawn and which key presses it.
        public enum Role: Sendable {
            /// Leaves things as they were — "Cancel": bordered, bound to Escape.
            case cancel
            /// Goes ahead, safely — "Remove", "Load", "Locate…", "OK": the accent's default button.
            case primary
            /// Goes ahead and can't be undone — "Reset", "Replace", "Move to Trash": the danger fill.
            case destructive
            /// Another way out — "Save First…", "Remove from Library": bordered.
            case secondary
        }

        /// The button's title, in title case.
        public let title: String
        /// How it's drawn and which key presses it.
        public let role: Role
        let perform: @MainActor () -> Void

        /// A button that runs `perform` when pressed.
        public init(_ title: String, role: Role = .secondary, perform: @escaping @MainActor () -> Void) {
            self.title = title
            self.role = role
            self.perform = perform
        }
    }

    private let title: String
    private let message: String
    private let details: String?
    private let tone: Tone
    private let actions: [Action]
    @State private var showsDetails: Bool

    /// An alert asking or telling `title`, explained by `message`, with the exact call in `details`
    /// (nil for no disclosure), led by `tone`'s symbol. Details start closed unless `showsDetails`.
    public init(_ title: String, message: String, details: String? = nil, tone: Tone = .warning, showsDetails: Bool = false, actions: [Action]) {
        self.title = title
        self.message = message
        self.details = details
        self.tone = tone
        self.actions = actions
        _showsDetails = State(initialValue: showsDetails)
    }

    public var body: some View {
        VStack(spacing: Metrics.space3) {
            Image(systemName: tone.symbol)
                .textStyle(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(tone.foreground)
                .accessibilityHidden(true)
            Text(title)
                .textStyle(.headline, weight: .bold)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .textStyle(.callout)
                .fixedSize(horizontal: false, vertical: true)
            if let details {
                DisclosureGroup(isExpanded: $showsDetails) {
                    CodeBlock(details)
                } label: {
                    Text("Details")
                }
                .disclosureGroupStyle(DetailsDisclosureStyle())
            }
            buttonRow
                .padding(.top, Metrics.space1)
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(Palette.text)
        .padding(Metrics.space5)
        .frame(width: Metrics.layout.alertWidth)
        .background(Palette.raised)
        .presentationBackground(Palette.raised)
    }

    @ViewBuilder private var buttonRow: some View {
        #if os(macOS)
        HStack(spacing: Metrics.space2) {
            ForEach(actions.indices, id: \.self) { button(actions[$0]) }
        }
        #else
        VStack(spacing: Metrics.space2) {
            ForEach(actions.indices, id: \.self) { button(actions[$0]) }
        }
        #endif
    }

    private func button(_ action: Action) -> some View {
        Button(action.title, action: action.perform)
            .buttonStyle(SheetButtonStyle(kind(of: action.role), fillsWidth: true))
            .keyboardShortcut(shortcut(of: action.role))
    }

    private func kind(of role: Action.Role) -> SheetButtonStyle.Kind {
        switch role {
        case .cancel, .secondary: .bordered
        case .primary: .primary
        case .destructive: .destructive
        }
    }

    private func shortcut(of role: Action.Role) -> KeyboardShortcut? {
        switch role {
        case .cancel: .cancelAction
        case .primary: .defaultAction
        case .destructive, .secondary: nil
        }
    }
}

/// The Details disclosure as the design draws it: "Details" in the accent's text color with a
/// turning chevron, and the content below it at the alert's full width rather than indented.
private struct DetailsDisclosureStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        DetailsDisclosure(configuration: configuration)
    }
}

private struct DetailsDisclosure: View {
    let configuration: DisclosureGroupStyleConfiguration
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.space2) {
            Button {
                withAnimation(Motion.animation(Motion.base, reduceMotion: reduceMotion)) {
                    configuration.isExpanded.toggle()
                }
            } label: {
                HStack(spacing: Metrics.space1) {
                    Image(systemName: Symbols.forward)
                        .imageScale(.small)
                        .rotationEffect(.degrees(configuration.isExpanded ? 90 : 0))
                    configuration.label
                }
                .textStyle(.callout)
                .foregroundStyle(Palette.accentText)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(configuration.isExpanded ? "Shown" : "Hidden")
            if configuration.isExpanded {
                configuration.content
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Exact text — a call, an error, a tool's report — as the design shows it: monospaced, wrapped and
/// selectable, on the content's fill inside a hairline edge. Internal to the alert's Details and the
/// job sheet's output.
struct CodeBlock: View {
    private let text: String

    /// A block showing `text` as it is.
    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.radiusControl)
        Text(text)
            .textStyle(.caption, monospaced: true)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Metrics.space2)
            .padding(.horizontal, Metrics.space3)
            .foregroundStyle(Palette.text)
            .background(Palette.content, in: shape)
            .overlay(shape.strokeBorder(Palette.separator))
    }
}

#if DEBUG
#Preview("Details closed") {
    DetailsAlert(
        "Reset the console?", message: "The game starts again from the beginning. Anything you haven’t saved is lost.",
        details: "PS1Console.powerOn(bios:) with my-console-bios.bin (524,288 bytes)",
        actions: [DetailsAlert.Action("Cancel", role: .cancel) {}, DetailsAlert.Action("Reset", role: .destructive) {}]
    )
}

#Preview("Details open") {
    DetailsAlert(
        "Reset the console?", message: "The game starts again from the beginning. Anything you haven’t saved is lost.",
        details: "PS1Console.powerOn(bios:) with my-console-bios.bin (524,288 bytes)", showsDetails: true,
        actions: [DetailsAlert.Action("Cancel", role: .cancel) {}, DetailsAlert.Action("Reset", role: .destructive) {}]
    )
}

#Preview("Information") {
    DetailsAlert(
        "Remove “Harbor Lights (USA)” from your library?",
        message: "The disc image stays on your Mac, and so do its save states and memory card. You can add it again any time.",
        details: "Deletes its entry and bookmark from library.json in iStation’s container.\nLeaves ~/Games/PS1/Harbor Lights (USA).cue untouched.",
        tone: .info,
        actions: [DetailsAlert.Action("Cancel", role: .cancel) {}, DetailsAlert.Action("Remove", role: .primary) {}]
    )
}

#Preview("Error") {
    DetailsAlert(
        "This save can’t be loaded", message: "Slot 2 was saved by an earlier iStation in format 1. This version reads format 2.",
        details: "loadState(_:) threw SaveStateError.unsupportedVersion(found: 1, supported: 2...2)", tone: .danger,
        actions: [DetailsAlert.Action("OK", role: .primary) {}]
    )
}
#endif
