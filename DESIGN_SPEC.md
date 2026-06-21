# AXI4 512-bit to 256-bit Downsizer Design Specification

## Overview

`axi512_to_axi256` is a standalone AXI4 data-width downsizer. It accepts a
512-bit slave-side AXI4 interface and emits equivalent 256-bit master-side AXI4
transactions. The address width is 48 bits by default.

The implementation is intentionally small and readable for integration tests and
FPGA-oriented simulation. It supports reads, writes, bursts, unaligned starts,
narrow transfers, byte strobes, backpressure, and bounded outstanding command
queues.

## Interface and Parameters

Default parameters:

- `ADDR_WIDTH = 48`
- `S_DATA_WIDTH = 512`
- `M_DATA_WIDTH = 256`
- `ID_WIDTH = 4`
- `OUTSTANDING = 4`

Implemented channels:

- Slave input side: `s_aw*`, `s_w*`, `s_b*`, `s_ar*`, `s_r*`
- Master output side: `m_aw*`, `m_w*`, `m_b*`, `m_ar*`, `m_r*`

Reset is active-low and synchronous: `aresetn`.

## Behavior

The bridge maps each 512-bit logical beat into the lower and/or upper 256-bit
half needed by the active byte lanes.

Write path:

- Accepts up to `OUTSTANDING` AW commands.
- Pairs W data with AW commands in AXI4 order.
- Emits one single-beat 256-bit downstream write for each non-empty half.
- Emits one 256-bit downstream burst for each slave-side write burst when the
  address sequence is representable with 256-bit beats.
- Preserves byte enables by slicing the 512-bit `WSTRB` into the matching
  256-bit output beat.
- Aggregates downstream `BRESP` values and returns the worst response on the
  slave-side B channel with the original ID.

Read path:

- Accepts up to `OUTSTANDING` AR commands.
- Emits one 256-bit downstream read burst for each slave-side read burst when
  the address sequence is representable with 256-bit beats.
- Reassembles returned 256-bit data into the correct half of the 512-bit
  slave-side `RDATA`.
- Aggregates downstream `RRESP` values and returns the worst response.

Burst handling:

- `INCR`, `FIXED`, and `WRAP` address progression are implemented.
- Downstream transactions are emitted as 256-bit bursts with `AxLEN` covering
  the required lower/upper half-beats instead of issuing one command per half.
- For unaligned multi-beat `INCR` bursts, the first transfer may be partial up
  to the next `AxSIZE` boundary; later transfers advance from the aligned
  boundary and use the full `AxSIZE` byte span.
- If a slave-side write burst cannot be represented as one continuous 256-bit
  output transaction, the bridge splits it into multiple output write
  transactions and returns one aggregated slave-side `BRESP`.

Ordering:

- Command queues allow several AW and AR requests to be accepted before previous
  requests finish.
- Write data is paired with AW commands in order, as required by AXI4.
- IDs are preserved on downstream requests and upstream responses.

## Limitations

- AXI user, region, lock, cache, protection, and QoS sideband signals are not
  included.
- The design favors correctness and simple verification over maximum throughput.
- Write data remains paired with accepted AW commands in order, matching AXI4's
  lack of a WID signal.

## Verification

The self-checking testbench covers:

- W01 aligned full-width single write: one output `INCR` burst, `AWLEN=1`,
  two 256-bit W beats, full strobes, correct `WLAST`.
- W02 unaligned 32-byte single write crossing the 256-bit boundary: one output
  `INCR` burst, `AWLEN=1`, strobes `FF00_0000` then `00FF_FFFF`.
- W03 aligned two-beat 512-bit write burst: one output `INCR` burst,
  `AWLEN=3`, four 256-bit W beats.
- W04 narrow `FIXED` write burst: preserves `AWBURST=FIXED` and repeated
  output address.
- W05 legal `WRAP` write burst: preserves `AWBURST=WRAP` and verifies wrapped
  256-bit output address sequence.
- W06 write error propagation: downstream `SLVERR` is returned as slave-side
  `BRESP`.
- W07 unaligned multi-beat `INCR` write burst: first transfer is partial,
  second transfer is aligned and full-size; output is split into two
  transactions at `0x9000` and `0x9040`.
- R01 aligned full-width single read: one output `INCR` burst, `ARLEN=1`, two
  256-bit R beats reassembled into one 512-bit R beat.
- R02 unaligned 32-byte single read crossing the 256-bit boundary: one output
  `INCR` burst, `ARLEN=1`.
- R03 unaligned multi-beat `INCR` read burst: first transfer is partial, second
  transfer is aligned and full-size; output `ARLEN=3` covers the four 256-bit
  read beats.
- R04 narrow aligned read: one 256-bit output beat and correct slave-side
  response.
- R05 read error propagation: downstream `SLVERR` is returned as slave-side
  `RRESP`.
- R06 queued outstanding reads with slave-side backpressure: two AR commands are
  accepted and completed in ID/order expected by the test.
- T01 reset behavior: reset clears counters, valid flags, and model state
  before the test starts and again at the end.
- T02 waveform generation: `tb_axi512_to_axi256.vcd` is dumped for GTKWave.

Run:

```sh
iverilog -g2005-sv -o tb_axi512_to_axi256.vvp axi512_to_axi256.v tb_axi512_to_axi256.v
vvp tb_axi512_to_axi256.vvp
```

Expected result:

```text
PASS: axi512_to_axi256 self-test completed
```
