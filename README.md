# Parameterized Synchronous FIFO

A single-clock, synthesizable FIFO implemented in SystemVerilog. The design provides registered read data, occupancy tracking, full/empty flags and one-cycle overflow/underflow event pulses.

## Design status

| Item | Status |
|---|---|
| RTL | Implemented |
| Written specification | Included |
| Testbench | Not included |
| Assertions/functional coverage | Not included |

See [Sync_FIFO_Specification.md](Sync_FIFO_Specification.md) for the detailed design specification.

## Specification

| Property | Default |
|---|---:|
| Module | `fifo` |
| Data width | `DATA_WIDTH = 8` |
| Depth | `DEPTH = 16` |
| Clock domains | 1 |
| Reset | Synchronous, active low (`rst_n`) |
| Read output | Registered |
| Simultaneous read/write | Supported |

### Interface

| Port | Direction | Width | Description |
|---|---|---:|---|
| `clk` | Input | 1 | Rising-edge clock |
| `rst_n` | Input | 1 | Synchronous active-low reset |
| `wr_en` | Input | 1 | Write request |
| `wr_data` | Input | `DATA_WIDTH` | Write payload |
| `rd_en` | Input | 1 | Read request |
| `rd_data` | Output | `DATA_WIDTH` | Registered read payload |
| `rd_valid` | Output | 1 | Read accepted in the current clock event |
| `full` | Output | 1 | Occupancy equals `DEPTH` |
| `empty` | Output | 1 | Occupancy is zero |
| `data_count` | Output | `$clog2(DEPTH+1)` | Current occupancy |
| `overflow` | Output | 1 | Rejected write pulse |
| `underflow` | Output | 1 | Rejected read pulse |

## Transaction rules

```text
rd_accept = rd_en && !empty
wr_accept = wr_en && (!full || rd_accept)
next_count = data_count + wr_accept - rd_accept
```

- A read from an empty FIFO is rejected and raises `underflow` for one cycle.
- A write to a full FIFO is rejected unless a read is accepted in the same cycle.
- At full occupancy, simultaneous read and write keeps the count constant and accepts both operations.
- At empty occupancy, simultaneous read and write accepts only the write; this implementation has no fall-through/bypass path.
- `rd_data` changes only on an accepted read and otherwise holds its previous value.
- `rd_valid`, `overflow` and `underflow` are event pulses, not sticky status bits.

## RTL architecture

```text
wr_en/wr_data -> write acceptance -> memory -> read acceptance -> rd_data/rd_valid
                        |                         |
                        +---- pointer/count -----+
```

The storage array is `mem[0:DEPTH-1]`. Read and write pointers wrap explicitly at `DEPTH-1`, so non-power-of-two depths greater than one are supported by the pointer logic.

## Reset behavior

Reset is sampled only on `posedge clk`:

```text
rst_n = 0 at rising edge -> pointers/count/data/status outputs reset
```

The memory array itself is not cleared. Its contents are invalid while `empty=1` and are overwritten by future accepted writes.

## Verification plan

No executable testbench is currently committed. A minimum regression should include:

| Test | Main checks |
|---|---|
| Reset | Empty state, count zero, pulses low |
| Basic write/read | Ordering and registered read data |
| Fill/drain | Full/empty boundaries and pointer wrap |
| Overflow/underflow | Rejected request and one-cycle pulse |
| Simultaneous access | Count behavior at middle, full and empty occupancy |
| Random model test | Queue-based scoreboard across thousands of cycles |
| Parameter test | Multiple widths and non-power-of-two depths |

Recommended assertions include count bounds, mutual exclusion of `full`/`empty` for nonzero depth, flag/count consistency and pointer stability on rejected requests.

## Compile check

```bash
iverilog -g2012 -s fifo -o fifo_compile fifo.sv
```

## Parameter constraints

- Use `DEPTH >= 2`; `DEPTH=1` produces a zero-width pointer declaration in common tools.
- `DATA_WIDTH` and `DEPTH` must be positive integers.
- This is a synchronous FIFO and must not be used for clock-domain crossing.

