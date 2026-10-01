# M3.2 production point-transform hot-path qualification

Status: in progress

## Purpose

Qualify the smallest internal fast path for the existing public
`tryTransformRasterPlane!transform()` operation.

Production baseline:

```text
raster-d/develop
252bc9ab0c868820a9dc5b2432119d8ac0f15903
```

Research baseline:

```text
raster-d-research/main
5ff4f488919a3786ae0793977027e4b19081babf
```

Tracked by research Issue #14.

## Existing evidence

R0.5 established that affine point transforms are strongly source-form
sensitive under DMD 2.111 while LDC 1.41 generally converges to the same broad
vectorized class for several source forms.

That evidence is not yet a Production promotion decision because:

- the fastest DMD D-array expression represented one built-in affine
  expression rather than an arbitrary caller-supplied `T -> T` alias;
- the real M2.2 Production operation performs semantic `trySample()` and
  `trySetSample()` calls in the inner loop;
- representative Production-shaped timing has not yet compared that path with
  a validated check-free Canonical executor.

## Semantic boundary

M3.2 must not change:

- public API;
- transform attribute contract;
- shape validation;
- empty success;
- destination injectivity requirement;
- exact source/destination overlap rejection before write;
- signed row/sample-stride support;
- POD sample support;
- error ordering.

The candidate is internal execution only.

## First experiment

Compare:

```text
current public M2.2 operation

versus

same validation boundary
    -> sourceSampleStride == 1
    -> destinationSampleStride == 1
    -> check-free row/pointer executor
```

Universal/sample-strided layouts remain on the existing semantic path.

The first benchmark uses one representative float affine transform only to
exercise an arbitrary compile-time alias through the real M2.2 shape. It does
not introduce affine semantics into raster-d.

Matrix:

- DMD 2.111;
- LDC 1.41;
- positive/negative source row stride;
- positive/negative destination row stride;
- small, medium and large regions;
- padded Canonical rows.

Hosted CI timing is diagnostic. Stable promotion ratios require repeated local
reference-machine runs.

## Decision gate

Promote a general Canonical executor only if:

1. output is bit-identical to current Production for the tested transform;
2. existing M2.2 structural semantics remain unchanged;
3. the representative Production-shaped path improves materially;
4. Universal/sample-strided fallback remains exact;
5. no public layout/compiler vocabulary is introduced.

Compiler-specific source forms are a second-stage question only if the general
Canonical result leaves a material compiler-specific gap.

## Continuation after the bounds-prefilter production handoff

PR #53 establishes production `b263477bdbbe0dc3e8c469ac3867eda345ba364c`.
The new isolated comparison is recorded in `m3-transform-executor.md` and
`experiments/m3_transform_executor/`; both sides use the same merged checked
bounds wrapper. The historical harness above remains evidence and is not used
to attribute bounds improvements to Canonical execution. Production promotion
and final pointer/slice selection remain gated by stable reference measurements.
