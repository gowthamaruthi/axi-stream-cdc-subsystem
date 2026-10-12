# Milestone 1 specification

Written before implementation, 2026-09-05. A streaming bridge, not a DMA engine.

## Scope

Two unrelated clocks: `s_clk` for AXI4-Stream ingress and AXI4-Lite, `m_clk` for stream egress. Fixed stream data 32 bits, `TKEEP` 4 bits, `TLAST` 1 bit; payload is preserved without interpretation, including zero TKEEP. Parameter `DEPTH` is a power of two >=4, default16. Storage capacity is exactly DEPTH beats, including sidebands. No TSTRB, TID, TDEST, TUSER, packet atomicity, memory-master port, interrupts, software flush or independent-domain resets.

Ingress accepts iff TVALID && TREADY at s_clk rising edge. Egress accepts iff TVALID && TREADY at m_clk rising edge. Output valid and payload remain stable while stalled, except during coordinated reset. Disabling ingress never withdraws a stalled egress beat. Upstream must hold its payload/valid under backpressure. Combinational FIFO head feeds egress; data is valid only with TVALID. No fixed cycle latency is promised across arbitrary clock ratios or stopped clocks.

## Reset / flush

One common active-low `rst_n` asserts reset asynchronously in both domains; each domain releases through a local two-flop reset synchronizer. Assert reset for at least two rising edges of each clock; resume clocks if stopped. Peers share coordinated reset and abandon outstanding stream/register transactions. Reset flushes all beats (including partial packets), clears counters and responses, and sets admission enabled. Memory is not erased. Never reset just one domain. No software flush exists in this milestone.

## AXI4-Lite subset

32-bit data, 8-bit byte address. AWPROT and ARPROT are present and ignored; no security/access distinction. One outstanding write response and one outstanding read response, concurrently supported. AW and W must be independently accepted/stored in either order. BVALID/BRESP and RVALID/RDATA/RRESP must hold while the receiver stalls. Ready may insert bubbles. Reads snapshot at AR acceptance; write side effects occur once both captured channels are present, before BVALID. Simultaneous read/write of one register returns its prior value (nonblocking update semantics).

| Byte address | Name | Access/reset | Definition |
|---|---|---|---|
| 0x00 | ID | RO / 0x43444301 | CDC milestone identifier |
| 0x04 | CONTROL | RW / 1 | bit0 admission enable; reserved bits read zero and writes ignored; only WSTRB[0] can affect bit0 |
| 0x08 | STATUS | RO | bit0 full in ingress domain; bit1 synchronized egress empty; bit2 admission enabled; upper bits zero |
| 0x0c | ACCEPTED | RO / 0 | number of accepted ingress beats, modulo 2^32; includes beats later discarded by reset, until reset clears it |
| 0x10 | SCRATCH | RW / 0 | 32-bit software scratch register, byte-wise WSTRB |

Successful accesses return OKAY (00). Writes to RO locations, unmapped addresses and any misaligned access return SLVERR (10), with no side effect. A zero-strobe write to a writable register returns OKAY and changes nothing. No DECERR/interconnect functionality.

CONTROL stays entirely in the ingress clock domain. Only the single-bit egress empty indication crosses back through two marked synchronizer flops; STATUS is an approximate, non-atomic diagnostic snapshot, not an exact occupancy count or flush handshake. FIFO Gray pointers cross in both directions; no unsynchronized multibit control/status bus crosses.

## Acceptance plan

Self-checking SystemVerilog with Icarus: accepted-event scoreboard for data, keep and last; concurrent source/sink; repeat wrap, long stalls/full, bursts, clock period changes/pauses, reset with pending data and AXI-Lite transactions; AW-first, W-first and simultaneous writes; response stalls; all strobe lanes and zero strobe; invalid/read-only/misaligned accesses; stream enable/drain/re-enable and ingress count. Check protocol stability while stalled. Nonzero exit on mismatch/watchdog. Run depths4/16 and deterministic seeds. Verilator lint and Yosys generic synthesis. Measure first-beat latency and sustained egress transfers only from simulation; do not infer Fmax, timing closure or board throughput. Reuse the repaired MIT FIFO with exact origin and source hash. Keep the milestone local for review.
