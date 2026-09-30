# Retained Block Assembly Research

Status: active research. E9.1 complete.

Issue: raster-d-research #7

## 1. Purpose

This research connects the already promoted M1 contracts without changing their
separation:

```text
dependency/request geometry
    -> cache-block decomposition policy
    -> retained lookup/materialization
    -> request assembly
```

The central invariant remains:

```text
ProviderBlock != CacheBlock != Region != ProcessingTask
```

M1.5 provides identity-agnostic retained storage. It intentionally does not
select cache-block geometry.

## 2. E9.1 — block-grid policy boundary

E9.1 isolates block geometry before retained ownership or source materialization
is added.

It compares two valid fixed-grid policies:

1. grid anchored at global logical zero;
2. grid anchored at the logical-extent origin.

Both use the same block dimensions.

The experiment asks whether either anchor is required by raster semantics.

## 3. Required properties

For either policy:

- every returned block lies inside the logical extent after edge clipping;
- the requested region is completely covered;
- no requested pixel depends on provider-native block geometry;
- partial edge blocks remain explicit logical regions;
- non-zero logical extents work;
- huge representable logical origins work without overflow;
- block geometry remains storage/reuse policy rather than operation semantics.

## 4. Interpretation

If two policies both satisfy the same logical request correctly but produce
different retained block sets, then block-grid anchoring is not intrinsic raster
semantics.

That would support a later architecture where block decomposition is supplied
as a package-internal policy/caller capability rather than hard-coded inside
`RetainedRasterStore`.

Passing E9.1 alone does not justify production promotion.


## 5. E9.1 result — block-grid anchoring is policy

Status: **PASS** on DMD 2.111.0 and LDC 1.41.0.

Verified research head:

`3e732f3930fc31863cbe47f7daff863fd439aad0`

Verified raster-d develop:

`813e73c4fc2f3fd2be74e39989da10c6723e6f3a`

GitHub Actions run:

`36711335792`

Both compiler jobs produced:

```text
E9.1 PASS: cache-block grid anchor is policy, not raster semantics
```

The experiment demonstrated:

1. a fixed block grid anchored at global logical zero can cover an arbitrary
   request exactly;
2. a fixed block grid anchored at the logical-extent origin can cover the same
   request exactly;
3. the two policies produce different retained block regions for the same
   semantic request;
4. both policies keep every clipped block inside the logical extent;
5. global-zero anchoring naturally produces partial edge blocks for a
   non-aligned non-zero logical extent;
6. extent-origin anchoring works at very large logical origins near
   `size_t.max` without whole-dataset arithmetic or unchecked wraparound;
7. provider-native 16 x 8 block geometry remains irrelevant to a 12 x 10 cache
   block policy.

### E9.1 conclusion

No single block-grid anchor is implied by raster semantics.

Therefore:

```text
cache-block decomposition = storage/reuse policy
```

not:

```text
cache-block decomposition = RetainedRasterStore identity/storage semantics
```

A later production integration should accept or instantiate a block-decomposition
policy rather than hard-code a universal global-zero or extent-origin grid
inside the retained store.

## 6. Next experiment — E9.2 retained cold/warm/overlap assembly

E9.2 adds real retained RasterLease values and a research-local store oracle.

It must verify:

- cold multi-block request assembly;
- warm repeat with no source rematerialization;
- overlapping second request with partial block reuse;
- source provider blocks remain 16 x 8 while cache blocks remain 12 x 10;
- direct source materialization equals assembled retained-block output exactly;
- acquired block leases can be consumed one at a time and released during
  assembly;
- request destination geometry remains independent of cache-block geometry.

The production M1.5 store is package-internal and is deliberately not bypassed
from this external research repository. E9.2 therefore reproduces only the
minimum lookup/retention semantics in research code while using real public
RasterLease ownership.
