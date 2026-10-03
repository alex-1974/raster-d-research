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

## Reference XPS qualification — 2026-10-03

The uploaded `raster-crossover-xps-run-9J1pun.tar.gz` has SHA256
`cd3bc1a37a9fba046053af434ec208a84deeb4d8065205d9c3a9bf486941472d`.
All 115 extended-manifest entries and all 110 original audit entries verify.
Summary regeneration is byte-exact. Pins, generated sources, matrix and
experiment input hashes match the container byte-for-byte, and all 438 workload
fingerprints agree across machines/forms/compilers/processes. Every original
file is retained byte-exactly directly or with lossless deterministic gzip,
including both uploaded manifests. The retained manifest has 116 entries;
`RAW-SHA256SUMS` preserves the uploaded extended manifest, and
`audit-SHA256SUMS` preserves the original collector manifest. The same verification
and replay commands above apply to `evidence/2026-10-03-xps`.

Reference host: Intel Core i7-9750H, CPU 0, Linux 6.17.0-22/glibc 2.43;
DMD 2.111.0, LDC 1.41.0/frontend 2.111.0/LLVM 19.1.7, GCC 15.2.0,
DUB 1.40.0, Python 3.14.4, GNU objdump 2.46. Resolved Mir algorithm 3.22.4,
Mir core 1.7.4 and silly 1.1.1 match the prior run. GCC/LLVM backend/CPU differ
from the VM and are explicitly recorded. Frequency/thermal conditions remain
unmonitored. Both complete compiler semantic/trust suites and the independently
challenged C++ bridge pass; all isolated 10,240-case/four-rounding-mode plus
forty-guard-page suites pass. Twelve complete processes retain the same
189,216 blocks and 215,804,736 calls with full backing/source oracles.

| XPS shape/layout | DMD original/store (process range) | DMD store / C++ | LDC original/store | LDC store / C++ |
| --- | ---: | ---: | ---: | ---: |
| 1x128 contiguous | 0.670 (0.663–0.676) | 34.872 | 0.995 | 20.039 |
| 15x17 contiguous | 0.835 (0.749–0.858) | 13.575 | 1.006 | 3.403 |
| 16x17 contiguous | 1.809 (1.683–1.847) | 7.027 | 1.067 | 2.370 |
| 31x17 contiguous | 1.510 (1.440–1.535) | 7.117 | 0.951 | 2.569 |
| 2048x512 contiguous | 3.244 (3.069–3.555) | 1.929 | 1.002 | 0.985 |
| 2048x512 padded | 2.446 (2.393–2.575) | 1.722 | 1.002 | 0.981 |
| 2048x512 negative source | 2.392 (1.813–2.517) | 1.877 | 0.996 | 2.398 |
| 2048x512 negative both | 2.384 (2.107–2.483) | 1.820 | 0.998 | 2.344 |
| 2048x512 repeated source | 2.492 (2.355–2.588) | 2.267 | 1.000 | 0.995 |
| 2048x512 Universal | 0.998 (0.977–1.031) | 20.169 | 0.993 | 4.281 |

Large DMD unit-stride stores win in every paired process, with medians
2.384–3.244x. Safe result copies remain slower (large ratios 0.458–0.603).
DMD original/store medians for unit-stride widths below sixteen are all below
one, ranging 0.456–0.993 across heights/layouts. The full-block boundary is a
useful selection hypothesis, not sufficient evidence for immediate promotion.

**31x17 contiguous now wins 1.510x on the XPS; PR29's qualified XPS evidence
loses at 0.904x on that shape.** Public candidate sources and fixture pins are
unchanged, but the expanded compiled harness, four-path order, timing block
length and execution conditions differ. These results do not identify the
cause. The earlier regression remains valid evidence for that captured consumer;
this sweep cannot erase it or establish that a width-16 gate fixes it.

A conservative next candidate can test **row width at least 64** while retaining
the original loop below that width. This is grounded in the sweep: all 200
unit-stride workloads with widths >=64 favor stores in every process on both
XPS and VM (lowest process ratios 1.144 and 1.118 respectively). Widths >=16
have an adverse 47x17 negative-source process (ratio 0.513; median 1.301).
Width 64 is an experimental candidate policy, not a measured selected-operation
result or a universal optimal threshold. The actual branch and preserved
original loop must be measured and qualified in both the prior PR29 consumer
and the wider PR31 consumer, including short and long timing blocks. No
Production source is changed by selecting this next research hypothesis.

Process spread is still substantial: store-form maxima 173.545% DMD
(7x128 contiguous) and 217.608% LDC (511x17 repeated source). Do not promote
small timing differences or precise factors outside the captured workloads.
LDC's implementation remains the original expression; material small-workload
form differences in the expanded harness warrant compiler/consumer inspection,
not a new SIMD algorithm claim. Large positive-row LDC is near this C++ executor
(medians 0.981–0.995), while signed LDC still takes 2.344–2.398x (negative-both
process range 2.169–3.155; negative-source 2.368–2.604). DMD stores still take
1.722–2.267x C++ time. All reference scope limits above remain: no equivalent
full-public C++ parity, historical-ratio division or isolated validation-cost
estimate is claimed.

## Decision and next gates

Retain the complete container and XPS evidence. Do not promote unconditional
vector selection. Next, implement and measure a private DMD x86-64 row-width
>=64 selection candidate, preserving the exact original loop below the gate
and all portable/LDC behavior. Qualify that actual full public candidate in
both PR29 and PR31 consumers, with short/long timing blocks, before deciding
whether its policy is justified. Preserve all contracts, exactness and narrow
trust gates. Keep the previous small-flat regression explicitly covered.
Investigate signed-LDC and scoped DMD residual C++ gaps with fresh comparisons;
no historical ratio division or end-to-end parity claim is permitted.
Issues #30/#28/#22 remain open for actual selection and remaining promotion.
Production PR61 is unchanged; no merge is performed.

## Pinned reference XPS launcher

`run_xps.sh` uses qualified source `0635b298a5fae79b25c98d0e0186c7000a930a6b`
and unchanged Production PR61 in new detached sibling worktrees. It records
complete D/GCC/toolchain/dependency provenance, preserves the original manifest,
verifies the summary and extended manifest, and prints the upload archive.
Bash syntax and a local prepare-only smoke passed; this is not an XPS runtime
measurement. The uploaded reference sweep is now qualified above. Actual conservative
selection qualification remains the next gate.
