// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

/// What a job sheet shows: a job the app runs for a person — checking a BIOS, adding a folder of
/// games, opening a game, recording a trace — as its title, its steps, how far it has got, what came
/// of it and the buttons that act on it. A place's view-model builds one from its own state and the
/// `JobSheet` draws it. Every helper here is pure, so a view-model's tests can read them.
public struct JobPresentation: Sendable, Equatable {
    /// What the job does, the sheet's title: "Checking your BIOS".
    public var title: String
    /// What it does it to, under the title, such as the file's name; nil for none.
    public var subtitle: String?
    /// The job's steps, in order.
    public var steps: [Step]
    /// How far the running step has got; nil when it can't say.
    public var progress: Progress?
    /// One line on what came of the job, in its tone; nil while there is nothing to say.
    public var summary: Summary?
    /// What became of each file the job went through, such as each disc in a folder, in order.
    public var results: [FileResult]
    /// Exact text to show as it is, in monospaced type: the call that failed, or a tool's report.
    public var output: String?
    /// The sheet's buttons, in the order they're drawn: the default one last, as macOS lays them out.
    public var actions: [Action]

    /// A job as its view-model describes it.
    public init(
        title: String, subtitle: String? = nil, steps: [Step], progress: Progress? = nil,
        summary: Summary? = nil, results: [FileResult] = [], output: String? = nil, actions: [Action]
    ) {
        self.title = title
        self.subtitle = subtitle
        self.steps = steps
        self.progress = progress
        self.summary = summary
        self.results = results
        self.output = output
        self.actions = actions
    }

    // MARK: Steps

    /// One step of a job: what it does, a detail under it, and where it stands.
    public struct Step: Sendable, Equatable {
        /// What the step does: "Check its size".
        public var name: String
        /// A detail under the name — a size, a count, a fingerprint; nil for none.
        public var detail: String?
        /// Where the step stands.
        public var state: StepState

        /// A step, pending unless a state is given.
        public init(_ name: String, detail: String? = nil, state: StepState = .pending) {
            self.name = name
            self.detail = detail
            self.state = state
        }
    }

    /// Where one step stands, each drawn in its own symbol and color.
    public enum StepState: String, Sendable, CaseIterable {
        /// Not started yet.
        case pending
        /// Under way: drawn with a spinner.
        case running
        /// Finished and worked.
        case done
        /// Finished and didn't work; the job ends here.
        case failed
        /// Stopped by the person; the job ends here.
        case stopped
        /// Not needed this time.
        case skipped

        /// The word the sheet shows beside the step, in its color; a pending step shows none.
        public var word: String? {
            switch self {
            case .pending: nil
            case .running: "Working"
            case .done: "Done"
            case .failed: "Failed"
            case .stopped: "Stopped"
            case .skipped: "Skipped"
            }
        }

        /// What VoiceOver says for the step's state, a pending one's included.
        public var spokenWord: String {
            word ?? "Waiting"
        }

        /// The SF Symbol drawn for the step. A running step draws a spinner in its place, unless
        /// Reduce Motion is on.
        public var symbol: String {
            switch self {
            case .pending, .skipped: Symbols.pending
            case .running: Symbols.running
            case .done: Symbols.done
            case .failed: Symbols.failed
            case .stopped: Symbols.stopped
            }
        }
    }

    /// Where the job stands, read from its steps.
    public enum Status: String, Sendable, CaseIterable {
        /// No step has started.
        case waiting
        /// A step is running, or some are done and the rest still wait.
        case running
        /// Every step is done or skipped.
        case done
        /// A step failed.
        case failed
        /// A step was stopped.
        case stopped
    }

    /// Where the job stands: running while any step runs; else failed or stopped if a step ended so;
    /// waiting before any step starts; done once every step is done or skipped.
    public var status: Status {
        if steps.contains(where: { $0.state == .running }) { return .running }
        if steps.contains(where: { $0.state == .failed }) { return .failed }
        if steps.contains(where: { $0.state == .stopped }) { return .stopped }
        if steps.allSatisfy({ $0.state == .pending }) { return .waiting }
        if steps.allSatisfy({ $0.state == .done || $0.state == .skipped }) { return .done }
        return .running
    }

    /// Whether the job is still going, so Stop and ⌘. act on it.
    public var isRunning: Bool {
        status == .running
    }

    /// Whether the job has ended — done, failed or stopped — and the sheet waits for the person.
    public var isFinished: Bool {
        status == .done || status == .failed || status == .stopped
    }

    /// The index of the step the job is on, or the one it ended at: the running, failed or stopped
    /// step. Nil while the job waits, once it's done, or between steps.
    public var currentStep: Int? {
        steps.firstIndex { $0.state == .running || $0.state == .failed || $0.state == .stopped }
    }

    /// How many steps are done.
    public var completedSteps: Int {
        steps.count { $0.state == .done }
    }

    // MARK: Progress

    /// How far the running step has got — a fraction, or a count of a total — with what is counted
    /// and the words under the bar.
    public struct Progress: Sendable, Equatable {
        /// How far, as the job reports it.
        public enum Amount: Sendable, Equatable {
            /// A fraction from 0 to 1.
            case fraction(Double)
            /// So many of a total: 24 of 60 frames.
            case count(Int, of: Int)
        }

