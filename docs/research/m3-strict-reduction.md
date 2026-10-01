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

## XPS confirmation

The uploaded 2026-10-01 archive is preserved byte-exact under
`experiments/m3_strict_reduction/evidence/2026-10-01-xps/`, with archive SHA256
and collector commit in its additional PROVENANCE.md. All 19 manifest checks
pass; the original summary reproduces byte-for-byte. Both compilers pass four
inherited unittest modules and the actual-source Pointer/Slice trust challenges.
All six processes pass all 42 timed, 56 semantic and contract cases, with
matching finite result bits and backing fingerprints.

Dell XPS 15 / Intel i7-9750H, affinity CPU 0, unchanged frequency/thermal
controls; DMD 2.111.0, LDC 1.41.0 / LLVM 19.1.7, DUB 1.40.0, G++ 15.2.0.
The VM used LLVM 20.1.5 and G++ 13.3.0. Cross-host differences therefore mix
hardware, backend and C++ compiler changes; they do not isolate a CPU effect.

Large Canonical ratios (public time divided by candidate time; above 1 means
the candidate is faster):

| Compiler | Pointer | Slice | C++ reference |
| --- | --- | --- | --- |
| DMD | 0.992–1.151x | 0.879–1.050x | 1.010–1.170x |
| LDC | 0.982–1.022x | 0.978–1.020x | 0.981–1.024x |

LDC is near parity for all three references. DMD Pointer is near parity on
contiguous data, but every paired large padded/negative/repeated-row process
and both corpora favor it: public/Pointer 1.097–1.151x (about 8.8–13.1% less
time). This is a real follow-up signal, not a blanket no-gain conclusion.
DMD Slice loses on large contiguous data (0.879–0.913x, about 9.5–13.8% more
time), and offers only small/mixed changes elsewhere.

Across large Canonical cases, process spread maxima are 11.76%/12.64%/12.75%/
10.61% for DMD public/Pointer/Slice/C++; LDC is 7.94%/7.17%/7.30%/7.18%.
These are diagnostic spreads, not confidence intervals. The DMD advantage is
layout-specific, overlaps the scale of process variability, and was not stable
in the VM matrix. Promoting a general executor replacement is unjustified.
A DMD-only Canonical pointer specialization merits a separate controlled
confirmation before adding a compiler branch and trusted production kernel.
The C++ gap on DMD has the documented classification/ABI asymmetry; the
accepted trade-off is to keep the simpler existing executor for this audit,
with the measured DMD opportunity retained explicitly rather than claiming
universal C++ parity.

## Decision and follow-up

| Question | Decision |
| --- | --- |
| Existing Production strict executor | KEEP as the qualified default |
| Generic Pointer replacement | DEFER; no stable cross-matrix gain |
| Generic Slice replacement | REJECT for current promotion; DMD contiguous regression |
| DMD Canonical Pointer specialization | DEFER to controlled targeted confirmation |
| Fixed-lane/reassociated/vector sum as strict | REJECT; different numeric semantic |
| Universal traversal | KEEP unchanged |
| C++ execution reference | KEEP with explicit wrapper/ABI/compiler limits |
| Manual SIMD and threading | DEFER |
| Production PR | No implementation change proposed |
| XPS qualification | PASS; baseline audit complete, evidence ready for integration |
| AArch64 performance | Unqualified |

M3.4 establishes correctness and the current x86_64 strict-order performance
baseline. Its completion does not claim that every compiler-specific
optimization is exhausted. A later DMD specialization should isolate compiler
and layout, repeat independent processes under recorded frequency/thermal
conditions, retain contiguous/Universal controls, and pass the same semantic
and trust gates. Reopen a measured performance task if that study justifies
promotion. No optimization is required merely to close this audit.
