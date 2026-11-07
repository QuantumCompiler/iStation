/// One video frame's guest-visible state: what every source — the Swift port, ProjectPSX and
/// SwanStation recorded from outside — can write (reference/trace-formats.md). 32 bytes after its tag.
public struct FrameRecord: Equatable, Sendable {
    /// The frame's number, counting from 0 at power-on.
    public var frame: UInt64
    /// FNV-1a 64 over the 2 MB of guest RAM at the end of the frame.
    public var ramChecksum: UInt64
    /// FNV-1a 64 over the displayed image, or 0 when the source has no picture.
    public var imageChecksum: UInt64
    /// FNV-1a 64 over the frame's audio samples, or 0 when there are none.
    public var audioChecksum: UInt64

    public init(frame: UInt64, ramChecksum: UInt64, imageChecksum: UInt64, audioChecksum: UInt64) {
        self.frame = frame
        self.ramChecksum = ramChecksum
        self.imageChecksum = imageChecksum
        self.audioChecksum = audioChecksum
    }

    static let tag: UInt8 = 0x03
    static let payloadSize = 32
}
