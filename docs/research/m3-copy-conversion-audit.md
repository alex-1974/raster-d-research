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

The baseline motivates comparison of full public candidates with
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

## Full public candidate qualification

Three independently generated forms extend the baseline without changing its
raw evidence. Each form pins and copies both complete public/internal modules,
retaining 147 public/dispatch unittest blocks across the three forms. The
validated bounds module is separately pinned at SHA256
`896da9b81f03fb0a5848043280c34597a3fcd5426cb8e3c0990045b760f07d0f`;
it retains two inherited tests and adds two cross-type tests. One harness test
brings the total to 152 unittest blocks across fourteen modules.

| Full consumer | Relation change | Execution change |
| --- | --- | --- |
| Bounds | Same-type checked wrapper; checked one-/four-byte envelopes for conversion | None |
| Execute | None | Unit-sample-stride safe row slices; approved flat conversion uses the same exact numeric loop |
| Combined | Both checked bounds forms | Both row kernels |

Checked envelopes prove **disjointness only**. Overlapping or unrepresentable
envelopes return to the original exact classifier, including arithmeticFailure;
all defensive operation-local fallbacks remain byte-for-byte unchanged. The
original flat checked memcpy copy selection is preserved. Universal execution
remains the original checked semantic traversal; it may still benefit from a
bounds rejection. No repeated/zero-source work shortcut is introduced.

The cross-type wrapper reuses the complete pinned checked envelope arithmetic
with source/destination sample sizes one and four. A new 5,000-case independent
byte-enumeration oracle checks overlap, disjointness, bounds-hit and decline;
integer-limit fixtures compare with the original exact classifier. Together
with the inherited 5,000-case same-type oracle this qualifies both sizes before
any real pointer is accessed. CTFE and safe/pure/nothrow/nogc properties remain.

Only read/write row pointer arithmetic and bounded slice formation need new
trust. Callers have already validated retained geometry, unit sample strides,
injective destination and exact global sample-byte disjointness. Source rows
may repeat. Local slices do not escape; assignment and numeric conversion loops
remain safe/pure/nothrow/nogc. Actual-source challenges extract all four row
kernel instances and instantiate ubyte/float/POD copy and conversion under
those attributes, then reject safe pointer/slice construction. The separately
inspected C++ wrapper challenge remains. All argumented trust boundaries are
invocation-local; none creates a persistent noalias capability.

Every public form is tested for error order, invalid/empty, shape mismatch,
non-injective destination, actual overlap/no-write and shared backing. In
addition to sparse Universal sharing, three-type Canonical copy and exact
conversion fixtures use overlapping envelopes with disjoint samples. They
force bounds decline, exact approval and safe optimized row execution, with
complete backing compared against independent storage/byte images.

The five measured paths are Public, Bounds, Execute, Combined and the existing
C++ execution reference. Fifteen cyclic rounds put each path in every position
three times after two warmups. Source/output/guard checks and destination reset
are outside timing. Six fixed-binary processes yield 43,200 timed calls across
96 cases plus 32 extra semantic cases; all four public paths receive the
contract controls. The summarizer validates odd medians, all counts and
cross-process/compiler backing fingerprints. Public/candidate ratios now
compare complete consumers; C++ ratios retain the baseline validation/ABI
limits. Isolated code generation extracts actual row helper source with the
recorded D release optimization flags; it is diagnostic, not a causal proof of
the complete public binary.

### Container results and decision

[Complete candidate evidence](../../experiments/m3_copy_conversion_candidates/evidence/2026-10-01-container/SUMMARY.md)
retains the six raw logs, exact reproducing summary, toolchain/build commands,
actual-source trust diagnostics, C++ and isolated D assembly, and SHA256SUMS.
Both compilers pass fourteen unittest modules and all five trust controls;
all six release processes pass the full contract and backing checks.

The following ranges cover three process medians per compiler; copy rows also
aggregate all three sample types. They describe this VM, not a stable speedup
promise or a complete D/C++ library comparison.

