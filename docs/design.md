# Design notes

## Why a pointer cannot cross as plain binary

A synchronizer protects each bit separately. If a binary pointer goes from
`0111` to `1000`, four bits change together. A destination edge landing in that
window can capture any mix of old and new bits, including values the pointer
never held. A Gray code changes exactly one bit per increment, so the
destination sees either the old value or the new one.

This depends on two things:

1. The Gray value comes straight from a register, with no logic after it. A
   combinational binary-to-Gray converter in front of the synchronizer would
   glitch. Here `wgray` and `rgray` are registered next to the binary pointers.
2. Routing skew between the bits stays below one source clock period. That is a
   timing constraint, not something RTL or functional simulation can guarantee.
   See `constraints/async_fifo.xdc`.

## Synchronizer depth

The first flop may go metastable. Each further stage gives it another
destination period to resolve, and mean time between failures grows
exponentially with that settling time. Two stages are the usual choice;
`SYNC_STAGES` can be raised for fast clocks, at the cost of one cycle of flag
latency per extra stage.

## Full and empty

Pointers are `ADDR_WIDTH + 1` bits wide. The extra bit records wraparound.

* **Empty** (read domain): the read pointer equals the write pointer.
* **Full** (write domain): same address, opposite wrap bit. In binary only the
  MSB differs. In Gray code this becomes: the top **two** bits are inverted and
  the rest are equal.

Both flags are computed from the *next* local pointer and then registered, so
they assert on the same edge as the transfer that fills or empties the FIFO.

## Why stale pointers are safe

Each side compares its own current pointer with an old copy of the other one.

* The write side may think there is less free space than there really is. It can
  report full too long, but never too short, so it cannot overflow.
* The read side may think there is less data than there really is. It can report
  empty too long, but never too short, so it cannot underflow.

The same reasoning gives the level outputs their guarantee: `wlevel` is never
below the true occupancy and `rlevel` is never above it. Neither is exact while
traffic is in flight, so do not compare the two with each other.

## Reset

Resetting only one side of a dual-clock FIFO leaves the pointers inconsistent
and can show stale data as new. This design takes a single `arst_n` and runs it
through a reset synchronizer in each domain: assertion is immediate, release is
synchronous to each clock. The two domains leave reset at different times, which
is safe because the pointers are all zero and `wfull` and `rempty` reset high.
`wfull` resetting high means a write attempted during reset is refused rather
than silently lost.

## Read behaviour and memory

The read is first-word fall-through: `rdata` already shows the oldest word when
`rempty` is low. The asynchronous read maps to LUT RAM on Xilinx parts. A large
FIFO would be better in block RAM, which needs a registered read and an output
stage to keep the same interface. That variant is not implemented.
