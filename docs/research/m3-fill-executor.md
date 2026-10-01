# M3.3 generic fill executor qualification

## Scope and baseline

Research Issue #17 follows the completed M3.1 neighbourhood and M3.2 point
transform handoffs. Production is pinned to merged develop
`d4763ff0b95999743ea43d0b1dcca44fc68773d1`; neither repository's historical
raw fill benchmark substitutes for the complete public consumer.

Workspace context is unavailable under `.workspace/` in this standalone clone;
tracked context and supplied current workspace policies were followed. The
existing research topic workflow is retained at its explicit integration base,
`research/m3-point-transform` merge `900da8164637a44a407e550225776a391ce62d98`.
Production receives no change during qualification.

## Preserved semantics

Fill accepts every validated writable resident affine layout, including
non-injective mappings. Repeated writes to the same sample are valid because
each writes the identical exact sample value. This differs from transform's
injective, physically disjoint destination contract.

`generate.py` verifies clean production HEAD and full SHA256 digests of both
public fill and internal scalar-dispatch modules. It mechanically preserves the
public wrapper, all eight inherited tests, invalid-plane rejection, valid-empty
success and the original Universal traversal. Only after plane selection and
empty handling, sample stride one selects either:

- generic signed-row pointer writes under documented bounded trust;
- narrow trusted row-slice formation followed by safe D slice assignment.

No injectivity check, noalias claim, public signature, numeric conversion,
compiler selector, SIMD or threading is introduced. Every assignment uses the
same value. Pointer/slice operands do not escape the validated writable borrow.
Actual-source safe challenges instantiate float, ubyte and eight-byte POD, with
positive trusted controls, and require pointer/index/slice safety rejection.
They justify why trust is necessary, not why the boundary is correct; the
validation-based argument is recorded with both generated kernels.

## Matrix and method

70 cases: float/ubyte each have three sizes (31x17, 256x128, 2048x512) and ten
layouts; POD has all ten small layouts. Layouts are contiguous, padded, negative
rows, zero/repeated rows, overlapping positive/negative rows, sample stride +2,
negative rows with sample stride -2, zero sample stride, and both strides zero.
All physical backing includes guards. An independent logical-coordinate oracle
marks every reachable storage sample and preserves all padding/guards.

Two warmups precede nine raw samples per path, with each path in each cyclic
ordering position three times. Each actual operation executes outside assert;
full output/padding checks and fingerprints run outside the timer after every
call. There are 11,340 timed calls over six independent processes. Invalid and
empty planes are checked for all three types. Bitwise special float fills cover
positive/negative zero, explicit NaN payload and infinities with distinct,
repeated and overlapping rows. Output hashes agree across compilers/processes.

DMD 2.111.0 and LDC 1.41.0 / LLVM 20.1.5 pass both inherited test modules and
actual-source trust challenges. Release commands, binaries' hashes, environment
and all raw samples are preserved under
`experiments/m3_fill_executor/evidence/2026-10-01-container/`.

## Container diagnostic

EPYC VM, affinity CPU 0, unchanged host frequency/thermal controls. For large
outputs with distinct physical rows (contiguous, padded, negative), across
three processes, baseline/candidate median ratios span:

| Type | Compiler | Pointer | Slice |
| --- | --- | --- | --- |
| float | DMD | 9.649–11.563x | 13.819–22.693x |
| float | LDC | 8.439–16.949x | 7.037–19.674x |
| ubyte | DMD | 18.949–22.359x | 91.838–291.288x |
| ubyte | LDC | 49.782–107.038x | 61.563–117.444x |

Under DMD, slice/pointer ratios for these paired cases are 0.497–0.698 for float
and 0.073–0.216 for ubyte: Slice is consistently faster. Under LDC float they
are 0.852–1.211, with no consistent winner; ubyte is 0.809–1.024. These VM
observations make slice a serious candidate, unlike the completed transform
qualification. They do not select a production source form.

Repeated/overlapping-row results are retained separately per case in SUMMARY.md.
They perform repeated logical writes to shared physical samples and must not
be presented as independent-memory bandwidth. Candidate process spread over
large Canonical cases reaches 47.97%; exact portable ratio promises are
unsupported. Very small cases include zero-duration samples at timer resolution:
retain them, omit zero-median ratios and use those cases for correctness only.
All large-case raw samples must remain positive.

