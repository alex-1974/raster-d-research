# M3.5 public copy and exact conversion baseline audit

## Question and pinned source

Research Issue #22 follows the M3.4 strict-reduction audit. That reduction
already used layout-selected scalar kernels; its KEEP-default outcome does not
qualify copy or cross-type relation performance. This audit starts from
production `1671fb2e51a7b1e7311f78f575d9457e9f279fd4` and existing research
integration `research/m3-point-transform` at
`8c0464d22255c63d82f31b8a76b3033e6dba77e4`. Research PR #20 and production
docs PR #59 remain independent pending integration. Workspace context is
absent under `.workspace/`; tracked and supplied canonical policies are used.

The generator pins all four complete source modules:

| Module | SHA256 |
| --- | --- |
| raster.copy | bfd9402eca1530e6f39316e6adb337f27799221d90cb9e79937621f0c0f05802 |
| raster.conversion | 837fe4ef749a059991311155acd7c3127022da636143782893e5d8c0077d8d00 |
| raster.internal.copy_dispatch | becd5a3e28334f970ede05f95213bb6e96fb147c66e5a90b044f1be06b4ee1e0 |
| raster.internal.conversion_dispatch | 55c86a892871aa102cf6444798982cca3740de3079769172d11bc63b832a1428 |

## Source finding and measured paths

Flat copy already uses checked physical-range classification and memcpy.
Flat conversion uses checked physical ranges and the existing Mir scalar
kernel. Other layouts prove destination injectivity, classify exact affine
sample-byte relations, retain a defensive exact arithmetic-failure fallback,
then execute checked per-coordinate semantic reads/writes. They do not yet use
the M3.2a validated bounds prefilter, which was qualified for other consumers.

| Path | Scope |
| --- | --- |
| Public | Complete current API with its original flat/affine selection |
| Approved | Unchanged private per-coordinate traversal with fixture-provided approval |
| C++ | Already-approved bounded execution; row/sample memcpy or exact conversion |
| Relation | Unchanged exact affine classifier plus view stride/base retrieval only |

Diagnostic wrappers are appended to complete generated dispatch modules; their
original private functions and 16 copy/15 conversion inherited tests remain
unchanged. One harness test adds independent semantic and public failure checks.
No new D execution candidate, bounds prefilter or production change is selected.

C++ omits D shape/plane/injectivity/alias validation and adds a separately
compiled C ABI call. Flat C++ copy performs one memcpy per row, while public
flat copy can issue one memcpy for the full plane. These differences are
explicit. Reference ratios locate opportunities, not equivalent full-library
D/C++ performance. Diagnostic durations cannot be subtracted to attribute an
exact percentage to validation, classification or code generation.

## Semantic and timing qualification

The experiment covers 96 timed cases: three sizes and eight layouts for
ubyte/float/eight-byte-POD copy and exact ubyte-to-float conversion. Destinations
are injective; sources include signed/sample-strided, repeated rows and zero
strides. A coordinate-to-storage oracle checks complete destination storage
including padding/guards. Source backing is fingerprinted after every call.
Float copy checks representation bits including NaN payload, signed zero,
infinities and subnormal. Injective-source conversion cases exercise all 256
ubyte inputs. Repeated mappings use final populated physical samples.

32 additional semantic cases and public controls verify invalid plane order,
shape mismatch, non-injective destinations, actual overlap/no-write, empty
null-base/extreme-stride behavior and shared sparse same-/cross-type backing
with overlapping envelopes but disjoint actual sample bytes. The complete
shared backing is compared to an independent expected image. C++ is not a
public failure validator and receives only already-approved fixtures.

The C++ wrapper's trust argument is retained beside actual code: reachable
validated geometry and small bounded stride-byte products, injective/disjoint
destination, no allocation/retention/throw. An actual-source trusted positive
control instantiates all four operations; replacing trust with safe must reject
casts/system calls. This challenge does not prove the C++ implementation safe;
the inspected source and fixture preconditions supply that argument.

Two warmups precede twelve cyclic rounds per path, each occupying every order
position three times. Destination reset and complete storage checks follow
outside timing. Three fixed-binary processes per compiler produce 27,648 timed
calls. The summarizer independently verifies sample counts/even medians,
semantic markers, all 96 identities and source/result fingerprints across
both compilers and all six processes. Tiny zero medians are retained with
ratios omitted; all large execution samples must be positive.

