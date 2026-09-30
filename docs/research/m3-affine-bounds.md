# M3 affine bounding-range fast-reject qualification

Status: in progress

Tracked by research Issue #15.

## Discovery

M3.2 point-transform research showed that the current exact same-type affine
source/destination overlap relation can dominate the entire operation for large
ordinary disjoint allocations.

For an equal-shaped 2048 x 512 relation the current general classifier may
compare 512 x 512 = 262,144 outer line pairs before execution.

A conservative physical bounding interval can reject the overwhelmingly common
separate-allocation case in O(1):

```text
provably disjoint physical bounds
        -> exact sample-byte sets are disjoint

otherwise
        -> preserve current exact affine relation
```

The second branch is mandatory. Overlapping bounds do not imply overlapping
sample sets.

## First correctness gate

The first experiment compares a research fast-reject wrapper against direct
finite sample-byte enumeration over a systematic bounded domain.

It covers:

- empty rectangles;
- width/height 1..5;
- sample sizes 1, 2, 4 and 8;
- positive, negative and zero row/sample strides;
- equal and differently shaped rectangles;
- base-address displacements;
- true overlap;
- disjoint ranges;
- overlapping bounds with sparse/interleaved disjoint samples.

Acceptance criterion:

> the fast reject must never return disjoint when direct finite enumeration
> finds any overlapping sample byte.

The first bounded-domain probe is intentionally separate from checked-arithmetic
limit qualification. Large-address and overflow behavior is a later gate.

## Performance gate

The relation benchmark compares:

- current exact same-type rectangle relation;
- bounding-fast-reject wrapper;

for large separately allocated logical address ranges.

Hosted timing is diagnostic only.

## Production boundary under investigation

If the correctness gates hold, Production should prefer one reusable checked
physical-bounds stage inside or immediately adjacent to the affine relation
layer. Individual operations should not duplicate unchecked min/max stride
arithmetic.


## Gate 1 result — bounded-domain correctness

Research head:

```text
ea98f22ce8ca619cd8d18ad175788b8d3891d88b
```

Workflow:

```text
M3 Affine Bounds Research #4
run 36768200508
DMD 2.111: success
LDC 1.41: success
```

Both compilers produced the same deterministic result:

```text
m3_affine_bounds_sparse_counterexample PASS
m3_affine_bounds_correctness PASS
cases=100000
fast_rejects=68105
overlapping_bounds_but_disjoint=4160
exact_mismatches=0
```

Interpretation:

- no tested case produced a false `disjoint` fast-reject;
- the fast-reject discharged 68.105 / 100.000 cases without needing the exact
  relation;
- 4.160 cases explicitly demonstrated why bounding-range overlap cannot be
  treated as sample overlap;
- the existing exact relation agreed with direct finite enumeration whenever
  it returned a non-arithmetic-failure result;
- positive/negative/zero row and sample strides, empty/small rectangles,
  multiple sample sizes and differently shaped rectangles are represented in
  the deterministic corpus.

Gate 1 therefore supports the one-way rule:

```text
provably disjoint bounds -> exact sample relation is disjoint
```

It does not justify:

```text
overlapping bounds -> sample overlap
```

## Remaining gates

Before Production promotion:

1. implement checked address/offset arithmetic covering `size_t.max`,
   `ptrdiff_t.min`, large extents and overflow boundaries;
2. prove the checked fast-reject never changes an exact overlap result into
   disjoint;
3. preserve the current exact classifier whenever bounds overlap or cannot be
   represented;
4. benchmark the relation stage itself and representative Production consumers;
5. decide whether the optimization belongs inside
   `classifySameTypeAffine2DRectanglesByteOverlap` or in one reusable
   validated-plane prefilter immediately above it;
6. qualify differently shaped neighbourhood source/output rectangles;
7. assess cross-type reuse separately rather than assuming same-type evidence
   applies.


## Gate 2 result — checked integer/address limits

Research head:

```text
4e19754a0e8e83198c6dfa998952e9e94f59b00b
```

Workflow:

```text
M3 Affine Bounds Research #9
run 36769995996
DMD 2.111: success
LDC 1.41: success
```

Both compilers produced:

```text
m3_affine_bounds_sparse_counterexample PASS
m3_affine_bounds_correctness PASS
cases=100000
fast_rejects=68105
overlapping_bounds_but_disjoint=4160
exact_mismatches=0

m3_affine_bounds_extreme PASS
fixtures=12
checked_oracle_cases=8
conservative_unknown_cases=4
fast_rejects=6
exact_arithmetic_failures=0
```

The checked research implementation mirrors the arithmetic structure already
used by Production backing validation:

```text
checked coordinate * stride
    -> axis min/max offsets
    -> checked signed offset addition
    -> checked element-offset to byte magnitude
    -> checked base +/- byte offset
    -> checked half-open upper endpoint
```

The gate covers:

- `ptrdiff_t.min`;
- `ptrdiff_t.max`;
- the signed-address midpoint;
- near-`size_t.max` valid intervals;
- sample-end overflow;
- coordinate/stride overflow;
- combined affine-offset overflow;
- byte-scaling overflow;
- negative traversal near the upper address boundary;
- opposite address-space edges;
- overlapping bounds with sparse-disjoint samples;
- overlapping bounds with genuine sample overlap.

In every arithmetic-uncertain case the fast-reject remains conservative:
it returns no proof and therefore preserves the exact relation path.

### Domain discrepancy found during Gate 2

The existing affine-relation unit tests include algebraic address cases such as
a one-byte sample beginning at `size_t.max`.

