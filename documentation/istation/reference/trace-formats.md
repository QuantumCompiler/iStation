# The trace formats

The files every trace source writes and TraceKit (`DataTracing`, product `TraceKit`, personal builds only) reads, compares and reduces: the Swift port, ProjectPSX with trace logging, and SwanStation recorded from outside (v0.0.1 items 3d–3g). iStation's own format, MIT. Implemented in `src/istation/source/data/tracing/`, pinned byte for byte by `DataTracingTests` (version 1, 2026-11-07).

Every integer is **little-endian**. Every checksum is **FNV-1a 64**: start at `0xCBF29CE484222325`; for each byte, XOR it into the value, then multiply by `0x00000100000001B3` modulo 2⁶⁴. A 32-bit word is hashed as its four little-endian bytes.

## A trace file

A 16-byte header, then records, each a 1-byte tag followed by a fixed-size payload. A file ends after its last whole record; a partial record is an error.

### Header (16 bytes)

| Offset | Size | Field | Value |
|---|---|---|---|
| 0 | 4 | magic | `ISTR` (`49 53 54 52`) |
| 4 | 2 | version | `1` |
| 6 | 1 | granularity | `1` per instruction · `2` per frame |
| 7 | 1 | reserved | `0` |
| 8 | 4 | full-state interval | instruction traces: a full-state record after every this many instruction records; `0` for none |
| 12 | 4 | reserved | `0` |

### Instruction record — tag `0x01`, 24 bytes

One record per executed instruction, written after it completes, including any exception it raised. A branch's delay slot is its own record.

| Offset | Size | Field |
|---|---|---|
| 0 | 4 | PC: the instruction's address |
| 4 | 4 | the instruction word |
| 8 | 8 | the CPU's cycle count after it |
| 16 | 8 | the register checksum after it |

**The register checksum** is FNV-1a 64 over 37 words, in this order: the 32 general registers `r0`–`r31`, `HI`, `LO`, then COP0's `SR` (register 12), `CAUSE` (13) and `EPC` (14). All zeros give `0x63DFF573DC19F335`.

### Full-state record — tag `0x02`, 160 bytes

The whole CPU state, so a divergence can be read field by field. Written after every *n* instruction records when the header's interval is *n*, and on demand.

| Offset | Size | Field |
|---|---|---|
| 0 | 8 | cycle count |
| 8 | 4 | PC |
| 12 | 128 | `r0`–`r31`, 4 bytes each |
| 140 | 4 | `HI` |
| 144 | 4 | `LO` |
| 148 | 4 | COP0 `SR` |
| 152 | 4 | COP0 `CAUSE` |
| 156 | 4 | COP0 `EPC` |

### Frame record — tag `0x03`, 32 bytes

One record per video frame, at the end of the frame: what every source, SwanStation included, can see.

| Offset | Size | Field |
|---|---|---|
| 0 | 8 | frame number, from 0 at power-on |
| 8 | 8 | FNV-1a 64 over the 2 MB of guest RAM, byte by byte |
| 16 | 8 | FNV-1a 64 over the displayed image, or `0` when the source has no picture |
| 24 | 8 | FNV-1a 64 over the frame's audio samples, or `0` when there are none |

Until v0.1.0 defines the image's pixel format and v0.2.0 the audio's, those two checksums are compared only between sources that write them the same way; RAM is the gate's measure.

## Divergence

Two traces of the same granularity are compared record by record; the **first divergence** is the first index at which the records differ in kind or in any field, or at which one trace has ended. `TraceDiff` names the differing fields (`pc`, `word`, `cycles`, `registerChecksum`; `gpr[n]`, `hi`, `lo`, `sr`, `cause`, `epc`; `frame`, `ramChecksum`, `imageChecksum`, `audioChecksum`; `kind`; `end of trace`). A flag ignores cycle counts while timing is being ported; no gate uses it.

## A checkpoint file

A trace reduced to a few kilobytes, small enough to commit: one checksum per window of *w* records, so any changed record changes its window's checkpoint.

| Offset | Size | Field |
|---|---|---|
| 0 | 4 | magic `ISCK` (`49 53 43 4B`) |
| 4 | 2 | version `1` |
| 6 | 1 | the trace's granularity |
| 7 | 1 | reserved `0` |
| 8 | 4 | window *w*, in records |
| 12 | 8 | the trace's record count |
| 20 | 4 | checkpoint count |
| 24 | 16 each | per checkpoint: the index one past its window's last record (8), then FNV-1a 64 over the window's records' bytes, tags included (8) |

The last window may hold fewer than *w* records. 100,000 records at *w* = 512 reduce to 196 checkpoints, 3,160 bytes.
