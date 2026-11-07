import BusinessPS1
import Testing

@Suite struct PS1ConsoleTests {
    @Test func aNewConsoleIsPoweredOff() {
        #expect(!PS1Console().isPoweredOn)
        #expect(PS1Console.name == "PlayStation")
    }
}