That is valid input for the relation's integer algebra but it is not a possible
already-validated RasterView backing sample, because the required half-open
sample interval

```text
[size_t.max, size_t.max + 1)
```

cannot be represented and would fail retained-resource validation.

This is not a Production correctness bug because the affine relation documents
validated raster views as its consumer precondition.

It does matter for the optimization boundary:

- a Production fast-reject should be defined over validated reachable raster
  bytes rather than silently broadening its contract to every algebraic
  relation input;
- relation-only tests may continue to exercise the wider algebraic domain;
- consumer-facing optimization must preserve the current exact classifier for
  any case where the validated-byte bound cannot be established.

## Gate 2 conclusion

KEEP for further qualification:

- checked conservative affine byte bounds;
- one-way `bounds disjoint -> sample sets disjoint` fast-reject;
- exact-classifier fallback for overlapping or unrepresentable bounds.

REJECT:

- unchecked pointer/stride min-max arithmetic in individual consumers;
- treating a bounding-envelope overlap as exact sample overlap.

Still required before Production promotion:

1. relation-stage benchmark using the checked implementation;
2. representative point-transform and neighbourhood consumer measurements;
3. differently shaped source/output rectangles;
4. decide the single package-internal integration point;
5. verify that exact overlap/error ordering is unchanged after integration.


## Gate 3 result — checked relation-stage performance

Research head:

```text
498df051daee2a5bb86303c2847ed6b2aae49bce
```

Workflow:

```text
M3 Affine Bounds Research #13
run 36770664732
DMD 2.111: success
LDC 1.41: success
```

The hardened timing uses real heap-backed float allocations and a batch of
100,000 checked fast-reject calls per timing sample. The target base alternates
between two runtime-valid addresses to prevent the simplest loop-invariant
hoisting.

Representative hosted medians:

| Relation shape | DMD exact | DMD checked bound / call | LDC exact | LDC checked bound / call |
|---|---:|---:|---:|---:|
| 128x64 vs 128x64 | 1.784 ms | 85.2 ns | 0.744 ms | 20.7 ns |
| 512x256 vs 512x256 | 28.637 ms | 85.2 ns | 11.869 ms | 21.9 ns |
| 2048x512 vs 2048x512 | 112.179 ms | 85.3 ns | 47.840 ms | 20.6 ns |
| 2050x514 vs 2048x512 | 115.317 ms | 85.2 ns | 48.121 ms | 21.7 ns |

The exact relation scales with the finite line-pair search. The checked
bounding reject remains effectively constant with rectangle dimensions.

The resulting exact/fast ratios are intentionally **not** treated as stable
Production speedup claims:

- hosted runners are not the local reference machine;
- the batch alternates only two disjoint runtime target addresses;
- compiler optimization can simplify the repeated benchmark more aggressively
  than a complete raster consumer;
- a relation-only win does not by itself prove the same end-to-end consumer
  gain.

Gate 3 therefore establishes the engineering fact needed for the next step:

> In the common provably-disjoint validated-raster case, checked conservative
> bounds remove a relation stage whose cost currently grows with rectangle
> dimensions, while the prefilter itself is dimension-independent and tiny
> relative to the current exact search.

The next required evidence is a complete Production-shaped consumer using the
same checked arithmetic and preserving the current exact fallback.

## Gate 4 harness — complete same-type consumers

Implemented in `experiments/m3_affine_consumer/` against pinned production
`252bc9ab0c868820a9dc5b2432119d8ac0f15903`.

The generator verifies both source hashes and changes only module/operation
identity, error-type import and relation import. Validation, error ordering,
execution and defensive arithmetic-failure enumeration stay source-identical.
There is no Canonical point-transform candidate in this gate: B isolates the
relation gain over A, the current public operation.

The shared wrapper reuses the Gate-2 checked arithmetic implementation rather
than the earlier point-transform probe's unchecked envelope arithmetic.
Overlapping/unrepresentable bounds preserve exact classification.

Container qualification passed on DMD 2.111 and LDC 1.41 / LLVM 20.1.5:

- 10 inherited transform unittest blocks;
- 12 inherited neighbourhood unittest blocks;
- explicit relation fallback unittest;
- four differential shared-backing consumers (sparse-disjoint and real overlap);
- both complete release matrices, including 2050×514 neighbourhood source versus
  2048×512 destination, both row directions, padding and sample stride +2/-2;
- full output/padding fingerprint after every measured operation;
- repeated original Gates 1–3: identical correctness counts and no mismatches.

Raw consumer logs and environment are retained under
`experiments/m3_affine_consumer/evidence/2026-09-30-container/`.
Timing is diagnostic only, with no performance threshold. This container is
not the stable XPS reference machine; noisy workload and operation-dispatch
overhead preclude treating its ratios as production promises.

CI now pins the production baseline and includes inherited consumer tests,
complete release execution, and uploaded raw evidence. The pushed-head CI
result must be verified separately.

Workspace note: these standalone checkouts did not contain `.workspace/`.
Both tracked `AGENTS.md` explicitly permit following tracked repository
documentation in that case. Supplied historical workspace README/ROADMAP still
describe raster-d as a future extraction; current production README and ADR
0003 establish the accepted pivot. No canonical workspace files were changed.

Decision: KEEP for continued qualification. Before production promotion:

1. verify DMD/LDC CI for this harness;
2. run three independent measurements on the XPS, including its LLVM 19.1.7;
3. decide the single internal integration point from the validated-byte versus
   algebraic-domain evidence;
4. preserve existing exact classifier and all consumer error/fallback semantics.

Issue #14, Canonical transform execution and cross-type reuse remain deferred.
