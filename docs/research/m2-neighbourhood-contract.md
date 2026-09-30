# M2.3 neighbourhood-kernel semantic contract

Status: complete

Date: 2026-09-30

Issue: raster-d-research #10

Production baseline:

```text
raster-d/develop
8b2be33bab48365489af892fafdd0c2bccc64f12
```

## Purpose

M2.3 needs one reusable local-neighbourhood primitive without promoting the
M1.7 test oracle, image filtering policy, scheduler policy or R0.5 benchmark
source shape into the public raster API.

The retained evidence already establishes two independent facts:

1. R0.3 / M1.7 prove neighbourhood dependency and decomposition semantics.
2. R0.5 proves that neighbourhood execution needs a validated semantic boundary
   with replaceable internal hot-loop forms.

This research defines the semantic operation between those layers.

## Existing evidence

### R0.3 / M1.7

The established radius-one dependency is:

```text
DependencyMargins(1, 1, 1, 1)
```

and the central invariant is:

```text
sufficient context
        ->
whole-request result == reassembled decomposed result
```

Processing-task boundaries may therefore create overlapping source halos but
must not change output values.

Logical-image edges remain different from task boundaries.

A ContextDeficit is not a border policy.

### R0.5

The qualified 3 x 3 execution work establishes:

- validate complete geometry before entering the hot loop;
- signed Canonical row stride remains semantically supported;
- Universal/sample-strided layouts remain part of the generic representation;
- DMD and LDC may need different internal optimized source forms;
- no public pointer or Mir representation follows from those measurements;
- no handwritten SIMD or hidden parallelism is justified.

Performance specialization remains an internal implementation concern.

## Candidate selected by this research

The first M2.3 primitive is deliberately fixed to a radius-one rectangular
neighbourhood:

```text
3 x 3 source neighbourhood
        ->
one destination sample
```

The caller supplies:

- an already-materialized resident `RasterView!T`;
- one source plane;
- `sourceOutputRegion`, expressed relative to the source view;
- a writable destination plane whose shape equals `sourceOutputRegion`;
- a compile-time kernel.

For every destination coordinate, raster-d snapshots the corresponding nine
source samples in row-major order and conceptually evaluates:

```d
destination(x, y) = kernel(neighbourhood);
```

where:

```text
neighbourhood[0..2] = row y-1
neighbourhood[3..5] = row y
neighbourhood[6..8] = row y+1
```

and index 4 is the center sample.

## Why fixed 3 x 3 first

A generalized arbitrary-radius/window API would immediately require public
answers for:

- window shape representation;
- dynamic versus compile-time dimensions;
- accessor lifetime;
- sparse footprints;
- coefficient layout;
- larger temporary storage;
- possible cross-type output.

None of those are required to establish the first useful neighbourhood
primitive.

Both R0.3 and R0.5 already contain direct radius-one / 3 x 3 evidence.

Therefore M2.3 should promote the proven semantic family first and generalize
only from later consumer evidence.

## Kernel surface

The selected kernel form is a compile-time callable over a fixed nine-sample
snapshot:

```d
T kernel(ref const(T)[9] neighbourhood)
```

The invocation boundary requires the kernel to be usable as:

```text
@safe pure nothrow @nogc
```

The research compiler probes confirm on DMD 2.111.0 and LDC 1.41.0 that:

- a conforming kernel compiles;
- impure kernels are rejected;
- throwing kernels are rejected;
- GC-allocating kernels are rejected;
- @system kernels are rejected.

### Why a snapshot rather than a public neighbourhood view

A nine-value snapshot:

- introduces no new public borrow/view type;
- exposes no source pointer, stride or Mir representation;
- cannot outlive source storage;
- makes kernel semantics independent of physical layout;
- keeps the kernel pure and allocation-free;
- leaves internal execution free to replace literal snapshot construction with
  a specialized hot path later.

A source-view-plus-center callable would expose more raster machinery to every
kernel and make traversal/layout concerns part of the callable contract.

