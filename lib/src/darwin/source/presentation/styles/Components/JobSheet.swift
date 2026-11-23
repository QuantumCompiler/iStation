// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import SwiftUI

/// The sheet a job runs in, as the design draws it for checking a BIOS, adding a folder, opening a
/// game and recording a trace: the title, each step with its state, a progress bar, a summary in its
/// tone, what became of each file, exact output, and the buttons. Present it with `.sheet`: it draws
/// the `JobPresentation` its place's view-model gives it and hands the button pressed to `perform`.
/// Stop is bound to ⌘., the default button to Return and Close to Escape; while the job runs the
/// sheet can't be swiped away.
public struct JobSheet: View {
    private let job: JobPresentation
    private let perform: @MainActor (JobPresentation.Action) -> Void

    /// A sheet drawing `job`, calling `perform` with each button pressed.
    public init(_ job: JobPresentation, perform: @escaping @MainActor (JobPresentation.Action) -> Void) {
        self.job = job
        self.perform = perform
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Metrics.space4) {
            header
            if !job.steps.isEmpty {
                steps
            }
            if let progress = job.progress {
                progressBar(progress)
            }
            if let summary = job.summary {
                Banner(summary.text, tone: summary.tone, showsSymbol: false)
            }
            if !job.results.isEmpty {
                results
            }
            if let output = job.output {
                CodeBlock(output)
            }
            if !job.actions.isEmpty {
                buttons
            }
        }
        .textStyle(.body)
        .foregroundStyle(Palette.text)
        .padding(Metrics.space5)
        #if os(macOS)
        .frame(width: Metrics.layout.sheetWidth)
        .onExitCommand(perform: exitCommand)
        #endif
        .background(Palette.raised)
        .presentationBackground(Palette.raised)
        .interactiveDismissDisabled(job.isRunning)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Metrics.space2) {
            Text(job.title)
                .textStyle(.title3, weight: .bold)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let subtitle = job.subtitle {
                Text(subtitle)
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: Metrics.space2) {
            ForEach(job.steps.indices, id: \.self) { StepRow(step: job.steps[$0]) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Steps")
    }

    private func progressBar(_ progress: JobPresentation.Progress) -> some View {
        VStack(alignment: .leading, spacing: Metrics.space2) {
            ProgressView(value: progress.fraction)
                .progressViewStyle(.linear)
                .tint(Palette.accent)
                .accessibilityLabel(progress.label)
                .accessibilityValue(progress.text)
            Text(progress.text)
                .textStyle(.caption)
                .foregroundStyle(Palette.secondaryText)
                .lineLimit(1)
                .accessibilityHidden(true)
        }
    }

    private var results: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.space2) {
                ForEach(job.results.indices, id: \.self) { ResultRow(result: job.results[$0]) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: Metrics.layout.resultsMaxHeight)
        .accessibilityLabel("Results")
    }

    @ViewBuilder private var buttons: some View {
        #if os(macOS)
        HStack(spacing: Metrics.space2) {
            Spacer()
            ForEach(job.actions.indices, id: \.self) { button(job.actions[$0], fillsWidth: false) }
        }
        #else
        VStack(spacing: Metrics.space2) {
            ForEach(job.actions.indices, id: \.self) { button(job.actions[$0], fillsWidth: true) }
        }
        #endif
    }

    private func button(_ action: JobPresentation.Action, fillsWidth: Bool) -> some View {
        Button(action.title) { perform(action) }
            .buttonStyle(SheetButtonStyle(action.isPrimary ? .primary : .bordered, fillsWidth: fillsWidth))
            .keyboardShortcut(shortcut(for: action))
            .help(action.help ?? "")
    }

    /// Stop takes ⌘., the default button Return, and the close button Escape.
    private func shortcut(for action: JobPresentation.Action) -> KeyboardShortcut? {
        if action == job.stopAction { return KeyboardShortcut(".", modifiers: .command) }
        if action == job.defaultAction { return .defaultAction }
        if action.role == .close, action == job.escapeAction { return .cancelAction }
        return nil
    }

    /// Escape on macOS when no close button takes it: stop while the job runs, else finish.
    private var exitCommand: (() -> Void)? {
        guard let escape = job.escapeAction, escape.role != .close else { return nil }
        let perform = perform
        return { MainActor.assumeIsolated { perform(escape) } }
    }
}

/// A job sheet as a `.sheet`'s content: it draws `job` while there is one, and once `job` is gone — the
/// view-model went idle as the sheet began to close — the last job it drew, so its words don't vanish
/// before the sheet does. The BIOS check's sheet and the library's scan and opening sheets present it.
public struct PresentedJobSheet: View {
    private let job: JobPresentation?
    private let perform: @MainActor (JobPresentation.Action) -> Void
    @State private var shown: JobPresentation?

    /// A sheet drawing `job`, or the last one it drew, calling `perform` with each button pressed.
    public init(_ job: JobPresentation?, perform: @escaping @MainActor (JobPresentation.Action) -> Void) {
        self.job = job
        self.perform = perform
        _shown = State(initialValue: job)
    }

    public var body: some View {
        Group {
            if let job = job ?? shown {
                JobSheet(job, perform: perform)
            }
        }
        .onChange(of: job) { _, job in
            if let job { shown = job }
        }
    }
}

