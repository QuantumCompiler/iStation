// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

import PresentationStyles
import Testing

/// The job sheet's value: where a job stands, read from its steps; how far it has got; and which
/// button each key presses, over the design's own jobs (html/main.html's jobView).
@Suite("A job's presentation says where it stands and which key presses which button")
struct JobPresentationTests {
    typealias Step = JobPresentation.Step
    typealias Action = JobPresentation.Action

    static let names = ["Read the file", "Check its size", "Work out its fingerprint", "Power on and run 60 frames"]

    static func job(_ states: [JobPresentation.StepState], actions: [Action] = []) -> JobPresentation {
        JobPresentation(title: "Checking your BIOS", steps: states.enumerated().map { Step(names[$0.offset % names.count], state: $0.element) }, actions: actions)
    }

    // MARK: Steps

    @Test("Reaching a step makes the ones before it done and the ones after it pending, keeping names and details")
    func reachingAStep() {
        let steps = [Step("Read the file", detail: "524,288 bytes"), Step("Check its size"), Step("Power on"), Step("Reach its shell")]
        #expect(steps.reaching(2, as: .running).map(\.state) == [.done, .done, .running, .pending])
        #expect(steps.reaching(0, as: .failed).map(\.state) == [.failed, .pending, .pending, .pending])
        #expect(steps.reaching(1, as: .stopped).map(\.state) == [.done, .stopped, .pending, .pending])
        #expect(steps.reaching(2, as: .running).map(\.name) == steps.map(\.name))
        #expect(steps.reaching(2, as: .running).first?.detail == "524,288 bytes")
    }

    @Test("Reaching past the last step leaves them all done; before the first, all pending")
    func reachingTheEnds() {
        let steps = Self.names.map { Step($0) }
        #expect(steps.reaching(steps.count, as: .done).allSatisfy { $0.state == .done })
        #expect(steps.reaching(steps.count + 3, as: .running).allSatisfy { $0.state == .done })
        #expect(steps.reaching(-1, as: .running).allSatisfy { $0.state == .pending })
        #expect([Step]().reaching(0, as: .running).isEmpty)
    }

    @Test("A step is pending until a state is given")
    func aStepStartsPending() {
        #expect(Step("Read the file").state == .pending)
        #expect(Step("Read the file").detail == nil)
    }

    @Test("Each state has the design's word and symbol, and a pending step's word is only spoken", arguments: [
        (JobPresentation.StepState.pending, nil as String?, "Waiting", "pending"),
        (.running, "Working", "Working", "spinner"), (.done, "Done", "Done", "checkCircle"),
        (.failed, "Failed", "Failed", "error"), (.stopped, "Stopped", "Stopped", "stopCircle"),
        (.skipped, "Skipped", "Skipped", "pending"),
    ])
    func eachStateHasItsWordAndSymbol(state: JobPresentation.StepState, word: String?, spoken: String, icon: String) {
        #expect(state.word == word)
        #expect(state.spokenWord == spoken)
        #expect(state.symbol == Symbols.icons.first { $0.icon == icon }?.name)
    }

    // MARK: Status

    @Test("Where a job stands is read from its steps", arguments: [
        ([JobPresentation.StepState](), JobPresentation.Status.waiting),
        ([.pending, .pending], .waiting),
        ([.done, .running, .pending], .running),
        ([.done, .pending], .running),
        ([.done, .done], .done),
        ([.done, .skipped, .done], .done),
        ([.done, .failed, .pending], .failed),
        ([.done, .stopped, .pending], .stopped),
        ([.failed, .running], .running),
    ])
    func statusIsReadFromTheSteps(states: [JobPresentation.StepState], status: JobPresentation.Status) {
        #expect(Self.job(states).status == status)
    }

    @Test("A job runs until it is done, failed or stopped, and is finished only then")
    func runningAndFinished() {
        for status in JobPresentation.Status.allCases {
            let states: [JobPresentation.StepState] = switch status {
            case .waiting: [.pending]
            case .running: [.done, .running]
            case .done: [.done, .done]
            case .failed: [.done, .failed]
            case .stopped: [.done, .stopped]
            }
            let job = Self.job(states)
            #expect(job.status == status)
            #expect(job.isRunning == (status == .running))
            #expect(job.isFinished == (status == .done || status == .failed || status == .stopped))
        }
    }

    @Test("The current step is the running, failed or stopped one; none while waiting or once done")
    func theCurrentStep() {
        #expect(Self.job([.done, .done, .running, .pending]).currentStep == 2)
        #expect(Self.job([.done, .failed, .pending]).currentStep == 1)
        #expect(Self.job([.stopped, .pending]).currentStep == 0)
        #expect(Self.job([.pending, .pending]).currentStep == nil)
        #expect(Self.job([.done, .done]).currentStep == nil)
        #expect(Self.job([.done, .done, .running, .pending]).completedSteps == 2)
        #expect(Self.job([.done, .skipped, .done]).completedSteps == 2)
    }

