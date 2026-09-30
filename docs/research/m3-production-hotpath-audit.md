# M3 production hot-path audit

Status: in progress

Date: 2026-09-30

Research issue: #12

Production baseline:

```text
raster-d/develop
5bc269b9455e28c4e5d6454e72fe254ace51dcff
```

## Purpose

M3 starts from the production implementation that actually exists after M2,
not from the historical R0.5 to-do list.

The first task is therefore to compare current production source shapes with
the retained R0.5 evidence and select one optimization slice with the strongest
direct evidence.

No optimization is promoted merely because an older research variant was fast.

## Workspace and repository constraints

The relevant engineering rules remain:

- benchmark before optimization;
- keep semantic API and execution source form separate;
- DMD remains a correctness/compiler comparison target;
- LDC/LLVM is the primary performance compiler;
- compiler/version specialization must be centralized and measured;
- no hidden worker threads or scheduler policy;
- compile-negative tests remain compile-only;
- public API must remain small;
- architecture-specific conclusions must not be extrapolated from x86-64 to
  AArch64 without evidence.

Production BENCHMARK.md further requires:

- deterministic correctness preflight;
- raw timing samples and median;
- compiler/version/flags;
- layout and workload dimensions;
- stable local reference machine for absolute historical baselines;
- hosted-runner timings as informational/non-gating evidence.

## Production-vs-R0.5 audit

### Same-type copy

Current Production already has a classified flat-contiguous path that reaches
checked `memcpy`.

R0.5 showed that the checked contiguous copy path is close to the fast raw copy
forms and that the older Mir scalar copy shape was not a suitable universal
fast path.

Conclusion:

```text
M3.1 first target: NO
```

Copy may still need affine/non-contiguous tuning later, but the strongest
obvious contiguous optimization is already present.

### Exact ubyte -> float conversion

R0.5 isolated the old Mir contiguous conversion as a major bottleneck and
selected a safe D-slice indexed loop as the leading Production candidate.

Current Production already uses
`scalarConvertUbyteToFloatSlice()` after contiguous classification.

Conclusion:

```text
historical R0.5 promotion already present
M3.1 first target: NO
```

Future work may benchmark newer compilers and non-contiguous layouts, but M3
must not re-implement this completed source-form change.

### Fill

Current Production `tryFillRasterPlane()` reaches the scalar semantic
reference loop and calls `WritableRasterView.trySetSample()` for every
logical coordinate.

R0.5 raw contiguous float fill showed:

- DMD slice fill materially faster than raw scalar fill in the retained run;
- LDC scalar and slice fill effectively equivalent.

That evidence does not yet compare the actual public Production fill path,
generic sample types, non-injective legal destinations, or signed/Universal
layouts.

Conclusion:

```text
likely optimization opportunity
evidence insufficient for immediate promotion
DEFER behind first production-shaped benchmark
```

### Strict float -> double reduction

The public strict reduction preserves a specific row-major floating-point
operation graph.

Production already dispatches by execution layout and uses internal scalar/Mir
kernels. R0.5 performance work on reductions is informative, but any
reassociation/vector reduction would change strict numerical semantics unless
the exact operation graph is preserved.

Conclusion:

```text
performance-sensitive
numerical semantic risk higher than pointwise/neighbourhood kernels
not first M3 promotion
```

### Same-type point transform

Current Production validates structure and aliasing once, then executes each
sample through `RasterView.trySample()` and
`WritableRasterView.trySetSample()`.

R0.5 affine pointwise experiments demonstrated large source-form differences,
especially under DMD, and showed that LDC can often optimize simple portable
forms well.

However the retained affine benchmark used a concrete arithmetic expression,
whereas M2.2 exposes a generic compile-time `T -> T` transform callback and
supports POD sample types.

Conclusion:

```text
strong candidate for later M3 work
requires production-shaped callback benchmark first
```

### Fixed 3 x 3 neighbourhood

Current Production `tryApplyRasterNeighbourhood3x3!kernel()` validates:

- source/destination plane indices;
- destination shape;
- complete resident halo;
- destination injectivity;
- exact physical disjointness.

After those checks, every output sample currently performs:

```text
9 x RasterView.trySample()
1 x compile-time kernel callback
1 x WritableRasterView.trySetSample()
```

R0.5 directly studied this operation family and established:

- complete geometry should be validated once;
- a narrow check-free Canonical hot kernel can be materially faster;
- signed Canonical row stride remains a supported semantic;
- DMD 2.111 benefits from the ordinary trusted check-free kernel for both row
  directions;
- LDC 1.41 positive Canonical already performs well in the integrated trusted
  form;
- LDC 1.41 negative Canonical can select a scalar loop version because of
  optimizer legality/versioning guards;
- a preserved out-of-line row-kernel boundary restores the fast class for that
  LDC negative-Canonical case;
- DMD does not benefit from that no-inline specialization;
- handwritten SIMD is not justified;
- compiler/layout specialization must remain internal and centralized.

This is the strongest direct match between retained R0.5 evidence and a current
public M2 operation.

Conclusion:

```text
M3.1 selected target
```

## M3.1 hypothesis

The first Production optimization should preserve the complete public M2.3
semantic boundary and replace only the already-approved execution path for
eligible layouts.

Candidate architecture:

```text
public M2.3 structural validation
        |
        +-- generic / Universal
        |       -> existing semantic reference path
        |
        '-- Canonical source + injective compatible destination
                -> check-free internal kernel
                        |
                        +-- ordinary integrated form
                        |
                        '-- LDC-qualified negative-row specialization
                            only if final production-shaped evidence supports it
```

The public function, error enum, border semantics, alias policy and callback
shape do not change.

## First benchmark question

Before implementing a Production fast path, measure the exact public callback
shape:

