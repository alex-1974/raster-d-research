# M3.8 full public exact DMD vector conversion

Research Issue #28 continues parent #22 after measured pointer alternatives
PR #27. Production PR #61 is pinned at
`7dcdf01babf87e9a80af2864fbad75efe8e7d0ef`. No integration is assumed.
Container collection: 2026-10-03.

## Question and candidate

Can exact sixteen-byte packed conversion materially improve the full public
DMD operation while retaining the original LDC/portable expression? Compare
the original with two identical SSE2 unpack/conversion kernels differing in
how results are written: safe slice copies versus a bounded unaligned store.
The safe row dispatcher and all public validation, exact overlap fallback,
Universal traversal, empty/error/no-write behavior and Copy remain.

DigitalMars/X86_64 selects the explicit vector kernel. Other branches and
RasterForcePortable use the original scalar expression; forced portable tests
do not qualify other physical architectures. SSE2 load, unpack, conversion and
store suffice on the measured target. There is no AVX/SSE4, host tuning or
fast-math. Zero-extension produces int lanes in 0..255; numeric CVTDQ2PS is exact
in binary32 and yields positive zero. D vector type painting is not mistaken
for numeric conversion. Scalar tails preserve the original cast.

The new private read helper accepts precisely sixteen scoped bytes; the store
helper accepts precisely four scoped floats. Both access exactly their supplied
block without alignment requirements or escaping pointers. The safe row loop
proves each block bound. Original global sample-byte disjointness, backing,
injectivity and row-geometry validation remain prerequisites. Read and write
trust are independently challenged. The README retains the complete proof and
links primary D documentation; pinned compiler source and actual compilation
establish baseline support.

## Qualification and provenance

Both DMD 2.111.0 and LDC 1.41.0 (frontend 2.111.0 / LLVM 20.1.5) pass:

- 40 imported unittest modules, including inherited public/internal tests.
- Separate release full public fixtures: 72 conversion backing cases plus 96
  unchanged Copy controls and all original failure/no-write/empty/shared controls.
- Forced portable full public fixtures with the same semantic oracles.
- Nine further shared-backing cases with overlapping envelopes but disjoint
  samples, widths 16/17/31, default and forced portable. These activate vector
  blocks and tails rather than relying only on prior four-wide shared controls.
- Safe/pure/nothrow/nogc controls for all five row instantiations; complete-helper
  trust removal rejection on both compilers. DMD also rejects isolated kernel
  trust removal and independently removing each active load/store helper's trust.
- 10,240 isolated bitwise row cases per form/selection: forty widths, sixteen
  source byte offsets, four float offsets and four rounding modes. All byte values,
  positive zero, unchanged source and full destination guards are verified.
- Forty additional widths ending immediately at inaccessible source/destination
  pages, default and forced portable, detecting tail overread/overwrite.

DUB 1.40.0; local pristine mir-algorithm 3.22.4 at
`ecde2eb4ff41dc9d9dc6f71234d0838dccce22b4`, mir-core 1.7.4 at
`4397b03a804b0368100e99252016c7b32aa562d1`. The runner records resolved import paths
in exact commands; downstream collectors resolve Production's pinned DUB setup.
Host: AMD EPYC 9V74 container, affinity CPU 0. Frequency and thermal conditions
remain unchanged/unmonitored; no binary-placement sweep is performed.

Six processes per compiler, eighteen workloads, nine balanced cyclic rounds
and three paths retain 5,832 timed blocks / 8,475,840 full public calls. Every
block verifies full backing/source data outside timing, and workload fingerprints
match across forms/processes/compilers. Eight warmup calls per path/workload,
setup and logging are excluded. Validation and return/error handling remain
timed. One fixed binary per compiler is identified by SHA256. All 97 evidence
checksums verify; deterministic summary regeneration is byte-exact. The checksum
manifest excludes itself. Commands, versions, host, source/generated hashes,
selected public/linked assembly and controls are retained. Temporary paths may
change full-object identity hashes on replay.

