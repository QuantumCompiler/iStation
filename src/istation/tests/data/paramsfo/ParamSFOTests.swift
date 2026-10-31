import DataParamSFO
import SupportDiscFixtures
import Testing

@Suite struct ParamSFOTests {
    @Test func readsStrings() throws {
        let sfo = try ParamSFO(bytes: makeSFO([
            ("CATEGORY", "DG"),
            ("TITLE", "Demon's Souls"),
            ("TITLE_ID", "BLUS30443"),
        ]))
        #expect(sfo.title == "Demon's Souls")
        #expect(sfo.titleID == "BLUS30443")
        #expect(sfo.category == "DG")
    }

    @Test func titleLineBreaksBecomeSpaces() throws {
        let sfo = try ParamSFO(bytes: makeSFO([("TITLE", "Line one\nLine two")]))
        #expect(sfo.title == "Line one Line two")
    }

    @Test func rejectsGarbage() {
        #expect(throws: ParamSFOError.self) {
            try ParamSFO(bytes: Array("not an sfo file at all".utf8))
        }
    }
}