| Large group (2048×512) | Compiler | Public/Bounds | Public/Execute | Public/Combined | Combined/C++ |
| --- | --- | --- | --- | --- | --- |
| Flat copy | DMD | 0.823–1.093x | 0.824–1.085x | 0.891–1.093x | 0.669–1.092x |
| Flat copy | LDC | 0.976–1.224x | 0.941–1.139x | 0.935–1.194x | 0.786–1.130x |
| Padded copy | DMD | 10.656–12.748x | 0.911–1.131x | 196.291–4122.947x | 0.971–1.331x |
| Padded copy | LDC | 15.662–18.739x | 1.039–1.069x | 86.405–1089.356x | 0.986–1.369x |
| Flat conversion | DMD | 0.978–1.030x | 7.250–16.513x | 7.373–15.469x | 8.141–9.563x |
| Flat conversion | LDC | 0.947–0.992x | 19.654–41.015x | 17.934–36.129x | 1.100–2.251x |
| Padded conversion | DMD | 38.948–53.086x | 1.017–1.047x | 537.524–583.384x | 8.381–9.154x |
| Padded conversion | LDC | 64.878–67.502x | 1.025–1.036x | 743.795–1671.381x | 1.021–2.279x |
| Negative-both conversion | DMD | 48.960–53.279x | 1.005–1.023x | 514.604–538.652x | 4.741–5.825x |
| Negative-both conversion | LDC | 64.972–66.367x | 1.024–1.050x | 323.807–365.440x | 3.135–3.427x |

The bounds-only result supports conservative rejection before the expensive
exact relation scan. Execution alone retains that scan and consequently does
little for non-flat cases. Combining both changes substantially reduces padded
Copy cost and produces execution-reference ratios in the same broad range;
flat Copy already takes the existing optimized route and has no established
improvement. Universal sample strides preserve the original execution and
receive only the applicable relation improvement.

Exact conversion improves substantially, but the combined public consumer
still trails the execution-only C++ reference: padded DMD is 8.381–9.154x,
while LDC ranges from 1.021–2.279x; negative-both conversion retains a larger
LDC gap of 3.135–3.427x. Isolated actual-source assembly shows scalar
`cvtsi2ss` conversion in DMD, and packed `cvtdq2ps` plus scalar tails in LDC;
the C++ object also has packed conversion. This supports a remaining codegen
question, not attribution of the complete public timing difference.

Across large cases the maximum three-process time spread is 126.32% public /
170.37% combined for DMD, and 67.51% / 139.92% for LDC. Those outliers make
stable reference-host confirmation essential; no confidence interval or timing
threshold is inferred. Tiny zero medians remain explicitly below clock
resolution. The final series ran alone; discarded preliminary logs are not
included in the evidence.

| Gate | Decision |
| --- | --- |
| Bounds-only and combined semantic / trust qualification | PASS on both compiler families |
| Container six-process full consumer evidence | Complete, diagnostic; high VM spread retained |
| Reference XPS qualification | Open; candidate collector ready |
| Production selection | Deferred until reference evidence; no source promotion |
| Remaining exact-conversion execution gap | Open; evaluate reference-host results and actual public codegen |
| Explicit SIMD, compiler switch, AArch64, threading | Unqualified / deferred |

## Reference XPS qualification — 2026-10-03

[Original XPS raw evidence and reproduced summary](../../experiments/m3_copy_conversion_candidates/evidence/2026-10-03-xps/SUMMARY.md)
qualifies research head `85e1614417b628068fca071a9fa4a28ace6302e1`
against the unchanged production pin. The uploaded archive SHA256 is
`7c1636331163f30e1479f9d99bbcb230a6520b2396184f21a2fdb73f26d73ae4`.
All 19 checksums verify, the summary reproduces byte-for-byte, and all 96
source/result fingerprints match the container evidence. Both compilers pass
fourteen unittest modules and five actual-source trust controls. All six
release processes pass 96 timed cases, 32 additional semantic cases, all four
public-path contract controls and independent backing/guard checks.

The reference host is Intel i7-9750H / x86_64, CPU affinity 0, Linux
6.17.0-22-generic; frequency/thermal controls are unchanged. DMD 2.111.0,
LDC 1.41.0 (frontend 2.111.0 / LLVM 19.1.7), DUB 1.40.0 and G++ 15.2.0
are recorded with full build commands. The container used LLVM 20.1.5 and
G++ 13.3.0, so differences are not isolated hardware effects. Each D binary
links the same strict C++ object on its host.

Ranges below span three process medians; Copy groups aggregate all three
sample types. Public/candidate ratios compare complete consumers. Combined/C++
retains the execution-only reference limitations; it is not a language ratio.