```d
T kernel(ref const(T)[9] neighbourhood)
```

Compare:

1. current public M2.3 path;
2. validated check-free Canonical candidate using the same callback;
3. positive versus negative Canonical source rows;
4. later, the preserved out-of-line row boundary for LDC negative Canonical.

The first benchmark is intentionally not a hard-coded box-sum-only API probe.
A representative arithmetic callback may be used, but it must pass through the
same template callback shape as Production.

## Promotion threshold

A candidate may be recommended for Production only if:

- exact output equality is preserved;
- all M2.3 semantic checks remain before the first write;
- the gain is material and reproducible on the stable local reference machine;
- the gain survives representative region sizes;
- DMD/LDC effects are documented separately;
- any compiler/version/layout selection is centralized;
- no public pointer/ISA/execution-layout API is introduced.

## KEEP

- validated semantic boundary -> narrow check-free internal hot path;
- signed Canonical semantic support;
- current public M2.3 callable and error contract;
- generic fallback for layouts without a qualified fast path;
- caller-owned parallelism;
- benchmark/codegen evidence before compiler specialization.

## REJECT

- handwritten SIMD as the first M3 action;
- replacing the public operation with raw pointers;
- weakening negative-stride support;
- hidden threads or worker pools;
- treating GitHub-hosted absolute time as a stable baseline;
- re-promoting the already-adopted safe-slice ubyte->float conversion change.

## DEFER

- fill specialization;
- production-shaped point-transform specialization;
- strict-reduction optimization;
- AArch64-specific selection;
- multithreaded execution;
- GPU work.

## Production-shaped benchmark evidence

### Harness correction

The first release-build harness revision invoked the benchmark and timed
operations through `assert(...)`.

That shape is invalid for release benchmarking because assertions may be
removed with their argument evaluation.

The harness was corrected so that:

- `main()` returns `runBenchmarkMatrix()` directly;
- every timed operation is executed explicitly;
- operation success is accumulated separately from timing;
- correctness fingerprints are verified after timing;
- no benchmark result from the assertion-wrapped revisions is retained.

This repeats an important R0.5 lesson: correctness guards must not accidentally
own the expression whose performance is being measured in release builds.

### Hosted-runner diagnostic matrix

Qualified head:

```text
0feee8fcd6def46a8b589da5df8e33ae756b0f1c
workflow run 36761357770 / #7
```

Both DMD and LDC jobs completed successfully.

The hosted environment is not an absolute baseline. It is retained only as
same-run relative diagnostic evidence.

The current LDC package identifies itself as:

```text
LDC 1.41.0
DMD frontend 2.111.0
LLVM 20.1.5
x86-64
```

This differs from the older R0.5 LDC 1.41 evidence that was recorded with LLVM
19.1.7. Compiler name/version alone is therefore not sufficient to infer one
optimizer generation.

Representative 2048 x 512, pitch 2304 medians:

| Compiler | Rows | Public M2.3 | Canonical integrated | Candidate / public | no-inline | no-inline / integrated |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| DMD 2.111 | positive | 53.379 ms | 17.349 ms | 0.325 | 17.318 ms | 0.998 |
| DMD 2.111 | negative | 53.789 ms | 17.493 ms | 0.325 | 19.719 ms | 1.127 |
| LDC 1.41 / LLVM 20.1.5 | positive | 17.847 ms | 9.393 ms | 0.526 | 9.272 ms | 0.987 |
| LDC 1.41 / LLVM 20.1.5 | negative | 17.909 ms | 10.471 ms | 0.585 | 9.341 ms | 0.892 |

The width matrix around 127/128/129, 511/512/513 and 2047/2048/2049 preserves
the same broad result:

- the validated Canonical execution path materially outperforms the current
  public sample-by-sample path on both compilers;
- DMD generally benefits by roughly a factor of two or more and by roughly
  threefold in the largest cases;
- LDC also benefits materially, though the public baseline is already much
  faster than DMD;
- ordinary integrated Canonical execution supports both row signs;
- the out-of-line row boundary is not a general optimization;
- on DMD it is neutral or materially worse for the important large negative
  case;
- on current LDC positive rows it is effectively neutral;
- on current LDC negative rows it reproducibly improves the integrated
  Canonical candidate by about 9--11 percent for the large cases.

The old R0.5 causal observation therefore still exists on the current hosted
LDC optimizer generation, but in a reduced form. Any Production selector must
remain compiler-generation/layout specific rather than selecting no-inline for
all compilers.

### Generic fallback

The research branch also contains a Universal/sample-strided source probe with
a negative-row destination.

The intended dispatch rule is:

```text
Canonical-compatible source/destination
        -> qualified check-free fast path

other validated affine layouts
        -> existing public semantic path
```

The Canonical candidate must decline the Universal/sample-strided fixture while
the public operation remains exact.

### Current interpretation

The magnitude of the same-process relative gain is large enough to continue
M3.1. It is not by itself sufficient for Production promotion because hosted
absolute timing is non-gating.

The likely smallest Production slice is now:

```text
keep the complete public M2.3 validation/error contract
        ->
classify Canonical-compatible execution
        ->
run narrow check-free Canonical kernel
        ->
otherwise retain existing generic path
```

A further LDC-negative no-inline selection may be layered internally only if
stable-reference-machine measurement and final production-shaped code
generation justify it.

## Next evidence

Before Production promotion:

1. run the current benchmark on the stable local reference machine with both
   baseline compilers;
2. inspect final production-shaped LDC code generation for positive/negative
   Canonical and the no-inline candidate;
3. record the Universal fallback probe result on both compilers;
4. decide whether M3.1 promotes only the ordinary Canonical fast path or also a
   narrow LDC-negative specialization.

Final Production promotion still requires stable local reference-machine
measurement and final code-generation inspection.