Nine separate scalar parameters are mechanically workable but produce a more
awkward callable interface without adding semantic capability.

## Resident geometry contract

`sourceOutputRegion` is a region relative to the supplied resident source
view.

For a non-empty radius-one operation it must have one resident source sample of
context on every side.

Conceptually the required resident source rectangle is:

```text
sourceOutputRegion expanded by 1 on left/top/right/bottom
```

and must be fully contained in the source view.

The destination dimensions must equal:

```text
sourceOutputRegion.width
sourceOutputRegion.height
```

The destination's own resident origin is independent; only its logical
dimensions correspond to the output region.

This is a resident execution contract only.

It does not attach logical/global image coordinates to RasterView.

## Relationship to M1 dependency planning

The neighbourhood operation does not derive logical dependencies.

M1.1 and M1.2 already own:

```text
logical output request
        ->
DependencyMargins
        ->
valid logical input + ContextDeficit
        ->
residentInput + residentOutput
```

For the ordinary M1 path, M2.3 can consume:

```text
source resident view = materialized residentInput
sourceOutputRegion   = plan.residentOutput
```

This keeps the layers distinct:

```text
logical dependency planning
        !=
resident neighbourhood execution
```

The operation must not accept or reinterpret `ContextDeficit`.

## Logical-edge and border semantics

M2.3 defines no border policy.

If M1 planning reports missing logical context, a higher layer must decide
whether to:

- reject the operation for that requested output;
- materialize caller-synthesized border samples according to an explicit
  policy;
- choose another operation.

Once M2.3 is called, it requires the complete resident 3 x 3 context.

Therefore:

```text
missing resident halo
        ->
explicit unsatisfiedNeighbourhood failure
```

not clamp, mirror, wrap, constant fill or silent clipping.

This also permits a future caller to supply synthetic border samples without
making raster-d aware of the policy that produced them.

## Empty output

A matching empty destination and empty `sourceOutputRegion` succeed.

No halo is required and the kernel is not invoked.

This follows the existing raster rule:

```text
empty != failure
```

## Destination semantics

The destination mapping must be injective.

Unlike fill, neighbourhood results generally vary by logical coordinate, so
multiple output coordinates may not collapse onto the same physical sample.

Destination injectivity is checked before the first write.

## Source/destination overlap

The first M2.3 primitive requires exact physical disjointness between:

- every source sample byte reachable by the expanded 3 x 3-required source
  rectangle; and
- every destination sample byte.

All overlap is rejected before the first write, including an exact apparent
in-place mapping.

This is intentionally conservative at the semantic level. A future carefully
ordered in-place neighbourhood operation would be a different contract because
neighbouring outputs consume overlapping source samples.

### Exact relation implementation

The research prototype uses a simple allocation-free pairwise oracle because
it is correctness evidence, not a production algorithm.

That O(N^2) oracle must not be promoted.

The existing production Diophantine machinery already contains the needed
general form:

- `classifySameTypeLinePair()` accepts separate
  `sourceCount` / `targetCount`;
- `boundedLinearEquation()` likewise accepts separate finite counts.

Only the outer
`classifySameTypeAffine2DByteOverlap()` wrapper currently imposes equal
source/target width and height.

Production M2.3 should therefore refactor/generalize that internal wrapper to
classify two differently shaped affine rectangles exactly, while retaining the
existing equal-shape API as a wrapper or equivalent internal call.

The generalization must preserve the existing exact reachable-sample semantics.
It must not regress to address-envelope overlap, because interleaved disjoint
sample sets can have overlapping envelopes.

A defensive exact allocation-free fallback may remain for arithmetic-classifier
failure, as in the existing copy/transform operations, but it is not the normal
large-raster path.

## Layout evidence

The candidate matrix passes on both required compilers for:

- contiguous source and destination;
- padded positive Canonical source rows;
- negative Canonical source rows;
- Universal/sample-strided source;
- negative/signed-stride destination;
- one resident source producing multiple output samples;
- task-local independently materialized halos whose reassembled result exactly
  equals whole execution.

