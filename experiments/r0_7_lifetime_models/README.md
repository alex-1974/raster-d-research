# R0.7 — Borrowed vs retained vs lexical raster access

Status: **research only / not promoted**. Source baseline: raster-d release/0.2,
PR #208 observations on DMD 2.111.0 and LDC 1.41.0 (2026-10-08).

## Question

Can raster-d provide a safe, no-silent-DIP1000-dependency lifetime story without
abandoning its current low-overhead hot-path views? Which alternative also
generalizes to imagery-d, geo-d and containers-d?

## Three models — different contracts

| Model | Holder | Escape policy | Main cost / concern |
| --- | --- | --- | --- |
| A: borrowed view | non-owning pointer+metadata | must stay inside owner lifetime | static rejection currently needs explicit DIP1000 for some patterns |
| B: retained ownership | view owns shared lifetime capability | may escape while storage is retained | refcount/copy/move cost; non-atomic owner is not thread-safe |
| C: lexical callback | temporary view only inside visitor | intended no escape | callback itself cannot prove non-escape without compiler enforcement; inlining/closure cost |

**Critical distinction**: the attached compiler harness uses *toy D models*.
Its B model uses a GC-owned class as an **analogy** for self-contained lifetime,
**not** a production prototype for raster-d's malloc-backed RasterLease.
GC reachability is not proof of correct custom-resource release. C is likewise
not safe merely because an API accepts a callback.

## First malloc-backed ownership model (added)

`probes/retained_malloc.d` now models a separately allocated control block
and a separately allocated payload with explicit reference counting. Returning
`RetainedView` transfers a retained owner rather than borrowing a local
owner, and a smoke unittest exercises creation, escape, read, and copy.

This is deliberately `@system`. It is **not yet** qualified for concurrent
sharing, callbacks, out-of-memory disposition, copy/assignment interactions,
exception handling, `@nogc`, or raster-d's actual descriptor metadata.
It demonstrates only the *shape* of a retained-resource approach. The
compile matrix runs a separate executable unittest so the research
does not silently accept compile-only evidence as a runtime qualification.

At this point there is **no A/B/C performance measurement** and no
validated safety proof for the ownership model. Those are promotion gates,
not optional polish.

## R0.7 retained-owner qualification extension (2026-10-08)

The malloc-backed prototype now has extra runtime assertions for:

- copy of an escaping owning view (shared control lifetime);
- assignment between two independently owned resources, with a prior alias
  verifying the old resource remains live until its last reference exits;
- `move` of an owner following assignment;
- **one final free per physical resource** using a test-only global counter;
- early cleanup of the control block when payload malloc fails.

These are narrow smoke tests, **not** a complete allocation-failure suite:
control-block OOM, zero-length semantics, release callbacks, concurrency,
cross-thread visibility, and ownership held by real raster descriptors remain
unqualified. The prototype is still deliberately `@system`; no
`@safe`, `@nogc`, or `nothrow` production contract is claimed.

`benchmark.d` adds an initial CPU read-only measurement with identical
bytes and iteration counts for a borrowed buffer and a retained owner.
A third plain-loop control is *not* a callback performance test. This
preliminary measurement is particularly sensitive to bounds checks,
compiler inlining, GC initialization, and dead-code optimization. It
is not a raster hot-path benchmark and cannot alone justify an API
decision. The checksum is validated and retained in a global sink.

The research CI compiles the benchmark optimized and executes it on the
baseline DMD/LDC jobs. No measured timing result is recorded until those
runs have completed and the numerical outputs have been inspected.

## DMD read-path gap — follow-up instrumentation