## Runtime results

2048x512. Ratio is original/form, median of paired process medians; parentheses
show minimum–maximum paired process ratios. Larger than one favors the candidate.
These ranges are observed process values, not confidence intervals.

| Compiler | Layout | vector16safe | vector16store |
| --- | --- | --- | --- |
| dmd | contiguous | 0.820 (0.766–0.840) | 4.400 (4.154–4.541) |
| dmd | padded | 0.799 (0.757–0.843) | 4.342 (3.260–4.485) |
| dmd | negative-source | 0.794 (0.747–0.846) | 4.210 (3.243–4.401) |
| dmd | negative-both | 0.801 (0.750–0.843) | 4.132 (2.769–4.232) |
| dmd | repeated-source | 0.808 (0.764–0.850) | 4.420 (3.004–4.534) |
| dmd | universal | 1.009 (0.994–1.058) | 1.007 (0.988–1.036) |
| ldc2 | contiguous | 0.996 (0.985–1.005) | 1.003 (0.993–1.015) |
| ldc2 | padded | 1.010 (0.994–1.039) | 1.001 (0.989–1.025) |
| ldc2 | negative-source | 1.005 (1.001–1.021) | 1.002 (0.925–1.020) |
| ldc2 | negative-both | 0.996 (0.973–1.001) | 0.995 (0.985–1.003) |
| ldc2 | repeated-source | 1.012 (0.995–1.510) | 1.008 (0.991–1.508) |
| ldc2 | universal | 0.992 (0.962–1.019) | 0.998 (0.985–1.020) |

DMD vector16store shows a material scoped gain: median ratios 4.132–4.420 for
the five unit-sample-stride layouts. Every process favors it, but process ranges
are broad for several layouts. Large negative-both store spread is 55.452%;
large padded store spread 36.673%. Across all workloads, maximum DMD spread is
58.648% (medium contiguous store), maximum LDC spread 52.807% (large repeated
source original). Exact ratios and smaller effects require XPS qualification.
Universal traversal is unchanged and remains near one. LDC deliberately retains
its original scalar expression/autovectorization; large store-form medians
0.995–1.008 establish no substantive LDC optimization.

DMD vector16safe ratios are about 0.79–0.82 for the five large unit-stride layouts,
so this result-writing form is slower than original in the retained run.
Selected assembly shows packed conversion in both variants, but safe result
copies also contain extra bounds/overlap checks, stack stores and copying;
store-form assembly contains unaligned SIMD writes. This is a diagnostic
observation, not proof assigning all runtime change to one instruction.

## Reference XPS qualified — 2026-10-03

Uploaded archive: `raster-vector-xps-run-rORpT2.tar.gz`, SHA256
`565c6d4a935fdf33a6436609868c0fa37d3c598cc38cbe2ac6d64ba439ab0a45`.
All 103 extracted files are retained byte-for-byte under
`experiments/m3_conversion_vector/evidence/2026-10-03-xps/`.
Original collector manifest: 97 verified entries; launcher extended manifest:
102 verified entries, including the unchanged original `audit-SHA256SUMS` and
four supplementary toolchain/run/dependency files. The file set is complete.
Summary regeneration is byte-exact. Source pins and generated-source hashes
match the container byte-for-byte; all eighteen workload fingerprints also
match across hardware, forms, compilers and processes.

Reference hardware: Intel Core i7-9750H, affinity CPU 0, Linux 6.17.0-22,
glibc 2.43. DMD 2.111.0, LDC 1.41.0 / frontend 2.111.0 / LLVM 19.1.7, DUB 1.40.0,
Python 3.14.4, GNU objdump 2.46. Resolved dependencies: mir-algorithm 3.22.4,
mir-core 1.7.4, silly 1.1.1. LLVM/backend/host differ from the container; no
cross-machine absolute timing equality is assumed. Frequency and thermal
conditions are unchanged and unmonitored.