| Large group (2048×512) | Compiler | Public/Bounds | Public/Execute | Public/Combined | Combined/C++ |
| --- | --- | --- | --- | --- | --- |
| Flat copy | DMD | 0.852–1.311x | 0.533–1.479x | 0.651–1.123x | 0.756–1.508x |
| Flat copy | LDC | 0.870–1.324x | 0.947–1.531x | 0.994–1.406x | 0.746–1.003x |
| Padded copy | DMD | 9.900–10.740x | 1.086–1.117x | 128.592–2892.533x | 0.878–1.161x |
| Padded copy | LDC | 14.488–21.845x | 1.044–1.068x | 46.604–934.892x | 0.998–1.643x |
| Flat conversion | DMD | 0.999–1.089x | 5.726–6.151x | 4.374–4.776x | 2.055–6.721x |
| Flat conversion | LDC | 0.945–1.012x | 18.150–22.327x | 20.210–23.135x | 0.938–0.998x |
| Padded conversion | DMD | 50.593–51.684x | 1.021–1.023x | 975.357–980.202x | 3.953–4.065x |
| Padded conversion | LDC | 62.394–65.162x | 1.010–1.049x | 891.907–1214.341x | 1.007–1.209x |
| Negative-both conversion | DMD | 51.355–51.856x | 1.006–1.034x | 920.221–929.541x | 2.918–3.516x |
| Negative-both conversion | LDC | 60.606–61.587x | 0.985–1.029x | 463.266–475.638x | 1.542–1.848x |

### Findings and selection

The independent forms confirm that both relation rejection and row execution
matter. On padded Copy, bounds alone improves the complete consumer by
9.900–10.740x under DMD and 14.488–21.845x under LDC; execution alone leaves
the expensive exact scan and is only 1.044–1.117x across the two compilers.
Combined is 128.592–2892.533x / 46.604–934.892x respectively. The exact
multipliers vary by sample type and process, but every measured large
non-flat case benefits from Combined. Universal sample strides still execute
the original checked traversal and receive only the conservative relation
benefit. Flat Copy preserves its original checked whole-plane memcpy route;
no small improvement or regression is established from these noisy results.

For conversion, padded Combined is 975.357–980.202x faster than the complete
DMD baseline and 891.907–1214.341x under LDC. DMD padded Public and Combined
process-time spread is 3.36% / 3.36%, supporting the large directional result.
Flat conversion also benefits (4.374–4.776x DMD, 20.210–23.135x LDC).
LDC flat conversion is in the C++ execution-reference range (0.938–0.998x),
and padded is 1.007–1.209x. DMD remains 3.953–4.065x slower for padded,
2.055–6.721x for flat; negative-both still trails for both compilers
(DMD 2.918–3.516x, LDC 1.542–1.848x). These remaining execution gaps stay
open; successful optimization does not establish family-wide C++ parity.

Actual isolated row assembly again has scalar cvtsi2ss conversion in DMD and
packed cvtdq2ps plus scalar tails in LDC. C++ also has packed conversion.
That is a concrete follow-up lead. It does not causally decompose the complete
public timings, and this evidence does not select explicit SIMD or a compiler
version switch. DMD flat Execute is faster than Combined in these runs despite
an unchanged flat relation route; inspect actual public codegen and measure
controlled candidates before attributing that difference to validation work.

The XPS run is not uniformly low-noise: maximum large-case Public / Combined
three-process spread is 99.55% / 244.36% DMD and 42.09% / 93.35% LDC,
mostly short Copy cases. LDC padded conversion Combined also has 45.06%
spread. Report full ranges; do not infer narrow speedup promises, confidence
intervals or precise near-parity differences. Frequency/thermal controls were
not locked by the collector. Tiny zero medians retain their clock-resolution
qualification. No additional host run was fabricated during archive review.

| Gate / next action | Decision |
| --- | --- |
| Complete consumer semantics, independent backing, shared fallback and trust on XPS | PASS for both compiler families |
| Reference-host direction of non-flat bounds + row improvement | Confirmed; precise Copy timing and small differences remain noisy |
| Same-/cross-type conservative bounds and Canonical row Copy | Selected for a clean, scoped Production implementation PR with original flat route retained |
| Exact conversion bounds + row loop | Qualified as a substantial intermediate improvement; remaining execution gaps must stay tracked through production validation |
| Production source integration | Not performed by this evidence commit; repeat required production checks on the clean implementation |
| Remaining conversion work | Actual full-public codegen and controlled row/pointer candidate study, especially DMD and signed LDC rows |
| Flat Copy microdifferences | No conclusion; preserve existing route and avoid claiming a small speedup |
| Explicit SIMD, compiler switch, AArch64 and threading | Unqualified / deferred |

Research Issue #22 remains open for clean Production promotion and the remaining
conversion execution work. No production API or numerical contract changes.