/// One step: its symbol, or a spinner while it runs; its name and detail; and its state's word.
private struct StepRow: View {
    let step: JobPresentation.Step
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.space3) {
            symbol
            VStack(alignment: .leading, spacing: .zero) {
                Text(step.name)
                    .foregroundStyle(step.state == .pending ? Palette.secondaryText : Palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = step.detail {
                    Text(detail)
                        .textStyle(.caption)
                        .foregroundStyle(Palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let word = step.state.word {
                Text(word)
                    .textStyle(.caption)
                    .foregroundStyle(color)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(step.detail.map { "\(step.name), \($0)" } ?? step.name)
        .accessibilityValue(step.state.spokenWord)
    }

    /// The state's symbol; a running step's spinner takes the symbol's place and size, and under
    /// Reduce Motion the symbol stays.
    @ViewBuilder private var symbol: some View {
        let image = Image(systemName: step.state.symbol).imageScale(.large)
        if step.state == .running && !reduceMotion {
            image.hidden().overlay { ProgressView().controlSize(.small) }
        } else {
            image.foregroundStyle(color)
        }
    }

    private var color: Color {
        switch step.state {
        case .done: Palette.ok
        case .running: Palette.info
        case .failed: Palette.danger
        case .stopped: Palette.warning
        case .pending, .skipped: Palette.disabledText
        }
    }
}

/// One file's result: its outcome's symbol, its path and note, and the exact error if there is one.
private struct ResultRow: View {
    let result: JobPresentation.FileResult

    var body: some View {
        HStack(alignment: .top, spacing: Metrics.space2) {
            Image(systemName: result.outcome.symbol)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: .zero) {
                Text(result.file)
                    .textStyle(.caption, monospaced: true)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(result.note)
                    .textStyle(.caption)
                    .foregroundStyle(result.outcome == .failed ? Palette.danger : Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let code = result.code {
                Text(code)
                    .textStyle(.caption, monospaced: true)
                    .foregroundStyle(Palette.secondaryText)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var color: Color {
        switch result.outcome {
        case .added: Palette.ok
        case .skipped: Palette.secondaryText
        case .failed: Palette.danger
        }
    }
}

/// The design's sheet and alert buttons (`.btn`, `.btn-primary`, `.btn-danger` in html/main.html):
/// bordered on the control's fill, the accent's default button, and the destructive one, each with
/// its hover and pressed fills and the faint disabled look. The job sheet and the alert draw theirs
/// with it, and so does the player's paused overlay, whose Resume is the design's primary button.
public struct SheetButtonStyle: ButtonStyle {
    /// Which of the design's buttons.
    public enum Kind: Sendable {
        /// Bordered on the control's fill: Cancel, Close (`.btn`).
        case bordered
        /// The accent's default button: Resume, Done (`.btn-primary`).
        case primary
        /// The danger fill, for what can't be undone: Reset, Stop (`.btn-danger`).
        case destructive
    }

    let kind: Kind
    let fillsWidth: Bool

    /// A style drawing `kind`, as wide as its row allows when `fillsWidth`.
    public init(_ kind: Kind, fillsWidth: Bool = false) {
        self.kind = kind
        self.fillsWidth = fillsWidth
    }

    /// The button, drawn as `kind`.
    public func makeBody(configuration: Configuration) -> some View {
        SheetButton(label: configuration.label, isPressed: configuration.isPressed, kind: kind, fillsWidth: fillsWidth)
    }
}

/// One button drawn by `SheetButtonStyle`, which tracks the pointer for its hover fill.
private struct SheetButton: View {
    let label: ButtonStyleConfiguration.Label
    let isPressed: Bool
    let kind: SheetButtonStyle.Kind
    let fillsWidth: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.radiusControl)
        label
            .textStyle(.body, weight: kind == .bordered ? nil : .semibold)
            .lineLimit(1)
            .padding(.horizontal, Metrics.space3)
            .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: Metrics.layout.control)
            .foregroundStyle(foreground)
            .background(fill, in: shape)
            .overlay(shape.strokeBorder(edge))
            .contentShape(shape)
            .onHover { isHovered = $0 }
            .animation(Motion.animation(Motion.fast, reduceMotion: reduceMotion), value: isHovered)
            .animation(Motion.animation(Motion.fast, reduceMotion: reduceMotion), value: isPressed)
    }

    private var fill: Color {
        guard isEnabled else { return Palette.control }
        switch kind {
        case .bordered: return isPressed ? Palette.controlPressed : isHovered ? Palette.controlHover : Palette.control
        case .primary: return isPressed ? Palette.accentPressed : isHovered ? Palette.accentHover : Palette.accent
        case .destructive: return Palette.dangerSolid
        }
    }

    private var edge: Color {
        guard isEnabled else { return Palette.separator }
        return kind == .bordered ? Palette.controlBorder : fill
    }

    private var foreground: Color {
        guard isEnabled else { return Palette.disabledText }
        switch kind {
        case .bordered: return Palette.text
        case .primary: return Palette.onAccent
        case .destructive: return Palette.onDestructive
        }
    }
}

#if DEBUG
#Preview("Running") {
    JobSheet(PreviewJobs.running) { _ in }
}

#Preview("Stopped") {
    JobSheet(PreviewJobs.stopped) { _ in }
}

#Preview("Done") {
    JobSheet(PreviewJobs.done) { _ in }
}

#Preview("Failed") {
    JobSheet(PreviewJobs.failed) { _ in }
}

#Preview("Every step state") {
    JobSheet(PreviewJobs.everyStep) { _ in }
}

#Preview("Presented") {
    PresentedJobSheet(PreviewJobs.running) { _ in }
}
#endif
