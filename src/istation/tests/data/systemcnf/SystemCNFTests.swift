@testable import DataSystemCNF
import Testing

@Suite struct SystemCNFTests {
    @Test func ps2BootLine() {
        let cnf = SystemCNF(text: "BOOT2 = cdrom0:\\SLUS_200.62;1\r\nVER = 1.00\r\nVMODE = NTSC\r\n")
        #expect(cnf?.console == .ps2)
        #expect(cnf?.serial == "SLUS-20062")
    }

    @Test func ps1BootLine() {
        let cnf = SystemCNF(text: "BOOT=cdrom:\\SCUS_944.55;1\nTCB=4\nEVENT=10\nSTACK=801FFFF0\n")
        #expect(cnf?.console == .ps1)
        #expect(cnf?.serial == "SCUS-94455")
    }

    @Test func nonStandardExecutableHasNoSerial() {
        let cnf = SystemCNF(text: "BOOT = cdrom:\\PSX.EXE;1")
        #expect(cnf?.console == .ps1)
        #expect(cnf?.serial == nil)
    }

    @Test func missingBootKey() {
        #expect(SystemCNF(text: "VMODE = PAL") == nil)
    }

    @Test func serialFromBootPath() {
        #expect(SystemCNF.serial(fromBootPath: "cdrom0:\\SLES_523.38;1") == "SLES-52338")
        #expect(SystemCNF.serial(fromBootPath: "cdrom:\\MAIN.EXE;1") == nil)
    }
}
