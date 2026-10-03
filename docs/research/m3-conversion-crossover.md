# M3.9 exact-vector crossover and fresh C++ execution comparison

Issue #30 follows #28 and parent #22. Qualified XPS evidence in PR29 establishes
large DMD gains but small-flat regression. This standalone study broadens the
same pinned complete public operation and retains a fresh separately compiled
C++ approved-execution reference. Production PR61 remains unchanged at
`7dcdf01babf87e9a80af2864fbad75efe8e7d0ef`. No merge is assumed.

## Method and scope

[Experiment and proofs](../../experiments/m3_conversion_crossover/README.md)
describe the 438 width/height/layout workloads, four cyclic paths, exact SIMD
kernels, fixture-only C++ trust and semantic gates. Kernels and complete public
generation derive from PR29 at `5161d368247113c462a74222b1b7484de89da8d4`.
This topic is standalone against the existing `research/m3-point-transform`
integration base; earlier Research PRs are not silently integrated.
`.workspace/` is unavailable here; tracked AGENTS and the supplied relevant
canonical policy attachments were read. No branch migration is performed.

Container evidence: DMD 2.111.0, LDC 1.41.0/frontend 2.111.0/LLVM 20.1.5,
DUB 1.40.0 and GCC 13.3.0, Linux x86-64 AMD EPYC shared VM, first available CPU.
Exact versions, commands, CPU/affinity, compiler/object/binary/generated/source
identities, assembly and raw blocks are retained. Frequency and thermal state
are unchanged and unmonitored. Imported `-i` consumers differ from separately
built DUB packages. GCC uses O3, no fast math, x86-64 baseline/generic tuning,
no LTO; D retains prior baseline release flags without native ISA tuning.

Six processes per D compiler contain 15,768 blocks each: **189,216 blocks and
215,804,736 calls** across four forms and 438 workloads. Three D forms are
complete public calls; one is an already-approved C++ executor. Each block
passes full bitwise backing/source/padding oracles. All compiler/form/process
fingerprints agree for all 438 workloads. The wider sweep uses a 262,144-sample
block target (8..4096 calls), shorter than PR29's 8,388,608 target. The values
are not interchangeable with prior historical timing factors.

## Results: no universal threshold from VM evidence

Original/store >1 favors the exact SIMD-store candidate. Values below are
medians of process-paired ratios. D/store-to-C++ >1 means the full D operation
is slower than the approved C++ executor, including D validation and different
ABI/code-generation costs. It does not estimate validation alone or establish
equivalent end-to-end API parity.

| Shape/layout | DMD original/store (process range) | DMD store / C++ | LDC original/store | LDC store / C++ |
| --- | ---: | ---: | ---: | ---: |
| 1x128 contiguous | 0.247 (0.230–0.254) | 61.652 | 1.000 | 14.901 |
| 15x17 contiguous | 0.871 (0.795–0.938) | 9.194 | 0.994 | 3.404 |
| 16x17 contiguous | 1.524 (1.511–2.037) | 5.826 | 0.996 | 2.149 |
| 31x17 contiguous | 1.306 (1.300–1.324) | 6.129 | 0.998 | 2.220 |
| 256x128 contiguous | 2.885 (2.778–2.919) | 2.332 | 1.000 | 1.080 |
| 2048x512 contiguous | 4.343 (3.464–4.693) | 2.325 | 0.998 | 1.078 |
| 2048x512 padded | 4.113 (3.682–4.601) | 2.426 | 1.001 | 1.088 |
| 2048x512 negative source | 4.415 (3.436–4.502) | 2.052 | 1.004 | 4.390 |
| 2048x512 negative both | 3.579 (2.528–4.336) | 2.232 | 0.997 | 4.148 |
| 2048x512 repeated source | 4.442 (2.909–4.636) | 2.215 | 1.007 | 1.064 |
| 2048x512 Universal | 1.000 (0.990–1.020) | 15.064 | 1.000 | 4.107 |

