import DataCatalog
import Foundation
import Testing

@Suite struct GameTests {
    @Test func aPathGameIsKeyedByConsoleAndPath() {
        let url = URL(fileURLWithPath: "/Games/PS2/./a.iso")
        let game = Game(title: "A", serial: nil, platform: .ps2, location: url, bootTarget: .path(url))
        #expect(game.id == "ps2:/Games/PS2/a.iso")
    }

    @Test func anInstalledPS3GameIsKeyedByTitleID() {
        let game = Game(
            title: "T", serial: "NPUB30000", platform: .ps3,
            location: URL(fileURLWithPath: "/x"), bootTarget: .rpcs3TitleID("NPUB30000")
        )
        #expect(game.id == "ps3:id:NPUB30000")
    }

    @Test func everyConsoleHasDistinctNames() {
        #expect(Set(Platform.allCases.map(\.shortName)).count == Platform.allCases.count)
        #expect(Set(Platform.allCases.map(\.displayName)).count == Platform.allCases.count)
    }
}
