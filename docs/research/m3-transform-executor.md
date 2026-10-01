# M3.2 post-bounds point-transform executor qualification

## Scope and baselines

Research Issue #14. This continuation starts from research commit
`12584b664059e8fcb077c17bfa2fb38c9ca1f707` and preserves that earlier experiment.
The production baseline is now `b263477bdbbe0dc3e8c469ac3867eda345ba364c`
(PR #53): both comparison sides already use the checked affine bounds wrapper.
The old `252bc9a` baseline is historical and cannot isolate executor benefit.

`.workspace/` is unavailable in this standalone checkout. The repository's
tracked engineering context and the supplied workspace practices/quality gates
were followed; the supplied migration table is stale for raster-d, so this
experiment retains the existing research workflow rather than restructuring it.

## Controlled difference

`experiments/m3_transform_executor/generate.py` pins the full production
transform module by SHA-256. Both candidates retain its entire structural
validation, error ordering, destination injectivity, exact relation/fallback,
empty success and Universal sample path. Only post-validation execution changes:

| Path | Execution when both sample strides are one |
| --- | --- |
| A | Public production `trySample` / `trySetSample` traversal |
| B | Signed row pointers, generic scalar transform loop |
| C | Bounded row slices, generic scalar transform loop in `@safe` |

No public signature, bounds classifier, transform expression, threading, SIMD,
compiler gate or persistent noalias property changes. Slice construction has
narrow documented trust; pointer execution has a broader documented trust
boundary. Positive/negative compile probes demonstrate why neither boundary can
simply be marked safe. They do not substitute for the validation-based argument.

## Correctness and measurement

Both generated consumers retain 11 production unittest blocks, which pass with
DMD 2.111.0 and LDC 1.41.0. The additional harness covers 41 cases: float/ubyte
small, medium and large contiguous/padded layouts, all four row-sign pairs,
Universal sample stride +2/-2, and POD contiguous/padded/Universal traversal.
Special-float affine and identity checks compare bit patterns against the public
operation, including preservation of signed zero by identity.

All six process executions (three per compiler) pass. Every timed operation is
followed by complete output/padding comparison and a source fingerprint check,
outside timing. All 41 fingerprints agree across processes and compilers.
The matrix contains 6,642 timed calls in total; two warmups precede each path.
Each path occupies every ordering position three times in nine cyclic rounds.
The timing includes full validation/relation work; it is not a kernel micro-win.

Evidence and reproducible summary:

- `experiments/m3_transform_executor/evidence/2026-10-01-container/`;
- `collect.sh OUTPUT_DIRECTORY CPU` (both compilers on PATH);
- `summarize.py DIRECTORY` validates sample counts, reported medians, complete
  case identity and cross-process/compiler fingerprints before reporting ratios.

## Container result

AMD EPYC 9V74 KVM environment, CPU affinity 0, unchanged host frequency/thermal
controls. DMD 2.111.0; LDC 1.41.0 / LLVM 20.1.5; DUB 1.40.0. Verbose compiler
commands and binary SHA-256 values are retained. Consumer release settings are
used, including ordinary safe-code bounds behavior; no boundscheck-off claim
is made. There is no explicit ISA optimization or compiler specialization.

Across three processes, all five large layouts per type (four padded signs plus
contiguous) have these baseline/candidate median ratio ranges:

| Type | Compiler | Pointer | Slice |
| --- | --- | --- | --- |
| float | DMD | 12.673–16.656x | 12.855–16.090x |
| float | LDC | 5.790–21.652x | 6.406–22.470x |
| ubyte | DMD | 7.320–8.405x | 6.420–7.258x |
| ubyte | LDC | 3.703–41.417x | 3.687–35.168x |

These are additional to the integrated bounds-prefilter gain. They are observed
VM diagnostics, not portable speedup promises. Candidate process-median spread
reaches about 30%; source form preference varies with type/sign/layout. Tiny and
Universal timings do not define a tight acceptance threshold. This environment
cannot replace the established XPS reference qualification, especially its LDC
LLVM 19.1.7 generation.

## Generated-code question

The isolated exact executor probes show vector loads for both float and ubyte
under LDC for both source forms. Their optimized IR has no bounds-error call.
DMD's slice probe retains bounds-error relocations; its pointer probe does not.
This is consistent with a possible slice-check cost under DMD, but it is not a
complete-consumer causal proof. No compiler-specific path is admitted from it.
`codegen.py` plus `codegen.sh` preserve the diagnostic source and commands.

## Decision

| Question | Decision |
| --- | --- |
| General Canonical executor | KEEP for production handoff; correctness and XPS benefit established |
| Slice versus pointer as production default | KEEP generic pointer; REJECT slice as the default due to consistent DMD cost, retain it as evidence |
| Compiler-specific form | DEFER; no specialization justified yet |
| Negative-row special handling | DEFER; signed generic paths are correct, no special implementation admitted |
| Universal fallback | KEEP unchanged |
| Parallel row-range entry | DEFER; outside this qualification |
| Production promotion | READY for a separate cleaned production PR with internal-surface and trust probes |

Only the cleaned accepted executor plus independent production contract probes
enter a separate PR to raster-d/develop. Issue #14 stays open until production
handoff is complete. The following XPS record completes reference qualification.


## XPS reference result — 2026-10-01

Uploaded archive SHA256:
`e0b5b0ec2333f69ef6e6ebe8bfd7f828db25104bd49ebbde0be6690afc9afb93`.
Source is research `ed7cd00ff3d91c49f732f257d2c9d10dcd11f44c`, production
`b263477bdbbe0dc3e8c469ac3867eda345ba364c`. Raw files are preserved byte-for-byte
under `experiments/m3_transform_executor/evidence/2026-10-01-xps/`, including
original SHA256SUMS. Every supplied checksum passes. The original summary used
a hardcoded container label; QUALIFIED_SUMMARY.md recomputes identical medians
and ratios with the corrected XPS environment label.

Machine: XPS i7-9750H, CPU affinity 0; no added host frequency/thermal control.
Compilers: DMD 2.111.0, LDC 1.41.0 / LLVM 19.1.7, DUB 1.40.0. Both inherited
test suites and both trust challenges pass. Six processes pass all 41 cases,
with all output/padding hashes identical across processes and compilers. Affine
and identity special-float checks pass. Complete-consumer timing includes the
already-integrated checked relation wrapper on all paths.

Large 2048x512 outputs, three processes, contiguous and all four padded row-sign
pairs:

| Type | Compiler | Public/pointer ratio | Public/slice ratio |
| --- | --- | --- | --- |
| float | DMD | 17.433–24.001x | 9.233–10.360x |
| float | LDC | 8.209–12.974x | 8.232–13.181x |
| ubyte | DMD | 9.015–9.475x | 7.390–7.585x |
| ubyte | LDC | 5.751–37.896x | 5.507–37.708x |

DMD slice/pointer medians are 1.764–2.398 for float and 1.212–1.273 for ubyte:
pointer wins every large paired case. LDC gives no stable material reason to
maintain an additional slice specialization; paired differences sit within
observed process variability. Both implementations use exactly the same
sample-value expression and validate before writing.

DMD float pointer process-median spread reaches 46.56%; LDC float pointer/slice
reach 39.66%/36.19%. DMD ubyte pointer spread is 5.44%. These limits prevent
precise portable speedup promises and a tight timing gate. Even the slowest
large paired pointer result substantially improves the public baseline, and
DMD pointer remains ahead of slice in every paired case. Source-form selection
therefore rests on the robust direction and magnitude, not a small noisy delta.

Decision: KEEP one portable generic pointer executor, with a narrowly audited
trusted row/sample loop and unchanged safe transform invocation. REJECT slice
as the default, while preserving it as a safety/performance comparison. DEFER
compiler-specific tuning, negative-row specialization and parallel entry;
AArch64 performance remains unqualified. Universal traversal remains unchanged.