Both compiler families pass all forty inherited test modules, default/forced
portable public fixtures, all attribute/trust gates, isolated 10,240-case
bitwise/rounding/offset controls, forty guard-page widths and nine further
vector-active shared-backing cases. The twelve complete timing processes
retain 5,832 blocks and 8,475,840 public calls. No semantic mismatch is observed.

2048x512 XPS store-form results. Ratio is original/vector16store; the last
column measures store-form process-median spread. Larger ratios favor it.

| Compiler | Layout | Median ratio | Process ratio range | Store spread |
| --- | --- | --- | --- | --- |
| dmd | contiguous | 2.375 | 1.917–2.381 | 36.177% |
| dmd | padded | 3.045 | 2.963–3.114 | 16.435% |
| dmd | negative-source | 3.107 | 2.718–3.185 | 32.227% |
| dmd | negative-both | 3.073 | 2.926–3.196 | 46.330% |
| dmd | repeated-source | 3.124 | 3.044–3.144 | 11.345% |
| dmd | universal | 1.017 | 0.980–1.077 | 11.930% |
| ldc2 | contiguous | 1.011 | 0.978–1.040 | 9.468% |
| ldc2 | padded | 0.974 | 0.925–1.023 | 32.840% |
| ldc2 | negative-source | 1.001 | 0.968–1.009 | 7.469% |
| ldc2 | negative-both | 0.993 | 0.904–1.102 | 14.721% |
| ldc2 | repeated-source | 0.998 | 0.973–1.041 | 10.825% |
| ldc2 | universal | 1.007 | 0.972–1.027 | 14.351% |

The DMD gain persists on reference hardware: medians 2.375–3.124 across the
five unit-sample-stride layouts, and every corresponding process favors the
store form (smallest observed ratio 1.917 for contiguous). Medium 256x128
unit-stride medians are 2.373–3.157, also favorable in every process. These are
material scoped improvements, not the container's 4.132–4.420 factors.

Stability is limited: maximum DMD process spread is 46.330% (large negative-both
store), maximum LDC spread 36.209% (medium negative-source store). LDC large
store-form medians are 0.974–1.011, with process ratios crossing one; no LDC gain
or small regression is qualified from these differences. Its original scalar
expression/autovectorization remains selected. Universal execution is unchanged;
small timing differences cannot be attributed to the vector algorithm.

A concrete crossover problem remains. Small contiguous 31x17 DMD conversion
has original/store median ratio 0.904 (range 0.900–0.927); the candidate is
about 10.6% slower and every process favors original. Small non-flat unit-stride
medians are 1.120–1.131. The safe-copy vector form is rejected again: its five
large unit-stride DMD medians are 0.456–0.606. A blanket SIMD selection would
therefore hide an observed small-flat regression.

## Decision and remaining gates

Keep the SIMD-store kernel as a hardware-qualified Research candidate for the
measured medium/large DMD unit-stride workloads. Do not promote the current
unconditional row selection into Production PR61. First measure a controlled
width/size crossover and qualify a conservative internal selection preserving
the original small-flat path. The three retained sizes do not establish an
optimal threshold. Keep safe-copy as a measured rejected alternative.

A fresh scoped C++ execution comparison remains necessary before claiming the
C++ gap closed. No C++ executor is timed here; historical C++ ratios must not be
divided by these speedups because timing conditions/packaging differ. The
negative-row LDC gap also stays open. Issues #28 and #22 track the remaining
selection/comparison/promotion work; XPS collection itself is complete.
Production PR61 stays unchanged and pending integration.

`.workspace/` was unavailable. Tracked AGENTS and the supplied canonical D
safety/benchmark, quality and Research/Git policies were consulted. The existing
`research/m3-point-transform` integration branch is retained. Previous Research
PRs and Production PR61 are not merged by this experiment.

[Executable runner, trust proof and XPS collector](../../experiments/m3_conversion_vector/README.md)
