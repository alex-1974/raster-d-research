# M2 point-transform semantic contract

Status: complete

Date: 2026-09-30

Issue: raster-d-research #8

Production baseline:

```text
raster-d/develop
f41865226655ac45a6f03956f24e50c27b0d5aa6
```

## Purpose

M2.2 needs a fundamental point-transform primitive without importing image,
radiometric, SIMD or compiler policy into the generic raster API.

R0.5 already measured the representative affine float kernel:

```d
dst[i] = src[i] * gain + bias;
```

Those measurements established important compiler/source-form behavior, but
they did not define a semantic public operation.

This research therefore separates:

```text
what one logical sample transform means
        !=
how one physical execution path implements it
```

## Experiments

The retained experiment is:

```text
experiments/m2_point_transform_contract/
```

The dedicated workflow is:

```text
.github/workflows/m2-point-transform-contract.yml
```

The final matrix was qualified on:

- DMD 2.111.0;
- LDC 1.41.0.

### Callable attribute probe

A compile-time alias transform can be consumed through a wrapper that requires:

```d
@safe
pure
nothrow
@nogc
```

Both compilers accept a conforming transform and reject tested transforms that
are:

- impure;
- throwing;
- GC allocating;
- `@system`.

This makes a compile-time callable materially different from a runtime delegate
or function-pointer API: the generic raster operation can preserve its desired
safety/allocation contract while allowing the caller to own the per-sample
semantics.

### Affine floating-point discriminator

The probe compared:

```d
x * gain + bias
```

with a forced separately rounded multiply followed by add and with explicit
`fma(x, gain, bias)`.

For the retained discriminator both DMD and LDC produced:

```text
ordinary = 0
separate = 0
fused    = -1.42109e-14
```

Therefore an affine convenience operation would have to choose and document a
floating-point contraction/operation-graph policy.

That policy is not required to establish a generic M2 point-transform
primitive.

### Special floating values

An identity transform preserved the transform result semantics for:

- NaN;
- +Inf;
- -Inf;
- +0.0;
- -0.0, including its distinct sign bit.

The generic raster layer therefore does not need to define NaN canonicalization,
saturation, signed-zero normalization or other floating policy.

Those semantics belong to the caller-supplied transform.

### Alias and injectivity probes

A shifted source/destination overlap changes unread source samples during
forward traversal and therefore changes the mathematical point-transform
result.

A non-injective destination is also not generally valid: multiple logical
source coordinates can map to one physical destination sample, making the
final value traversal-order dependent.

These are fundamentally different from M2.1 fill, where every logical
coordinate writes the same value and repeated writes are idempotent.

The first point-transform contract therefore requires:

```text
injective destination
+
physical source/destination disjointness
```

before the first write.

An exact same-buffer in-place transform can be valid for a pure point operator,
but it is a distinct alias contract and is not needed for the first M2.2
surface.

### Raster-layout candidate

A research candidate using the existing raster relation machinery passed for:

- contiguous float source/destination;
- padded rows with untouched sentinels;
- arbitrary signed affine row/sample strides;
- POD same-type samples;
- matching empty planes;
- invalid source plane;
- invalid destination plane;
- shape mismatch;
- non-injective destination rejection before writing;
- exact same-mapping overlap rejection before writing;
- shifted overlap rejection before writing.

Raw descriptor/resource fixture construction remained `@system`, as expected.
The candidate transform operation itself remained `@safe nothrow @nogc`.

## Selected semantic model

The smallest reusable M2.2 primitive is:

```text
same-type source plane
        +
compile-time pure point transform T -> T
        +
same-shaped injective disjoint writable destination plane
        ->
transformed destination
```

The raster layer owns:

- plane selection;
- shape validation;
- destination injectivity;
- source/destination physical relation;
- layout traversal;
- lifetime and writable capability;
- failure-before-write for structural relation failures.

The transform owns:

- arithmetic;
- NaN/Inf behavior;
- signed-zero behavior;
- saturation/clamping if deliberately coded;
- FMA or non-FMA expression semantics;
- POD field semantics.

The raster layer performs no implicit conversion or normalization.

## Recommended production API shape

Provisional naming:

```d
enum RasterTransformError : ubyte
{
    none,
    invalidSourcePlane,
    invalidDestinationPlane,
    shapeMismatch,
    nonInjectiveDestination,
    sourceDestinationOverlap
}

bool tryTransformRasterPlane(alias transform, T)(
    scope RasterView!T source,
    size_t sourcePlaneIndex,
    scope ref WritableRasterView!T destination,
    size_t destinationPlaneIndex,
    out RasterTransformError error
)
@safe
nothrow
@nogc;
```

The implementation should force transform invocation through a helper whose
attributes are:

```d
@safe pure nothrow @nogc
```

so invalid transform aliases fail at compile time.

The raster operation itself cannot be `pure` because it mutates caller-owned
storage.

### Success contract

For every logical source coordinate, the operation computes conceptually:

```d
destination(x, y) = transform(source(x, y));
```

for the selected planes.

A valid matching empty shape succeeds and does not invoke the transform.

All validated resident affine layouts are semantically supported.

Execution order is not public semantics because the transform is pure and each
successful destination mapping is injective.

### Failure contract

Structural failure occurs before the first destination write.

The first production slice should reject:

- invalid source plane;
- invalid destination plane;
- shape mismatch;
- non-injective destination;
- any detected physical source/destination sample-byte overlap.

Existing checked affine relation machinery should remain internal.

## KEEP

- compile-time alias point transform;
- same-type `T -> T`;
- generic `isRasterSampleType!T`, including POD samples;
- `@safe pure nothrow @nogc` transform requirement;
- out-of-place RasterView -> WritableRasterView as the first operation;
- equal logical shape;
- explicit source and destination plane indices;
- injective destination;
- exact physical source/destination disjointness;
- failure before first write;
- empty success without callback execution;
- allocation-free operation;
- all validated signed affine layouts;
- internal replaceable execution specialization;
- caller-owned numerical semantics.

## REJECT for the first M2.2 surface

- a built-in float affine transform as the fundamental primitive;
- raster-owned FMA/contraction policy;
- runtime delegate/function-pointer transform API;
- stateful/impure transform callbacks;
- throwing callbacks;
- GC-allocating callbacks;
- `@system` callbacks;
- non-injective destination semantics;
- arbitrary or shifted source/destination overlap;
- implicit numeric conversion;
- implicit clamp/saturation;
- image brightness/contrast/gamma semantics;
- public Mir/SIMD/compiler-layout types;
- hidden parallelism.

## DEFER

- exact in-place point transform;
- cross-type generic transform;
- fallible/result-carrying transform callbacks;
- runtime-selected transforms;
- affine convenience wrappers;
- LUT-specific API;
- compiler-specific source forms;
- vectorization/SIMD;
- multithreaded execution.

## Production recommendation

Promote one narrow M2.2 slice:

```text
public generic same-type compile-time point transform
+
checked out-of-place disjoint relation
+
injective writable destination
```

Do not promote the research implementation literally.

Production should reuse its existing validated view, writable capability and
affine-relation contracts, add public-surface compile probes, and keep every
execution detail below the semantic API.

Performance specialization remains M3 work.