Isolated actual-executor disassembly answers whether source shape selects a
bulk-fill implementation. DMD slice float has `_memsetFloat` relocations absent
from pointer float. LDC emits `memset` edges for ubyte in both forms. The probe
retains concrete commands and disassembly; it is a diagnostic rather than a
complete-consumer causal proof. No compiler workaround is inferred.

## Decision and next gate

| Question | Decision |
| --- | --- |
| Generic Canonical fill optimization | KEEP as a qualified correctness candidate |
| Pointer versus Slice | KEEP Slice for production; retain Pointer as comparison evidence |
| Universal/sample-strided fallback | KEEP unchanged |
| Repeated/overlapping rows | KEEP exact legal fill behavior; no injectivity gate |
| Compiler-specific specialization | DEFER |
| Zero-stride algorithmic shortcut | DEFER; original Universal logical traversal retained |
| SIMD, parallel execution | DEFER |
| Production admission | READY for separate implementation review after XPS qualification |
| AArch64 performance | Unqualified |

`collect.sh OUTPUT_DIRECTORY CPU xps` reproduces all semantic, trust, six-process
and code-generation checks on the reference machine. `summarize.py` validates
raw counts, medians and cross-process/compiler fingerprints. Targeted CI pins
production and runs the semantic/trust/complete-consumer diagnostic on both
compilers without timing thresholds. A later production PR admits only the
selected cleaned kernel with independent contract/visibility tests.

## XPS qualification — 2026-10-01

The uploaded archive and source hashes are recorded in
`experiments/m3_fill_executor/evidence/2026-10-01-xps/PROVENANCE.md`. All uploaded
checksums pass; the validating summarizer exactly reproduces SUMMARY.md.
All six runs pass 70 cases and contract/special-float checks, with matching
hashes. Both inherited suites and actual-source trust challenges pass.

XPS i7-9750H, affinity CPU 0, no added frequency/thermal controls; DMD 2.111.0,
LDC 1.41.0 / LLVM 19.1.7, DUB 1.40.0. Complete-consumer timings contain 11,340
calls. Across all six large Canonical layouts, public/candidate medians span:

| Type | Compiler | Pointer | Slice |
| --- | --- | --- | --- |
| float | DMD | 8.431–13.234x | 9.232–13.845x |
| float | LDC | 2.281–16.557x | 2.247–16.350x |
| ubyte | DMD | 19.132–24.234x | 61.527–282.100x |
| ubyte | LDC | 8.628–144.913x | 11.892–151.867x |

Slice beats Pointer in every paired large DMD ubyte case; Slice/Pointer ratios
are 0.086–0.311 (3.22–11.65x faster). DMD float is mostly near parity, unlike
the larger VM Slice advantage. LDC float and ubyte preferences vary by run and
layout. Specifically LDC padded float Slice is 3.6–15.8% slower in all three
runs; this bounded measured disadvantage is accepted in exchange for the large
consistent DMD ubyte benefit and narrower safety boundary of one generic source
form. Negative-row LDC float comparisons vary from 0.616–1.263; no specialization
is justified by these noisy small paired differences.

Large-case process spread reaches 355.03% for LDC ubyte Pointer, 157.86% for
LDC ubyte Slice and 150.99% for DMD ubyte Slice. DMD float Pointer/Slice spread
is 72.61%/61.67%, LDC float 96.17%/73.32%. These results support the robust
end-to-end gain over the checked public baseline, not precise speedup promises
or a claim that Slice wins every comparison. Repeated/overlapping rows remain
logical repeated-write work, not independent-memory bandwidth.

Select one portable generic Slice executor for matching sample stride one.
Only validated row formation is trusted; assignment is safe. Retain Pointer
as comparison evidence. Preserve Universal traversal and legal non-injective
semantics, including repeated/overlapping Canonical rows. Compiler-specific,
zero-stride algorithmic shortcuts, manual SIMD and parallel execution remain
deferred. AArch64 performance is unqualified. The production handoff must add
independent layout/padding/bitwise tests and external visibility/actual-source
trust controls before merge.
