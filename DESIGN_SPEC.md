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
- Suppresses downstream writes for halves whose `WSTRB` is zero.
- Aggregates downstream `BRESP` values and returns the worst response on the
  slave-side B channel with the original ID.

Read path:

- Accepts up to `OUTSTANDING` AR commands.
- Emits one single-beat 256-bit downstream read for each half touched by the
  requested transfer size and address.
- Reassembles returned 256-bit data into the correct half of the 512-bit
  slave-side `RDATA`.
- Aggregates downstream `RRESP` values and returns the worst response.

Burst handling:

- `INCR`, `FIXED`, and `WRAP` address progression are implemented.
- Downstream transactions are emitted as single 256-bit beats. This keeps the
  converter simple while preserving the slave-visible burst behavior.

Ordering:

- Command queues allow several AW and AR requests to be accepted before previous
  requests finish.
- Write data is paired with AW commands in order, as required by AXI4.
- IDs are preserved on downstream requests and upstream responses.

## Limitations

- AXI user, region, lock, cache, protection, and QoS sideband signals are not
  included.
- The design favors correctness and simple verification over maximum throughput.
- The downstream side receives single-beat 256-bit accesses rather than merged
  256-bit bursts.

## Verification

The self-checking testbench covers:

- Aligned full-width writes and reads.
- Narrow aligned transfers.
- Unaligned transfers crossing the 256-bit boundary.
- Multi-beat `INCR` bursts.
- `FIXED` and `WRAP` address progression.
- Basic backpressure.
- Multiple queued read and write commands.
- Downstream error propagation.
- Reset behavior.

Run:

```sh
iverilog -g2005-sv -o tb_axi512_to_axi256.vvp axi512_to_axi256.v tb_axi512_to_axi256.v
vvp tb_axi512_to_axi256.vvp
```

Expected result:

```text
PASS: axi512_to_axi256 self-test completed
```
