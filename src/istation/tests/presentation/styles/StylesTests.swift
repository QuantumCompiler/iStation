import PresentationStyles
import Testing

@Suite struct StylesTests {
    @Test func theScreenIsFourByThree() {
        #expect(abs(Metrics.screenAspectRatio * 3 - 4) < 1e-9)
        #expect(abs(Metrics.playerMinWidth * 3 - Metrics.playerMinHeight * 4) < 1e-9)
    }

    @Test func symbolsAreDistinct() {
        #expect(Symbols.nothingToPlay != Symbols.acknowledgements)
    }
}
