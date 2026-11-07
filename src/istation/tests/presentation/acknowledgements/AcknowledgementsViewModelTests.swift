import Foundation
import PresentationAcknowledgements
import Testing

@MainActor
@Suite struct AcknowledgementsViewModelTests {
    @Test func withNoEntriesTheScreenSaysSo() {
        let screen = AcknowledgementsViewModel()
        #expect(screen.state == .empty)
        #expect(screen.emptyMessage == "iStation includes no third-party code yet.")
    }

    @Test func entriesAreListedInOrder() {
        let entries = ["First", "Second"].map {
            Acknowledgement(name: $0, licence: "MIT", notice: "Notice", source: URL(fileURLWithPath: "/\($0)"))
        }
        let screen = AcknowledgementsViewModel(entries: entries)
        #expect(screen.state == .listed)
        #expect(screen.entries.map(\.name) == ["First", "Second"])
    }
}