    // MARK: Progress

    @Test("Progress is a fraction from 0 to 1, clamped, and 0 when it can't be worked out", arguments: [
        (JobPresentation.Progress.Amount.count(24, of: 60), 0.4),
        (.count(60, of: 60), 1), (.count(0, of: 60), 0), (.count(75, of: 60), 1), (.count(-3, of: 60), 0),
        (.count(5, of: 0), 0), (.count(5, of: -2), 0),
        (.fraction(0.25), 0.25), (.fraction(1.5), 1), (.fraction(-0.2), 0), (.fraction(.nan), 0),
    ])
    func progressIsAClampedFraction(amount: JobPresentation.Progress.Amount, fraction: Double) {
        let progress = JobPresentation.Progress(amount, label: "Frames run", text: "")
        #expect(abs(progress.fraction - fraction) < 1e-12)
    }

    @Test("Results are tallied by outcome")
    func resultsAreTallied() {
        var job = Self.job([.done, .stopped])
        job.results = [
            JobPresentation.FileResult("PS1/Harbor Lights (USA).cue", outcome: .skipped, note: "Already in your library"),
            JobPresentation.FileResult("PS1/Tidepool/Tidepool.m3u", outcome: .added, note: "Added · PS1 · SLUS-00920 · 3 discs"),
            JobPresentation.FileResult("Homebrew/gpu-test.exe", outcome: .added, note: "Added · PS-EXE · no serial"),
            JobPresentation.FileResult("Backups/half-copy.cue", outcome: .failed, note: "This disc image ends early.", code: "DiscError.truncated"),
        ]
        #expect(job.resultCount(.added) == 2)
        #expect(job.resultCount(.skipped) == 1)
        #expect(job.resultCount(.failed) == 1)
        #expect(JobPresentation.FileResult.Outcome.added.symbol == Symbols.done)
        #expect(JobPresentation.FileResult.Outcome.skipped.symbol == Symbols.pending)
        #expect(JobPresentation.FileResult.Outcome.failed.symbol == Symbols.failed)
    }

    // MARK: Buttons

    @Test("Finish and retry are the accent's default buttons; only Stop names its shortcut")
    func buttonRoles() {
        #expect(Action("Done", role: .finish).isPrimary)
        #expect(Action("Check Again", role: .retry).isPrimary)
        #expect(!Action("Stop", role: .stop).isPrimary)
        #expect(!Action("Close", role: .close).isPrimary)
        #expect(Action("Stop", role: .stop).help == "Stop (⌘.)")
        #expect(Action("Cancel", role: .stop).help == "Cancel (⌘.)")
        #expect(Action("Close", role: .close).help == nil)
        #expect(Action("Continue", role: .finish).help == nil)
    }

    @Test("While a job runs, ⌘. and Escape press Stop, and nothing is the default")
    func whileRunning() {
        let stop = Action("Stop", role: .stop)
        let job = Self.job([.done, .running, .pending], actions: [stop])
        #expect(job.stopAction == stop)
        #expect(job.defaultAction == nil)
        #expect(job.escapeAction == stop)

        let cancel = Action("Cancel", role: .stop)
        let opening = Self.job([.done, .running], actions: [cancel])
        #expect(opening.stopAction == cancel)
        #expect(opening.escapeAction == cancel)
    }

    @Test("After a failure or a stop, Return retries and Escape closes")
    func afterAFailureOrAStop() {
        let cancel = Action("Cancel", role: .close)
        let chooseAnother = Action("Choose Another File…", role: .retry)
        let failed = Self.job([.done, .failed, .pending], actions: [cancel, chooseAnother])
        #expect(failed.defaultAction == chooseAnother)
        #expect(failed.escapeAction == cancel)
        #expect(failed.stopAction == nil)

        let close = Action("Close", role: .close)
        let checkAgain = Action("Check Again", role: .retry)
        let stopped = Self.job([.done, .stopped], actions: [close, checkAgain])
        #expect(stopped.defaultAction == checkAgain)
        #expect(stopped.escapeAction == close)
    }

    @Test("Once a job worked, Return and Escape both finish")
    func onceItWorked() {
        let continueButton = Action("Continue", role: .finish)
        let done = Self.job([.done, .done], actions: [continueButton])
        #expect(done.defaultAction == continueButton)
        #expect(done.escapeAction == continueButton)
        #expect(Self.job([.done, .done], actions: [Action("Check Again", role: .retry)]).escapeAction == nil)
        #expect(Self.job([.done, .done]).escapeAction == nil)
    }
}
