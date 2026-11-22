// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

#if DEBUG
/// Jobs for the job sheet's previews, as the design's prototype reports them (html/main.html's
/// BIOS check over BIOS_OK and BIOS_WRONG, and its folder scan over SCAN_FILES): made-up files and
/// the design's own figures, held in memory. A preview never reads a file.
enum PreviewJobs {
    /// The BIOS check's steps for a file of the right size.
    private static let biosSteps = [
        JobPresentation.Step("Read the file", detail: "524,288 bytes"),
        JobPresentation.Step("Check its size", detail: "A PS1 BIOS is 524,288 bytes (512 KB)"),
        JobPresentation.Step("Work out its fingerprint", detail: "SHA-1 3f9a 1c0e 52d4 88b0 e7a1 4c26 9d0f 51aa 7b21 c3e8"),
        JobPresentation.Step("Power on and run 60 frames", detail: "24 of 60 frames"),
        JobPresentation.Step("Reach the BIOS’s shell"),
    ]

    /// Checking a BIOS, 24 of its 60 frames run (the design's bios-checking).
    static let running = JobPresentation(
        title: "Checking your BIOS", subtitle: "my-console-bios.bin",
        steps: biosSteps.reaching(3, as: .running),
        progress: JobPresentation.Progress(.count(24, of: 60), label: "Frames run", text: "24 of 60 frames"),
        actions: [JobPresentation.Action("Stop", role: .stop)]
    )

    /// Adding a folder, stopped after 5 of its 9 discs (the design's scan-stopped).
    static let stopped = JobPresentation(
        title: "Adding games from ~/Games",
        steps: [
            JobPresentation.Step("Find disc images", detail: "9 found"),
            JobPresentation.Step("Read each disc", detail: "5 of 9"),
            JobPresentation.Step("Add them to your library"),
        ].reaching(1, as: .stopped),
        summary: JobPresentation.Summary("Stopped after 5 of 9. Added 3 games. 2 already in your library. Scan Again skips the games already added.", tone: .warning),
        results: [
            JobPresentation.FileResult("PS1/Harbor Lights (USA).cue", outcome: .skipped, note: "Already in your library"),
            JobPresentation.FileResult("PS1/Moonbase Courier.iso", outcome: .skipped, note: "Already in your library"),
            JobPresentation.FileResult("PS1/Tidepool/Tidepool.m3u", outcome: .added, note: "Added · PS1 · SLUS-00920 · 3 discs"),
            JobPresentation.FileResult("PS1/Glass Orchard (Europe).cue", outcome: .added, note: "Added · PS1 · SLES-02155"),
            JobPresentation.FileResult("Homebrew/gpu-test.exe", outcome: .added, note: "Added · PS-EXE · no serial"),
        ],
        actions: [JobPresentation.Action("Done", role: .close), JobPresentation.Action("Scan Again", role: .retry)]
    )

    /// A BIOS that worked (the design's bios-done).
    static let done = JobPresentation(
        title: "Checking your BIOS", subtitle: "my-console-bios.bin",
        steps: biosSteps.enumerated().map { index, step in
            index == 3 ? JobPresentation.Step(step.name, detail: "60 of 60 frames") : step
        }.reaching(biosSteps.count, as: .done),
        summary: JobPresentation.Summary("Your BIOS works: it reached its shell.", tone: .ok),
        actions: [JobPresentation.Action("Continue", role: .finish)]
    )

    /// A file of the wrong size (the design's bios-wrong-size).
    static let failed = JobPresentation(
        title: "Checking your BIOS", subtitle: "bios-backup.zip",
        steps: [
            JobPresentation.Step("Read the file", detail: "271,384 bytes"),
            JobPresentation.Step("Check its size", detail: "A PS1 BIOS is 524,288 bytes (512 KB)"),
            JobPresentation.Step("Work out its fingerprint"),
            JobPresentation.Step("Power on and run 60 frames"),
            JobPresentation.Step("Reach the BIOS’s shell"),
        ].reaching(1, as: .failed),
        summary: JobPresentation.Summary("This file is 271,384 bytes. A PS1 BIOS is exactly 524,288 bytes. Choose the BIOS file itself.", tone: .danger),
        output: "PS1Console.powerOn(bios:) threw PS1Error.biosSize(271384)",
        actions: [JobPresentation.Action("Cancel", role: .close), JobPresentation.Action("Choose Another File…", role: .retry)]
    )

    /// Every state a step can be in, as the Foundations-Components board's Job steps card draws them.
    static let everyStep = JobPresentation(
        title: "Job steps",
        steps: [
            JobPresentation.Step("Read the file", state: .done),
            JobPresentation.Step("Check its size", state: .running),
            JobPresentation.Step("Work out its fingerprint", state: .pending),
            JobPresentation.Step("Run 60 frames", state: .stopped),
            JobPresentation.Step("Check its size", state: .failed),
            JobPresentation.Step("Reach the BIOS’s shell", state: .skipped),
        ],
        progress: JobPresentation.Progress(.fraction(0.4), label: "Progress", text: "40 percent"),
        actions: []
    )
}
#endif
