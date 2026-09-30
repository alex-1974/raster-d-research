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
