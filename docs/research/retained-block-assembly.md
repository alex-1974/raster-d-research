# Retained Block Assembly Research

Status: active research. E9.1 in progress.

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
