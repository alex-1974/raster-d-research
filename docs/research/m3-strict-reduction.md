# M3.4 strict row-major reduction qualification

## Question and baseline

Research Issue #19 follows M3.1–M3.3 production handoffs. Pinned production:
`1671fb2e51a7b1e7311f78f575d9457e9f279fd4`. The existing public
`trySumFloatToDouble` already selects scalar Mir execution by validated layout;
it does not perform the checked per-sample public accessor traversal that
motivated the earlier point-transform/fill optimizations.

The semantic is one double accumulator, initially positive zero, adding each
float widened to double in logical row-major order. Fixed-lane4 is a distinct
internal operation graph and is not a strict optimization. A four-value
`[1e20f,1,-1e20f,1]` fixture must yield exactly 1.0 on every compared path.

Workspace context is absent under `.workspace/` in this clone; tracked and
supplied workspace rules were followed. Existing research-topic integration is
preserved at `research/m3-point-transform` merge
`8c0464d22255c63d82f31b8a76b3033e6dba77e4`.

## Controlled comparison

The generator pins full public/internal reduction modules by SHA256 and
preserves nine inherited tests per candidate, public attributes/signature,
plane-index failure with out-positive-zero, empty success before pointer
formation, original Universal traversal and unrelated fixed-lane semantics.
Only approved non-empty Canonical/contiguous execution differs:

| Path | Execution |
| --- | --- |
| Public | Production scalar Mir layout kernels |
| Pointer | Signed row pointers, one sequential double accumulator |
| Slice | Narrow trusted row slice construction, safe sequential sum |
| C++ | Already-validated descriptor strict execution reference |

No D candidate reassociates additions, creates row subtotals or independent
lanes, changes conversion precision, mutates/retains source or adds SIMD/threads.
Trust arguments use validated reachable signed row/index geometry. Actual-source
challenges compile trusted controls and reject safe pointer formation/indexing.

C++ has explicit plane-index/out-zero/empty behavior, one double accumulator and
no restrict promise. It omits D layout classification/Mir adaptation and adds
a separately compiled C ABI call. These differences are recorded rather than
claiming equal abstraction overhead or parity with an independent full raster
library. It uses GCC 13.3 with `-std=c++17 -O3 -fno-fast-math
-ffp-contract=off -fno-lto`, no explicit ISA setting. The D wrapper trusts only
the inspected bounded no-retention C++ call and scoped output. Both binaries
link the same object; neither D compiler can cross-inline it with LTO.

## Numerical and layout matrix

42 timed cases: sizes 31x17, 256x128 and 2048x512; contiguous, padded,
negative-row, Universal +2, negative rows/sample -2, repeated-row and both-zero
strides; positive and cancellation corpora. An independent storage-index oracle
reads the populated logical samples with one sequential accumulator. Repeated
mappings use their final populated physical value, preserving view semantics.

56 extra small semantic cases span those seven layouts with positive,
cancellation, deterministic finite exponent/sign, negative-zero, infinity,
opposite-infinity, explicit NaN-input and subnormal corpora. Finite results,
infinities and signed zeros compare bits; NaNs compare class because the public
strict contract makes no portable arithmetic-result payload promise. Source
fingerprints include padding/guards and are checked after every timed call.
Invalid plane, invalid empty plane, valid empty with null/extreme metadata,
out-positive-zero and the distinguishing cancellation graph are also checked.

Two warmups precede 12 timed samples per path. Cyclic order gives each of four
paths every position three times. Each actual operation runs independently of
assert; result/source checks follow outside timing. Six fixed-binary processes
produce 12,096 timed calls. Even-sample medians use integer nanoseconds, retaining
raw samples. Tiny zero durations are preserved and zero-median ratios omitted;
all large-case samples must be positive.

## Container evidence

EPYC VM, CPU affinity 0, unchanged host frequency/thermal controls. DMD 2.111.0,
LDC 1.41.0 / LLVM 20.1.5, DUB 1.40.0; GCC 13.3.0. Both compilers pass four
inherited unittest modules and actual-source trust challenges. All six processes
pass the 42 timed, 56 semantic and contract cases. Result/source fingerprints
match across all runs/compilers. Raw flags, object/binary hashes and disassembly
are preserved under `experiments/m3_strict_reduction/evidence/2026-10-01-container/`.

Across large contiguous/padded/negative/repeated rows and both timed corpora,
public/candidate median ratios span:

| Compiler | Pointer | Slice | C++ reference |
| --- | --- | --- | --- |
| DMD | 0.854–1.137x | 0.795–1.159x | 0.986–1.254x |
| LDC | 0.809–1.141x | 0.898–1.093x | 0.899–1.130x |

No D candidate consistently materially improves the existing execution form.
The C++ reference is in the same broad range, with the stated overhead
asymmetry; this is not a universal D/C++ parity claim. DMD candidate process
spread reaches 38.21% for Pointer and 20.70% for Slice; LDC reaches
24.22%/18.22%. Small relative deltas cannot select a new production executor.
Isolated actual-source D/C++ disassembly is retained to inspect the dependent
scalar addition graph; it is not used as a substitute for timing.

## Decision and next gate

| Question | Decision |
| --- | --- |
| Existing Production strict executor | KEEP; no justified change from VM evidence |
| Generic Pointer/Slice replacement | DEFER; no material stable gain established |
| Fixed-lane/reassociated/vector sum as strict | REJECT; different numeric semantic |
| Universal traversal | KEEP unchanged |
| C++ execution reference | KEEP with explicit wrapper/ABI limits |
| Compiler specialization, manual SIMD, threading | DEFER |
| Production PR | No implementation change proposed |
| XPS qualification | Required before closing performance audit |
| AArch64 performance | Unqualified |

`collect.sh OUTPUT_DIRECTORY CPU xps` repeats semantic/trust checks, the
separately compiled strict C++ reference and six process measurements. Targeted
CI pins production and checks correctness plus consumer diagnostics, without
performance thresholds. XPS may confirm KEEP-existing; no optimization must be
promoted merely because this milestone investigates performance.