The semantic contract therefore does not require contiguous or positive-stride
storage.

R0.5 optimized source forms remain future internal specializations.

## Structural failures

The candidate explicitly qualifies:

- invalid source plane;
- invalid destination plane;
- destination shape mismatch;
- insufficient resident neighbourhood context;
- non-injective destination;
- source/destination overlap.

These failures occur before the first destination write.

## Decomposition independence

The retained candidate executes the same kernel over:

1. one whole resident source with halo;
2. two independently materialized task-local resident sources, each containing
   only its own required halo.

Reassembled task output is exactly equal to whole output.

This is a direct M2.3-level confirmation of the stronger R0.3/M1.7 invariant:
the kernel contract depends on resident context, not processing-task
boundaries.

## Recommended production surface

Provisional shape:

```d
enum RasterNeighbourhood3x3Error : ubyte
{
    none,
    invalidSourcePlane,
    invalidDestinationPlane,
    destinationShapeMismatch,
    unsatisfiedNeighbourhood,
    nonInjectiveDestination,
    sourceDestinationOverlap
}

bool tryApplyRasterNeighbourhood3x3(alias kernel, T)(
    scope RasterView!T source,
    size_t sourcePlaneIndex,
    Region2D sourceOutputRegion,
    scope ref WritableRasterView!T destination,
    size_t destinationPlaneIndex,
    out RasterNeighbourhood3x3Error error
)
@safe
nothrow
@nogc;
```

The exact public name may be adjusted during Production review, but the
semantic shape should not widen without new evidence.

The kernel must be compile-time constrained through a private invocation helper
to:

```d
@safe pure nothrow @nogc
T(ref const(T)[9])
```

## KEEP

- fixed radius-one / 3 x 3 as the first neighbourhood primitive;
- same-type `T -> T`;
- compile-time kernel;
- row-major nine-sample value snapshot;
- `@safe pure nothrow @nogc` kernel requirement;
- explicit resident-relative `sourceOutputRegion`;
- already-materialized source input;
- destination shape equal to output-region shape;
- complete one-sample resident halo required;
- no border policy;
- injective destination;
- exact required-source/destination byte disjointness;
- structural failure before first write;
- matching empty success without kernel invocation;
- all validated signed affine source/destination layouts;
- decomposition independence;
- internal validated-boundary -> replaceable execution path.

## REJECT for the first M2.3 surface

- promoting the M1.7 weighted test kernel as a built-in operation;
- a built-in float box blur/sum as the fundamental API;
- implicit border clamp/mirror/wrap/constant behavior;
- passing ContextDeficit into the execution kernel;
- deriving logical dependency inside M2.3;
- public source pointers;
- public Mir slices;
- public runtime neighbourhood view/accessor type;
- nine separate public callable parameters;
- runtime delegate/function pointer kernels;
- non-injective destination;
- source/destination overlap;
- O(N^2) alias classification as the normal production path;
- hidden scheduling or worker threads;
- compiler-specific public API;
- handwritten SIMD.

## DEFER

- arbitrary radius;
- rectangular dimensions other than 3 x 3;
- sparse footprints;
- cross-type neighbourhood transforms;
- public convolution/coefficient API;
- exact in-place neighbourhood algorithms;
- explicit border-policy API;
- fallible/result-carrying kernels;
- runtime-selected kernels;
- compiler/layout-specialized hot paths;
- SIMD;
- multithreading;
- GPU execution.

## Production recommendation

Promote one narrow M2.3 slice:

```text
already-materialized RasterView!T
        +
resident-relative 3 x 3 output region
        +
compile-time pure nine-sample kernel
        +
injective physically disjoint WritableRasterView!T
        ->
same-type neighbourhood output
```

As part of that production slice, generalize the existing internal exact
same-type affine-overlap classifier to support asymmetric source and target
rectangle dimensions.

Do not promote the research pairwise overlap oracle or the M1.7 test kernel.

Performance specialization remains an M3 concern.