## Evidence and decision

EPYC 9V74 KVM VM, CPU affinity 0, unchanged frequency/thermal controls;
DMD 2.111.0, LDC 1.41.0 / LLVM 20.1.5, DUB 1.40.0, G++ 13.3.0.
Both compilers pass three unittest modules (31 inherited tests plus the
independent harness test) and actual-source C++ wrapper trust challenges.
All six fixed-binary processes pass 96 timed and 32 additional semantic cases
and all public contract controls; all source/result fingerprints agree.
All 18 manifest entries pass; SUMMARY.md reproduces byte-for-byte. Raw evidence
is in `experiments/m3_copy_conversion/evidence/2026-10-01-container/`.

The following ranges span the three process medians for 2048x512. Copy rows
aggregate three sample types; each full per-case record is in SUMMARY.md.

| Large workload | Compiler | Public ms | Public/C++ execution | Exact relation ms |
| --- | --- | --- | --- | --- |
| Flat copy (three types) | DMD | 0.029–0.378 | 0.663–1.406x | 83.846–96.426 |
| Flat copy (three types) | LDC | 0.030–0.362 | 0.703–1.293x | 38.417–41.104 |
| Padded copy (three types) | DMD | 93.082–100.011 | 249.751–2440.853x | 82.825–88.403 |
| Padded copy (three types) | LDC | 41.165–49.701 | 117.207–1310.138x | 39.341–49.517 |
| Flat exact conversion | DMD | 6.266–6.450 | 63.294–65.320x | 451.548–477.961 |
| Flat exact conversion | LDC | 4.235–4.279 | 43.813–44.318x | 158.696–175.861 |
| Padded exact conversion | DMD | 463.042–488.510 | 4708.104–4956.973x | 450.376–479.853 |
| Padded exact conversion | LDC | 166.299–179.201 | 1695.198–1826.720x | 160.681–168.913 |

Above-one ratios favor C++ execution, which omits public validation. **The
flat public paths bypass the separately measured exact affine classifier**;
the flat relation column is a diagnostic control, not their execution cost.
Flat copy already operates in the same broad timing range as row memcpy, with
no stable blanket winner across sample types/processes. Large public process
spread reaches 12.44% on DMD and 20.74% on LDC; these are not confidence
intervals. Tiny results are below or near timer resolution and cannot select
an executor.

The large non-contiguous consumer gap is material enough to require follow-up,
not acceptance as C++ parity. Exact relation diagnostics are expensive, and
approved semantic execution still differs substantially from C++ on several
layouts. Flat conversion also has a large reference gap while bypassing that
classifier. The source paths and scoped timing observations support two
separate candidate axes; no duration subtraction claims an exact causal share.

| Question | Decision |
| --- | --- |
| Flat checked memcpy copy | KEEP as current baseline; no generic replacement selected |
| Same-/cross-type affine relation | INVESTIGATE checked conservative bounds before the exact classifier |
| Approved affine traversal | INVESTIGATE bounded row execution while retaining all prior checks |
| Flat exact conversion | INVESTIGATE a D-native kernel with the existing validation/precision contract |
| Full-copy/conversion candidate | Required before end-to-end optimization claims |
| Public failure/alias/fallback semantics | KEEP unchanged |
| Production PR | DEFER pending complete candidate and XPS evidence |
| C++ execution reference | KEEP with validation/ABI/memcpy scope limits |
| XPS baseline confirmation | Open; collector ready |
| AArch64, explicit SIMD, threading | Unqualified / deferred |

The next bounded research slice should compare full public candidates with
bounds-only, execution-only and combined changes, preserving original flat
selection where appropriate. Checked conservative envelopes may prove
**disjointness only**; overlapping/unrepresentable envelopes must retain the
exact sample-byte classifier and its defensive fallback. Cross-type sizes need
an independent byte oracle and integer-limit fixtures. Row execution must
retain safe sample-type and scoped callback/borrow contracts, signed strides,
source self-aliasing and destination injectivity. Actual-source trust challenges
remain necessary. VM evidence establishes the question; stable XPS evidence
must justify any production promotion. No compiler switch or manual SIMD is
selected from these diagnostic ratios.
