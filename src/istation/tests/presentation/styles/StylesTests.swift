import DataCatalog
import PresentationStyles
import Testing

@Suite struct StylesTests {
    @Test func everyConsoleHasItsOwnSymbol() {
        let symbols = Platform.allCases.map(Symbols.console)
        #expect(Set(symbols).count == Platform.allCases.count)
    }

    @Test func everyConsoleHasItsOwnTint() {
        let tints = Platform.allCases.map { Palette.tint(for: $0).description }
        #expect(Set(tints).count == Platform.allCases.count)
    }

    @Test func tilesFitTheirGrid() {
        #expect(Metrics.tileMinWidth <= Metrics.tileMaxWidth)
        #expect(Metrics.coverAspectRatio < 1) // a game case is taller than wide
    }
}
