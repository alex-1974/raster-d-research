# M3.9 exact-vector crossover and fresh C++ execution reference

Refs Research #30, #28 and #22. PR29's XPS qualification established material
medium/large DMD gains but a consistent small contiguous 31x17 regression.
This standalone study copies PR29's exact qualified generation, kernels and
semantic/trust controls from `5161d368247113c462a74222b1b7484de89da8d4`.
It adds a broader matrix and a freshly compiled C++ execution reference.
Production PR61 remains pinned at `7dcdf01babf87e9a80af2864fbad75efe8e7d0ef`.
The original four complete source/fixture hashes remain mandatory.

## Questions

Which widths, heights and layouts favor the SIMD store over the original full
public call? Does width alone explain the small-flat regression? What remains
of the scoped C++ execution gap on the same CPU/process/allocations/toolchain?
No selection threshold or Production candidate is introduced before these
measurements are qualified on the reference XPS.

## Matrix and measurement

24 widths: 1,7,15,16,17,23,31,32,33,47,63,64,65,95,127,128,129,255,256,257,
511,512,513,2048. Each uses heights 1,17,128 and six layouts: contiguous,
padded, negative-source, negative-both, Universal sample stride two and
repeated-source rows. Six 2048x512 anchors bring the total to 438 workloads.
The complete manifest `matrix.json` is checked against every process.

Four forms: original full public operation, exact vector with safe result
copies, exact vector with bounded stores, and C++ already-approved execution.
DMD x86-64 uses the baseline SSE2 kernels; LDC/forced portable retain the
original expression/autovectorization. All inherited validation/fallback,
errors/no-write/empty/injectivity/overlap and Copy controls remain.

Nine rounds use cyclic order `(position+round+process)%4`, eight warmups per
form, 8..4096 calls per block with a 262,144 sample target. Smaller blocks bound
the broader sweep; these raw timing values must not be substituted into
PR29's longer-block historical ratios. Every block checks complete backing,
source preservation and a bitwise independent expected result outside timing.
Six processes per compiler reuse a fixed binary and CPU; no performance pass
threshold exists. Thermal/frequency controls are unchanged and unmonitored.

`original_over_form_*` reports paired speedup (>1 favors form).
`form_over_cpp_*` reports paired full-D/approved-C++ elapsed ratios (>1 means
D takes longer). The summary uses round medians, then paired process ratios;
process spread remains explicit. Missing, duplicate, misordered or relabelled
process/round/form data and mismatched fingerprints fail replay.

## C++ scope and fixture trust

`reference.cpp` is a separately compiled C ABI executor with numeric byte-to-
float conversion, flattened positive contiguous traversal, unit-stride rows
and affine sample-stride fallback. GCC flags are C++17, O3, no fast math,
`-march=x86-64 -mtune=generic`; no native ISA tuning or LTO. Compiler version,
command, object identity and disassembly are retained. GCC version is recorded,
not assumed identical between VM and XPS.

This C++ function assumes reachable live backing, disjoint source/destination,
injective output, bounded affine arithmetic and valid shape. It has no public
view/error/injectivity/overlap validation. Thus its gap includes validation and
ABI/code-generation differences; it is not equivalent end-to-end API parity or
a numerical estimate of validation cost. Universal reference execution also
bypasses D's sample-access API. Original/store comparisons share the full D
public contract and are the selection evidence.

`cpp_bridge.d` adds fixture-only narrow trust. Timing uses separately allocated
arrays; all affine extrema are checked before timing, every expected indexed
access is bounded, and the fixed matrix makes ptrdiff_t math representable.
The C++ source does not escape pointers. Its restrict qualification follows
from these distinct allocations; repeated source samples remain legal.
Source/result/padding guards run after every block. Each compiler also calls
this same C++ object through 10,240 isolated widths/offsets/four rounding-mode
cases and forty guard-page widths. Removing bridge trust must actually fail
on both compilers. No Production trust is widened.

PR29's complete semantic suite is repeated: 40 unittest modules; 72 conversion
backing cases and 96 Copy controls, default/forced portable; nine vector-active
shared-backing cases; positive attributes and original/new/independent SIMD
load/store trust challenges; 10,240 bitwise row cases and forty protected-page
widths per form/selection. Forced portable is not another architecture test.

## Reproduce

Linux x86-64, Python 3, GCC g++, objdump, DMD 2.111.0, LDC 1.41.0 and DUB 1.40.0
are required. Use a clean sibling Production checkout at the exact pin.

```bash
python3 experiments/m3_conversion_crossover/audit.py /tmp/conversion-crossover
(cd /tmp/conversion-crossover && sha256sum -c SHA256SUMS)
python3 experiments/m3_conversion_crossover/summarize.py /tmp/conversion-crossover > /tmp/replayed.csv
cmp /tmp/replayed.csv /tmp/conversion-crossover/summary.csv
```

`--compiler dmd|ldc2|both`, `--processes 1..6`; output must be new. CI uses one
process for qualification, with no timing claim. The pinned XPS launcher prepares detached sibling worktrees at qualified
Research source `0635b298a5fae79b25c98d0e0186c7000a930a6b` and unchanged
Production PR61. It checks baseline D compiler/DUB versions, records GCC and
resolved dependency versions, runs both compilers with six processes, verifies
hashes and replay, and prints an upload archive. No user working branch is
switched or cleaned. Partial files/worktrees remain on failure. The archive
contains original uncompressed evidence and an extended manifest; its original
collector manifest is preserved separately as `audit-SHA256SUMS`.

```bash
bash experiments/m3_conversion_crossover/run_xps.sh "$HOME/Programmiersprachen/dlang/d-geospatial-workspace/libs"
```

A second `--prepare-only` argument checks versions/pins and prepares worktrees;
it does not benchmark or qualify the XPS. Keep power conditions consistent and
close heavy background workloads for the actual reference run. No branch merge
is assumed.

[Findings and remaining gates](../../docs/research/m3-conversion-crossover.md).
