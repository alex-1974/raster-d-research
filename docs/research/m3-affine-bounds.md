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