        /// How far.
        public var amount: Amount
        /// What is counted, as VoiceOver names the bar: "Frames run".
        public var label: String
        /// The line under the bar: "24 of 60 frames".
        public var text: String

        /// A job's progress.
        public init(_ amount: Amount, label: String, text: String) {
            self.amount = amount
            self.label = label
            self.text = text
        }

        /// How far along, from 0 to 1, for the bar: values outside are clamped, and a count of no
        /// total, or a fraction that isn't a number, is 0.
        public var fraction: Double {
            switch amount {
            case .fraction(let value):
                return value.isNaN ? 0 : min(max(value, 0), 1)
            case .count(let done, let total):
                guard total > 0 else { return 0 }
                return Double(min(max(done, 0), total)) / Double(total)
            }
        }
    }

    // MARK: Outcomes

    /// One line on what came of the job, in its tone: "Your BIOS works: it reached its shell."
    public struct Summary: Sendable, Equatable {
        /// The line, in plain words.
        public var text: String
        /// How it's drawn: ok for a job that worked, warning for a stop, danger for a failure.
        public var tone: Tone

        /// A summary line.
        public init(_ text: String, tone: Tone) {
            self.text = text
            self.tone = tone
        }
    }

    /// What became of one file the job went through, such as one disc of a folder.
    public struct FileResult: Sendable, Equatable {
        /// What became of it.
        public enum Outcome: String, Sendable, CaseIterable {
            /// Added to the library.
            case added
            /// Left as it was, such as a game already in the library.
            case skipped
            /// Couldn't be used.
            case failed

            /// The SF Symbol drawn beside the file.
            public var symbol: String {
                switch self {
                case .added: Symbols.done
                case .skipped: Symbols.pending
                case .failed: Symbols.failed
                }
            }
        }

        /// The file's path from where the job looked: "PS1/Tidepool/Tidepool.m3u".
        public var file: String
        /// What became of it, or why not, in plain words: "Added · PS1 · SLUS-00920 · 3 discs".
        public var note: String
        /// The exact error, in monospaced type, such as "DiscError.truncated"; nil for none.
        public var code: String?
        /// What became of it.
        public var outcome: Outcome

        /// One file's result.
        public init(_ file: String, outcome: Outcome, note: String, code: String? = nil) {
            self.file = file
            self.outcome = outcome
            self.note = note
            self.code = code
        }
    }

    /// How many of the job's files came to `outcome`, for the summary's tally.
    public func resultCount(_ outcome: FileResult.Outcome) -> Int {
        results.count { $0.outcome == outcome }
    }

    // MARK: Buttons

    /// One of the sheet's buttons: its title, and the role that says how it's drawn and which key
    /// presses it. The sheet hands the button pressed back to the view-model.
    public struct Action: Sendable, Equatable {
        /// What a button does to the job.
        public enum Role: String, Sendable, CaseIterable {
            /// Stops the running job — "Stop", or "Cancel" while a game opens: bordered, bound to ⌘.
            case stop
            /// Closes the sheet once the job has stopped or failed — "Close", "Cancel", "Done":
            /// bordered, bound to Escape.
            case close
            /// Closes the sheet once the job worked — "Done", "Continue": the accent's default button.
            case finish
            /// Starts the job again, or another way — "Choose Another File…", "Check Again", "Scan
            /// Again": the accent's default button.
            case retry
        }

        /// The button's title, in title case.
        public var title: String
        /// What it does to the job.
        public var role: Role

        /// A button.
        public init(_ title: String, role: Role) {
            self.title = title
            self.role = role
        }

        /// Whether the button is drawn in the accent, as the sheet's default: finish and retry.
        public var isPrimary: Bool {
            role == .finish || role == .retry
        }

        /// The tooltip naming the button's shortcut, "Stop (⌘.)", for the stop button; nil for the others.
        public var help: String? {
            role == .stop ? "\(title) (⌘.)" : nil
        }
    }

    /// The button ⌘. presses: the stop button, if the sheet has one.
    public var stopAction: Action? {
        actions.first { $0.role == .stop }
    }

    /// The button Return presses: the first finish or retry button.
    public var defaultAction: Action? {
        actions.first(where: \.isPrimary)
    }

    /// The button Escape presses, as the design has it: the close button; else, while the job runs,
    /// the stop button; else the finish button. Nil when none of them is there.
    public var escapeAction: Action? {
        if let close = actions.first(where: { $0.role == .close }) { return close }
        if isRunning { return stopAction }
        return actions.first { $0.role == .finish }
    }
}

extension Array where Element == JobPresentation.Step {
    /// These steps as a job that has reached the step at `current` shows them: the steps before it
    /// done, it in `state`, the steps after it pending, names and details kept. A `current` past the
    /// last step leaves every step done; one before the first leaves every step pending.
    public func reaching(_ current: Int, as state: JobPresentation.StepState) -> [JobPresentation.Step] {
        enumerated().map { index, step in
            var step = step
            step.state = index < current ? .done : index > current ? .pending : state
            return step
        }
    }
}
