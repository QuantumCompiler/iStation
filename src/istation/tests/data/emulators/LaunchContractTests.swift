import DataCatalog
import DataEmulators
import Foundation
import Testing

/// Pins reference/emulator-launch-contract.md: each emulator's flags, as iStation passes them.
@Suite struct LaunchContractTests {
    private let iso = BootTarget.path(URL(fileURLWithPath: "/g/a.iso"))

    @Test func pcsx2() {
        let arguments = LaunchContract.arguments(for: .pcsx2, booting: iso, options: LaunchOptions(fullscreen: true, fastBoot: true))
        #expect(arguments == ["-batch", "-fullscreen", "-fastboot", "--", "/g/a.iso"])
    }

    @Test func duckStationWindowedWithBIOSIntro() {
        let arguments = LaunchContract.arguments(for: .duckstation, booting: iso, options: LaunchOptions(fullscreen: false, fastBoot: false))
        #expect(arguments == ["-batch", "--", "/g/a.iso"])
    }

    @Test func aPathStartingWithADashStillBoots() {
        let target = BootTarget.path(URL(fileURLWithPath: "/g/-weird.iso"))
        let arguments = LaunchContract.arguments(for: .pcsx2, booting: target, options: LaunchOptions(fullscreen: false, fastBoot: false))
        #expect(arguments.suffix(2) == ["--", "/g/-weird.iso"])
    }

    @Test func rpcs3InstalledTitle() {
        let arguments = LaunchContract.arguments(
            for: .rpcs3, booting: .rpcs3TitleID("NPUB30000"), options: LaunchOptions(fullscreen: false, fastBoot: true)
        )
        #expect(arguments == ["--no-gui", "%RPCS3_GAMEID%:NPUB30000"])
    }

    @Test func rpcs3DiscFolderFullscreen() {
        let folder = BootTarget.path(URL(fileURLWithPath: "/g/BLUS30443"))
        let arguments = LaunchContract.arguments(for: .rpcs3, booting: folder, options: LaunchOptions())
        #expect(arguments == ["--no-gui", "--fullscreen", "/g/BLUS30443"])
    }

    @Test func eachEmulatorRunsItsOwnConsole() {
        #expect(EmulatorKind.allCases.map(\.platform) == [.ps1, .ps2, .ps3])
    }

    @Test func rpcs3KeepsInstalledGamesInApplicationSupport() {
        let folder = RPCS3Layout.installedGamesFolder(applicationSupport: URL(fileURLWithPath: "/h/Library/Application Support"))
        #expect(folder.path == "/h/Library/Application Support/rpcs3/dev_hdd0/game")
    }
}