The first GitHub-hosted run (#37844586245) reported borrowed/retained
single-trial read costs of **0.349/1.916 ns per sample on DMD 2.111.0**
and **0.163/0.156 ns on LDC 1.41.0**. Those figures are single
measurements on runners and are *not* an established performance ratio.

The latest benchmark now records seven independently timed trials per
compiler, rotating the case order for each trial, and preserves identical
checksums. A separate CI step emits compiler-produced object symbols
and an initial disassembly excerpt. This is **instrumentation**: no root
cause is confirmed until those CI artifacts are examined.

The retained sample access has also been annotated `@system nothrow
@nogc` as a compiler acceptance probe. `@safe` is intentionally
*not* claimed for the raw-pointer implementation. Production-safe
construction, ownership failure paths and true scoped execution must
still be audited separately.

Important limitations:
- CI-hosted timings remain noisy. Median, spread and raw runs should be
  recorded before interpreting any DMD/LDC performance difference.
- Current read model includes accessor checks; the borrow model does not
  have identical bounds-check placement. Future measurements must
  distinguish **checked read**, **validated hot-path read**, and
  **ownership copy/retain** separately.
- The third `loop_control` case is not a callback implementation.
- The included disassembly excerpt may omit inlined loop bodies; a
  conclusive codegen explanation requires checking the complete emitted
  object and compiler optimization settings.

## Linked-codegen experiment: DMD `-inline`

The preceding CI disassembly was taken from a *relocatable object*; it
showed per-sample calls into `RetainedStorage.read` in both compilers'
`retainedSum` bodies. That observation by itself does **not** establish
the behavior of the final linked benchmark, nor does it demonstrate
the reason for the DMD/LDC performance difference.

The current CI now builds and executes the **fully linked** baseline
on both compilers, plus an additional DMD `-O -release -inline`
variant. It records retained-related call sites from `objdump` and
seven trial timings for each build. This is a test of whether DMD's
explicit inlining flag changes the generated hot path. It is not a
general endorsement of global inlining for production. Compare
the results and codegen before choosing a permanent optimization.

No observed outcome is claimed for the newly added variant until CI
has completed. The frozen `raster-d` public API is unchanged.

## Controlled follow-up: LDC pipeline and DMD read overhead

The compiler-version line in `compile-matrix.sh` now writes a complete
version report to a temporary file before printing the first three lines.
This avoids LDC's broken-pipe failure with Bash `pipefail`.

The repeated benchmark now includes `retained_unchecked` (control-block
indirection without per-element assertions) and `retained_cached` (one
control-block lookup before looping over a borrowed raw data pointer),
in addition to checked `retained`, `borrowed`, and `loop_control`.
Both extra accessors are **research-only @system** facilities, not
candidate public API additions. All five cases verify the same checksum
and their order rotates across seven trials.

This separates the cost of repeated checked access from repeated control
lookup and the cost of a once-per-operation validated access path.
No correctness/safety contract is inferred for unchecked reads: the
benchmark has validated its indices and retains the owner throughout.
Interpret timings only after examining the latest compiler matrix and
linked codegen.

## Strided descriptor and ROI microbenchmark (new)

`descriptor_benchmark.d` introduces a **research surrogate** of a
row-strided raster descriptor (256×128, row stride 320), plus an owning
descriptor retaining the malloc-backed reference-counted storage.
It exercises borrowed/retained descriptor copying, 32×24 ROI creation,
and row-strided ROI sample aggregation with seven rotating trials under
DMD and LDC (DMD with `-inline`). All sums are computed from the
same initialized bytes, and matching ROI sums are asserted.

**Important limitation:** These are not yet the production
`raster-d` `RasterView` / `RasterLease` types or validated APIs.
No cross-repository dependency or change to the frozen API was made.
The first CI runs demonstrate that the surrogate compiles and executes,
but they also expose a benchmark pitfall: constant-time copy/ROI cases
can be folded, hoisted or eliminated by an optimizing compiler, yielding
near-zero reported nanoseconds on LDC. Those timings **must not** be
interpreted as genuine retained-reference-copy costs. Future
qualification must make input choices runtime-variable, establish
observable ownership transitions, and isolate ROI construction from
sample traversal.

The remaining production-near qualification requires testing the
actual raster-d descriptors (including region layouts, storage
callbacks, cache/tile policies, and thread model), recording CPU/compiler
metadata and machine-readable repeated-run evidence before deciding
whether to promote a model.

## Real raster-d API consumer — pinned release reference

`real_consumer/` is an isolated DUB executable using the actual
`raster-d` public `tryAdoptMallocResource`, `tryImportOwnedRaster`,
`RasterLease!ubyte.view`, `RasterView!ubyte.tryRoi`, and
`RasterView!ubyte.trySample` APIs. GitHub Actions clones the
`release/0.2` source and checks out the fixed source commit
`cca63a9b2821cd26a98792d322207c8f07bd734f`, then registers that
checkout as a local DUB package. It does not alter `raster-d`.

The workload uses a 256×128 resident single-plane byte raster
with 320-byte row stride and 32×24 ROIs. Each trial rotates three
cases: one sampled ROI after borrowing; a full ROI sum after copying
the retained lease; and a full ROI sum without copying the lease.
ROI x coordinates vary by operation. Side-effecting API calls are
outside `assert` so `-release` cannot eliminate them.

**Comparison constraints:** Single sample versus full ROI sum have
different units of useful work and must not be ranked against each
other as a pure ownership penalty. Compare `retained_copy_roi_sum`
only to `borrow_roi_sum`; the borrow-only sampled-ROI case
separately examines view/ROI setup. Even the pair is an end-to-end
consumer measurement, not a precise standalone refcount cost.
The public `trySample` method is a checked/control-plane accessor,
not the package-internal optimized execution adapter.

The CI output for this new consumer is pending. The consumer may
reveal public integration/compiler issues; no green result or numerical
measurement is claimed until the new job logs have been checked.

## Actual API: ownership setup versus production reduction

The pinned external DUB consumer now contrasts a copied
`RasterLease!ubyte` plus `view()` against directly borrowing
`view()` without an extra owner copy. Both cases consume runtime-varying
ROI offsets but use a small control-plane observation, so the numbers
remain sensitive to compiler optimization and are not standalone
reference-count latency proofs.

A separate `production_sum_roi` case uses the public
`sum!ulong(roi, 0)` API after a real `tryRoi`, rather than the
control-plane `trySample` loop. Compare it only against matching
full-ROI work and verify sums/checksums. All cases use the immutable
release/0.2 source commit and do not cross package-private boundaries.

## Dependency provenance correction

The initial real-consumer workflow used `dub add-local` alongside a
`version="*"` dependency. CI logs displayed `Fetching raster-d 0.1.0`,
so they did **not** prove that the exact checked-out release/0.2 source
was linked, despite printing the desired Git commit. These earlier
consumer results must not be attributed to `cca63a9`.

The dependency is now an explicit local path:
`dependency "raster-d" path="raster-d-local"`.
The CI step symlinks `raster-d-local` to the checkout at the exact
commit. Future compiler and performance claims must be based on a green
run with this path dependency, not on previous registry-resolved runs.

## R0.7 qualified interim evidence — pinned source (2026-10-09)

Source: GitHub Actions [run 37901584402](https://github.com/alex-1974/raster-d-research/actions/runs/37901584402),
DMD 2.111.0 and LDC 1.41.0, each completed successfully. Consumer path dependency
resolved to the checked-out `raster-d` source commit
`cca63a9b2821cd26a98792d322207c8f07bd734f`; DUB built
`raster-d ~master` from that local path. Values below are seven-trial
**medians in nanoseconds per operation**, measured on GitHub-hosted VMs:

| Workload | DMD | LDC | Scope |
| --- | ---: | ---: | --- |
| borrow_roi_sample | 75.85 | 16.275 | one sample + ROI/view setup |
| retained_copy_roi_sum | 4362.50 | 645.85 | 768 checked samples + lease copy |
| borrow_roi_sum | 4359.12 | 642.15 | 768 checked samples |
| retained_copy_view | 36.55 | 7.40 | lease copy + view/control observation |
| borrow_view | 33.925 | 5.25 | borrowed view/control observation |
| production_sum_roi | 2421.20 | 622.675 | 768 samples via actual `sum!ulong` |

The two complete checked ROI traversals have identical checksums
(`391680000`) and comparable work. The `production_sum_roi`
checksum matches too. The per-operation median differences are
3.38 ns (DMD) and 3.70 ns (LDC) for checked ROI sums with versus without
the lease copy, but **this does not isolate refcount cost**. End-to-end
operations, measurement variation and optimizer treatment confound that
inference. `retained_copy_view` versus `borrow_view` differs by
2.625 ns (DMD) and 2.15 ns (LDC) in these trials, again not an
ownership microbenchmark proof.

The public production sum engine is ~1.80× faster than checked
`trySample` traversal on DMD, ~1.03× on LDC for this ROI shape;
not a general speed claim. This is **not** an XPS or C++ parity result.
`RasterLease` copying remains non-atomic and has no implicit
cross-thread ownership contract.

The earlier `dub add-local`/registry-based consumer numbers were
incorrectly attributed to the pinned release source. They remain
historical exploratory observations only.

## Initial C++ performance reference (new, not yet qualified)

`roi_sum_cpp.cpp` executes seven repeated strided ROI sums over the
same initialized 256×128 byte pattern (320-byte row stride; 32×24 ROI;
x-origin `1 + operation % 13`; 4000 operations per trial). CI builds
with `c++ -std=c++20 -O3 -DNDEBUG`, records the C++ compiler version,
and prints the checksum with the duration. The real raster-d external
consumer now includes `raw_d_roi_sum`, which performs equivalent raw
D slice-indexed work under its normal DUB release build.

These are **initial algorithm-matching baselines**, not controlled
cross-language performance evidence yet: compiler flags, code generation,
GC-owned D slice vs C++ vector, optimizer elimination risks, ABI and
runtime timing are not normalized. Compare checksums first. Same runner
does not imply equivalent system load; report per-compiler medians and
variability, and remeasure on the target XPS before any C++ parity claim.

The consumer now also includes two alternating-owner cases: it chooses
between two live leases at runtime, either copying the chosen lease for
one checked sample (`retained_switch_sample`) or borrowing directly
(`borrow_switch_sample`). This makes ownership transitions observable
through a live view/sample, but it **still does not isolate reference-count
latency** from conditional selection, checking, and loop overhead. Tiny
view-construction differences from run 37901584402 likewise cannot be
interpreted as exact reference-count latency. An ownership-instrumented
callback/release-count probe remains a separate qualification gate.

## Strict-sum source audit and comparable C++ arithmetic (2026-10-09)

Inspection of the exact pinned `raster-d` source at
`cca63a9b2821cd26a98792d322207c8f07bd734f` identifies an
important mismatch in the original baseline: `sum!ulong` dispatches
to `raster.internal.strict_sum.executeStrictSum`. In its inner
loop the implementation checks *each* unsigned addition using
`tryAddChecked`, returns `accumulatorOverflow` upon failure, and
preserves row/sample strides and the strict accumulation order.
The previous `raw_d_roi_sum` and `cpp_roi_sum` loops **do not**
perform equivalent overflow checks. Consequently the large measured
gap between production sum and raw sums cannot be attributed solely
to descriptor, dispatch, or borrow abstraction overhead.

`roi_sum_checked_cpp.cpp` now adds a C++20 unsigned 64-bit
per-sample checked accumulation using an overflow predicate before
each addition. Its image values and ROI coordinates match the other
baselines; this is a **closer numerical-contract reference**, not an
exact clone of raster-d's public invalid-plane/stride handling.
CI compiles it using `-std=c++20 -O3 -DNDEBUG` and prints checksum
and overflow status. C++ compilation and performance numbers for
this case are **unqualified until the new CI run completes**.

Follow-up codegen qualification should inspect optimized linked
disassembly of `sum!ulong`, including whether runtime overflow checks
remain after optimization. The external consumer now adds `checked_d_roi_sum`, with a `ulong`
accumulator reset for each ROI and a per-sample overflow predicate
before addition. Its checksum must match the production and C++
checked sums. It is still not a substitute for full raster layout
validation or the production overflow result object.

Equivalent compiler optimization flags, stable trial isolation, and
XPS runs are required before claiming C++ parity or a safe
specialization for bounded `ubyte` samples. **Do not remove or
weaken the established checked-overflow contract based on these
microbenchmarks.**

## Experiment protocol

1. Run `bash experiments/r0_7_lifetime_models/compile-matrix.sh dmd`
   or pass `ldc2`. The script invokes both ordinary and DIP1000 compilation
   and prints per-model accept/reject observations. It does **not** promote
   compiler acceptance to proof of safety.
2. Collect compiler version strings, full per-case diagnostics, and run
   context. Compare identical source across compiler versions.
3. In the next phase, implement production-equivalent retained control-block
   and visitor variants based on raster-d's actual backing constraints;
   inspect `@safe`, `@nogc`, `nothrow`, copying, mutation, and aliasing.
4. Benchmark **the same operation** for A/B/C on DMD and LDC: direct sample
   reads, loop-carried access, ROI, view copies, and callback entry; record
   optimized assembly, ns/sample, allocations, p50/p95 and relevant layouts.
   No benchmark number is claimed until measured.
5. Add negative tests for global escape, returned ROI, mutable pointer escape,
   closure capture, owner destruction/move, and const write-capability.
   One positive/negative pair must be checked for each claimed contract.

## Decision gates

- No silent new dependency or shared common package; preserve workspace
  domain boundaries.
- No revision of frozen raster-d public declarations during this experiment.
- A borrowed-view path must remain allocation-free and preserve kernel
  codegen/performance unless measured evidence supports another choice.
- B must retain actual resources including external callback disposition
  without relying on GC as an accidental owner.
- C must demonstrate rejection of escape routes or be explicitly documented
  as a *discipline*, not a static safety guarantee.
- Compile with both baseline compiler families; do not assume one toolchain
  behaves like the other.
- The source/quality release gate remains open pending evidence and an explicit
  release-contract decision.

## Initial expected findings (hypotheses, not results)

- Pure value and owning types avoid *owner-destruction* dangling references
  when they **actually own/retain the underlying resource**.
- A small borrowed descriptor may be cheapest in a tight loop.
- A callback likely introduces no cost after successful inlining but must
  not be assumed equivalent for every compiler/configuration.
- Owning handles could be offered beside the frozen borrowed API later;
  forcing refcount operations inside per-pixel access would be a bad design.

## Relevant production evidence

- raster-d PR #208 (ordinary vs DIP1000 negative lifetime matrix)
- raster-d `source/raster/backing.d` retained owner implementation
- raster-d `source/raster/writable_view.d` certified borrowing boundary
- Workspace `DESIGN_PRINCIPLES.md`, `DLANG_PRACTICES.md`, `QUALITY_GATES.md`.
