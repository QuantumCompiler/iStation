// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2026 iStation contributors

#if DEBUG
import Foundation

/// Acknowledgements view-models for previews, over entries shaped like the acknowledgements list's,
/// held in memory: a preview never reads the bundled list.
@MainActor
enum PreviewAcknowledgements {
    static func empty() -> AcknowledgementsViewModel {
        AcknowledgementsViewModel()
    }

    static func listed() -> AcknowledgementsViewModel {
        AcknowledgementsViewModel(entries: [
            Acknowledgement(
                name: "iStation",
                licence: "MIT",
                notice: "MIT License\n\nCopyright (c) 2026 iStation contributors",
                source: URL(string: "https://github.com/QuantumCompiler/iStation")!
            ),
            Acknowledgement(
                name: "ProjectPSX",
                licence: "MIT",
                notice: "MIT License\n\nCopyright (c) 2019 Pedro Cortés",
                source: URL(string: "https://github.com/BluestormDNA/ProjectPSX")!
            ),
        ])
    }
}
#endif