The unconditional candidate is markedly slower below a full sixteen-byte block.
A block boundary helps explain part of the crossover but does not select a
portable cutoff: **31x17 contiguous wins 1.306x here, whereas PR29's XPS run
loses at 0.904x**. Machine/compiler backend/packaging/block-duration/placement
conditions differ. No single cause is inferred, and the VM cannot override
the measured XPS regression. The broader XPS sweep is mandatory before a
conservative selection candidate is justified.

Largest store-form process spread is 88.587% (DMD 47x1 negative both) and
110.379% (LDC 65x1 Universal). Short blocks are especially vulnerable to shared
host noise. Small differences and exact crossover factors are not qualified
Production claims. Every process favors DMD SIMD stores on the five large
unit-sample-stride layouts, but their exact factors remain hardware-scoped.
LDC retains the original expression; its near-one form comparisons do not
justify new SIMD/architecture selection.

Fresh C++ gaps are materially open. Large DMD SIMD stores are still
2.052–2.426x slower than this approved executor, and large negative-row LDC is
4.148–4.390x slower. C++ uses a known-disjoint restrict-qualified fixture and
flat/row/affine loops without view/shape/injectivity/physical-relation/error
validation. Universal C++ also bypasses D's sample API. These current scoped
gaps are not directly comparable to PR23's historical compiler/reference
implementation and cannot prove regression or decompose costs. They identify
further work; no parity is claimed.

## Qualification and retained evidence

Both compilers pass 40 imported unittest modules; 72 full public conversion
backing cases and 96 Copy controls, default/forced portable; nine vector-active
shared-backing cases, default/forced portable; positive attributes and original,
whole-vector, isolated and independently removed SIMD load/store trust gates.
Each SIMD form/selection passes 10,240 bitwise offset/width/four-rounding-mode
cases and forty guard-page widths. The same compiled C++ object independently
passes these 10,240 plus forty cases through each D compiler; removing its
fixture bridge trust actually fails. No Production trusted boundary changes.

[evidence/2026-10-03-container](../../experiments/m3_conversion_crossover/evidence/2026-10-03-container)
preserves all 110 files listed in the original collector manifest and that
manifest itself. Timing TSV and large assembly files use
deterministic lossless gzip to bound repository size. `RAW-SHA256SUMS` is the
byte-exact original manifest; 110 entries verify after decompression. The
retained-file manifest has 111 entries, including that original manifest.
Summary regeneration is byte-exact from the compressed evidence. No timing or
assembly text is edited. No compiled binary/object is checked in.

```bash
python3 experiments/m3_conversion_crossover/support/verify.py experiments/m3_conversion_crossover/evidence/2026-10-03-container
python3 experiments/m3_conversion_crossover/summarize.py experiments/m3_conversion_crossover/evidence/2026-10-03-container > /tmp/crossover-replay.csv
cmp /tmp/crossover-replay.csv experiments/m3_conversion_crossover/evidence/2026-10-03-container/summary.csv
```

Negative replay controls reject missing rounds, duplicate blocks, changed
cyclic form selection and mislabelled processes. Retained-file checks reject
missing/corrupted files. Python assertions must remain enabled; runner/replay
explicitly reject optimized Python. CI independently repeats both compiler
semantic/trust suites with one process and no timing threshold.

## Decision and next gates

Retain this study as measured Research evidence. Do not promote unconditional
vector selection or invent a cutoff from shared-container observations.
Run the complete pinned collector on the reference XPS, qualify all hashes,
summary, fingerprints and process ranges, then select a conservative private
compiler/architecture/size policy and measure that actual full public candidate
against both original and unconditional vector execution. Preserve the original
path where it wins, all public contracts, exactness and independent trust gates.
Investigate the remaining signed-LDC and scoped DMD execution gaps with fresh
comparisons; no historical ratio division or C++ parity claim is permitted.
Issues #30/#28/#22 and Production promotion remain open.
