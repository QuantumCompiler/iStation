import Observation

/// The acknowledgements screen: every notice the app carries (ADR 0014).
///
/// A placeholder until the acknowledgements list exists (Architecture item A2); the screen's full
/// content is v1.0.0's.
@MainActor
@Observable
public final class AcknowledgementsViewModel {
    /// Each visibly different state of the screen.
    public enum State: Equatable, Sendable {
        /// The app carries no third-party code.
        case empty
        /// The app carries these notices.
        case listed
    }

    public private(set) var entries: [Acknowledgement]

    public init(entries: [Acknowledgement] = []) {
        self.entries = entries
    }

    public var state: State { entries.isEmpty ? .empty : .listed }

    /// What the screen says when there is nothing to list.
    public var emptyMessage: String { "iStation includes no third-party code yet." }
}
