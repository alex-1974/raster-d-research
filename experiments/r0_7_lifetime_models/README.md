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

## Linked codegen audit — production strict sum (2026-10-09)

A focused source audit of the pinned `raster-d` commit
`cca63a9b2821cd26a98792d322207c8f07bd734f` traces the public
`raster.reduction.sum!ulong` to
`raster.internal.strict_sum.executeStrictSum!(ubyte, ulong)`.
After validating the plane/strides and the empty-view case, it
walks rows and samples in encounter order, checks each accumulator
addition via `tryAddChecked`, and uses guarded pointer advances
(`if (x + 1 < source.width)` and `if (y + 1 < source.height)`).
Both the per-element overflow predicate and repeated last-element
branches are plausible codegen costs; **their machine-level
presence and relative cost are not yet demonstrated**. The kernel
must continue to preserve overflow-failure behavior, signed stride
correctness, empty-region handling and order of accumulation.

The research workflow now retains `nm -anC` symbols and complete
`objdump -drwC` output of the **linked external consumer binary**
for DMD 2.111.0 and LDC 1.41.0, with compiler-labelled 14-day
artifacts. The step records the binary SHA-256 and small relevant
symbol/reference excerpts in the job log. Inlining may eliminate
named symbols; lack of a symbol is **not proof** that an operation is
absent. Compare the actual hot loop, branch structure, and call sites,
not only an object-file listing.

**Experiment gate:** retrieve the artifacts from a successful run;
verify that the optimized loop is identifiable before attributing
timings to any particular instruction. Do not change the frozen
production implementation or weaken its overflow contract on the
basis of this source-level hypothesis.

## Strict-sum loop-shape controls (research-only)

`strict_sum_loop_shapes.d` adds isolated optimized loops for the
same fixed 32×24 signed-free positive-stride byte ROI workload:
an indexed checked loop (`indexed_checked`), a local-dimension
pointer version (`cached_dimensions`), a pointer-end-guard
version (`pointer_end_guard`), and an independently labelled direct
checked control (`direct_checked`). This is an *initial
instrumentation scaffold*, not yet a full one-factor-at-a-time
experiment: cached-dimension and pointer-end-guard versions currently
share much of their control flow, while indexed and direct-checked
share the same implementation. Equal timings are expected for some
pairs and must not be reported as independent evidence.

Before timing, the probe compares outcomes for every 32×24 ROI
origin within the 256×128 resident region and checks zero-width
semantics. It does **not** yet test unsigned overflow with a
sample type capable of producing it, negative strides, arbitrary
sample strides or malformed descriptors. Those are mandatory
qualifications before any production implementation experiment.

CI compiles optimized `-O -release` on both compilers, adding
`-inline` for DMD, and reports seven rotating timed trials.
The results are unqualified until the CI finishes. Never promote
one of these shapes on timing alone or change the v0.2 API.

## Linked codegen inspection — qualified DMD observation (2026-10-09)

Artifacts from successful workflow
[37916072037](https://github.com/alex-1974/raster-d-research/actions/runs/37916072037)
were retrieved and inspected. These archives contain the linked consumer
disassembly and symbol tables for DMD 2.111.0 and LDC 1.41.0.

**DMD:** The linked binary has a distinct
`executeStrictSum!(ubyte, ulong)` symbol starting at `0x6af90`.
Within its inner sample loop (`0x6b035` onward), address
`0x6b04e` contains a real `call` to
`tryAddChecked!ulong` (`0x6b0d0`), followed by a success
branch. The checked-add helper itself performs the unsigned
overflow predicate, writes the output result via a pointer and
returns success or failure. The inner loop also contains an
end-of-row pointer-advance condition around `0x6b069`–`0x6b078`.
Thus the existence of a **per-sample call and per-sample
pointer-advance branch** is directly established for this
DMD linked build; no cycle-level attribution is yet proven.

**LDC:** No separately named `executeStrictSum` or
`tryAddChecked` symbol is exposed in the corresponding
linked consumer symbol listing. This is consistent with
inlining/internalization, but is *not* by itself proof of
the exact LDC hot-loop instructions or absence of overflow
checks. Locate the inlined reduction inside `_Dmain` and
perform a scoped instruction/branch audit before making a
stronger codegen claim.

The newly replaced `strict_sum_loop_shapes.d` is now structured
to compare exactly one source-level dimension at a time:
cached descriptor fields, indexed versus pointer traversal,
and an algebraically equivalent unsigned overflow predicate.
These are **research-only** alternatives. They validate
every legal fixed-size ROI origin, non-unit sample stride,
negative row and sample strides, zero-sized shapes, genuine
ulong overflow and a no-overflow ulong control before timing.
They have **not yet passed compiler CI** at the current commit.
Do not compare the old loop-shape numbers to these changed
implementations as though they measured the same variants.

## Controlled follow-up: compile-time specialization (2026-10-09)

The initial successful [run 37935538619](https://github.com/alex-1974/raster-d-research/actions/runs/37935538619)
used a **runtime `Variant` switch** inside `strictSum`, so its
four medians also reflected runtime dispatch/code layout and must
not be treated as isolated effects of the source-level changes.
Archived disassembly symbols confirm that the old loop-shape
executable emitted a single `strictSum!ubyte` entry point on
each compiler (plus `strictSum!ulong` for overflow validation),
rather than four individually named specialized kernels.

The new kernel accepts `Variant` as a **compile-time template
parameter** and dispatches before entering it. Each variant is
compiled separately: baseline guarded pointer, cached descriptor
fields only, row-relative index instead of advancing sample pointer,
and alternative equivalent unsigned checked addition.
This removes the per-sample runtime variant check from the
`alternate_checked_add` case. Every variant is validated against
the baseline across ROI positions, positive/negative strides,
empty shapes, and real `ulong` overflow before timing.

Do **not** compare the new trial medians directly to the earlier
runtime-dispatched variant measurements or infer an isolated source
effect from the previous numbers. Inspect generated linked symbols
and assembly after the updated CI qualifies.

## Checked-add helper versus inline predicate (new)

The now independently compiled `checked_helper` case uses a separate
`@safe nothrow @nogc` checked-add function with an `out ulong`
result and the same pre-addition unsigned overflow predicate as the
`guarded_pointer` baseline. The descriptor traversal is otherwise
identical. All existing equivalence probes (including actual
`ulong.max + 1` overflow, negative signed strides and empty shapes)
also cover this case.

**Hypothesis:** DMD's production strict-sum slowdown may partly
reflect a surviving per-sample checked-add call/return and output
parameter. Whether this research helper is inlined depends on the
compiler and flags: a successful functional test alone does not
prove either result. Compare the linked disassembly symbols and
actual call sites before attributing a performance gap.

This experiment is intentionally not a production change. It does not
attempt to delete overflow checks, replace the public
`RasterSumResult` contract or specialize away failure states.

## Linked assembly evidence: checked-add A/B (2026-10-09)

Source: successful [GitHub Actions run 37938280137](https://github.com/alex-1974/raster-d-research/actions/runs/37938280137), artifact names
`r07-loop-shapes-codegen-dmd-2.111.0` and
`r07-loop-shapes-codegen-ldc-1.41.0`.
The archived symbol tables and linked disassembly were inspected directly.

DMD linked addresses (binary-relative; not stable API addresses):
- `addWithOutput`: `0x608bc`;
- specialized `strictSum!(Variant.guarded, ubyte)`: `0x61e54`;
- specialized `strictSum!(Variant.alternateAdd, ubyte)`: `0x62234`;
- specialized `strictSum!(Variant.checkedHelper, ubyte)`: `0x6232c`.

The DMD `checkedHelper` inner loop contains a concrete
`call 0x608bc` at `0x623d3` targeting `addWithOutput`;
the call site is on the loop path, which branches back at
`0x62426`. Neither the guarded direct-add kernel nor the
alternative-add kernel has a call instruction in its compiled
kernel body. The alternative checked-add path performs an
address/register `lea` and compares the wrapped result with
the previous accumulator (`0x6229d`–`0x622a4`); the
baseline uses the complementary pre-add overflow comparison
(`0x61ec4`–`0x61eca`). Both checked predicates remain present.

LDC's archived linked symbol table exposes none of these
individual `strictSum` specializations or `addWithOutput`
as externally named entries; this is consistent with
inlining/internalization. **It does not prove the absence of
individual overflow checks or completely explain LDC throughput.**
A follow-up should identify inlined callsites in `_Dmain`
via branch/dataflow inspection or compile with explicit
codegen instrumentation.

Measurement from the same run (median of seven trials, ns/ROI):
| Variant | DMD | LDC |
|---|---:|---:|
| guarded_pointer | 962.075 | 175.650 |
| alternate_checked_add | 575.375 | 171.325 |
| checked_helper | 1641.600 | 170.050 |

All cases returned the same checksum `391680000`. The
benchmark cases are *not* a matched production-raster API
comparison, and compiler and runner effects remain. **The
DMD helper call is proven; the exact fraction of runtime
attributable solely to the call is not.** No production
change or API modification is authorized by this evidence.

Proposed XPS qualification: keep the implementation in the
research repo; measure each variant through independent,
non-inlined public entrypoints with matched input descriptors,
seed, repetitions, optimization flags, and iteration order.
Include positive/negative row and sample strides, empty ROI,
and real ulong overflow in a correctness stage distinct from
timed runs. Record compiler version, target CPU and
optimization flags; retain median plus dispersion and linked
assembly. Benchmark the pinned `raster-d` v0.2 baseline in
the same session before considering any production adaptation.

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

## Linked checked-add codegen: observed evidence (2026-10-09)

Source: successful
[workflow 37938280137](https://github.com/alex-1974/raster-d-research/actions/runs/37938280137);
archived `r07-loop-shapes-codegen-dmd-2.111.0` and
`r07-loop-shapes-codegen-ldc-1.41.0`, each containing
`r07-codegen-loop-shapes.{txt,symbols}`.

### DMD 2.111.0

The linked symbol table contains **five distinct**
`strictSum!(Variant.*, ubyte)` instantiations; this confirms
compile-time specialization. Their start addresses are:
guarded `0x61e54`, cached `0x62040`, indexed `0x62140`,
alternate add `0x62234`, and helper `0x6232c`.
The linked `addWithOutput` function starts at `0x608bc`.

A scoped disassembly inspection of each `ubyte` function
found **zero `call` instructions** inside the four
direct-check loop kernels. The `checked_helper` function
contains exactly one direct call site at **`0x623d3`**:
`call 608bc <...addWithOutput...>`.
That site lies in the helper kernel's per-sample traversal.
These observations establish a surviving hot-path call in
the DMD helper variant for this linked binary, rather
than merely inferring it from timing.

The corresponding seven-trial medians (ns/ROI) were
guarded **962.075**, cached **666.600**, indexed **723.350**,
alternate checked add **575.375**, and checked helper
**1641.600**. These differences are **not** an isolated
estimate of call overhead: branches, register allocation,
different binary layout and uncontrolled CI runner variation
remain confounders. They justify a matched local A/B
experiment; they do not justify production adoption.

### LDC 1.41.0

The linked LDC binary does **not** expose separately named
`strictSum` or `addWithOutput` symbols, although
`validate` and `run` symbols exist. This indicates
significant specialization/inlining/internalization at
link time. Absence from a symbol table does not prove
that all overflow tests disappear; no such removal is
allowed. The five LDC medians were close:
guarded **175.650**, cached **170.925**, indexed **170.400**,
alternate **171.325**, helper **170.050** ns/ROI.

### Decision gate

**Qualified:** helper call-site presence under DMD, its
absence as a separately named symbol under LDC, and
functional equivalence on the tested input matrix.

**Not qualified:** numerical performance attribution to
the call alone, XPS hardware results, an exact instruction
count for LDC's inlined hot loop, and parity with the
production `executeStrictSum` semantics for arbitrary
descriptors. Continue within `raster-d-research`; preserve
the raster-d v0.2 API freeze.



## Reproducible XPS local follow-up (not yet measured)

From a clean `raster-d-research` worktree on the XPS, run:

```bash
bash experiments/r0_7_lifetime_models/run_xps_checked_add.sh \
  /tmp/r07-checked-add-xps
```

The script requires `dmd`, `ldc2`, `objdump`, `sha256sum` and
`python3`. It compiles the same research source with DMD
(`-O -release -inline`) and LDC (`-O3 -release`), saves both
linked disassemblies and binary hashes, executes nine outer runs per
compiler (seven internal trials per variant), checks consistent
checksums and expected sample counts, and writes `raw.csv`,
`summary.csv` and `metadata.txt`. Preserve the **entire output
directory** as raw evidence; do not cherry-pick only the best trials.

The harness measures the five research loop-shape variants, **not**
the pinned production `executeStrictSum` path. Therefore it can
support a same-machine *research-kernel* comparison and assess
run-to-run dispersion, but cannot by itself justify production
performance or attribute the entire helper delta to call overhead.
A production-versus-candidate A/B still requires equivalent public
validation, dimensions, stride semantics, optimizer flags and
a common hardware session. No XPS results are claimed here.


## Frozen production-source checked-add A/B (new; pending execution)

Run from a **clean** research worktree:

```bash
bash experiments/r0_7_lifetime_models/run_production_checked_add_ab.sh \
  /tmp/r07-production-checked-ab
```

This creates **two independent detached clones** at the identical pinned
`raster-d` SHA `cca63a9b2821cd26a98792d322207c8f07bd734f`.
The baseline is untouched. The candidate changes **one internal**
`executeStrictSum` call site, and only when
`Accumulator == ulong`: it substitutes the direct predicate
`value > ulong.max - total` and the subsequent `total += value`.
Every other accumulator, row traversal, view/plane validation,
signed stride operation, empty handling, output status and public
signature stays on the original code path. The patch script
checks the frozen source revision, a clean checkout, a unique
source anchor and a single diff hunk; the full candidate diff is retained.

The **same** existing real-consumer source is built through DUB
against each clone, using DMD and LDC independently. The existing
`production_sum_roi` public API operation (including lease/view,
ROI creation, validation and result check) is timed for seven pairs
of baseline/candidate runs per compiler, with seven internal trials.
Pairs alternate execution order to mitigate order bias. Each binary's
linked symbols, assembly, checksum and build provenance are saved.
The summary contains 49 measurements per compiler/arm and refuses
unequal checksums or missing trials.

**Limits:** only `ubyte -> ulong` ROI summation is timed; the
source candidate is designed to preserve other integer and floating
instantiations but this harness alone does not exhaustively validate
them. A successful build is not a completed public numeric-contract
matrix; retain existing frozen-source tests and extend candidate
signed/unsigned overflow cases before any promotion. No XPS A/B
numbers or production speedups are claimed before execution. This
is a research-only copy; the production repository is untouched.


## Compiler and architecture dispatch decision (2026-10-10)

The XPS paired *public production-path* A/B experiment reported
49 observations per compiler/arm. The local observed medians were:

| Compiler | Frozen helper baseline (ns/ROI) | Inline-`ulong` candidate (ns/ROI) |
| --- | ---: | ---: |
| DMD 2.111.0 | 2293.22 | 1103.70 |
| LDC 1.41.0 | 587.075 | 591.35 |

All four groups reported checksum `391680000`. These results
refer to **one XPS architecture, one integer operation and one
compiler configuration**. They cannot establish results on AArch64,
other x86 CPUs, other accumulator types or newer frontend versions.

D `version (...)` can select a compiler-specific implementation
(e.g. `version (LDC)` with an `else` for the default), and a
separate architecture condition (e.g. `version (X86_64)`).
These are **different dimensions**:
a compiler branch must not implicitly stand for an architecture,
and an architecture branch must not silently encode compiler
performance assumptions. Use a single compile-time dispatch
boundary within an internal kernel, **not scattered conditionals**
across the public API or numeric contract.

**Decision for now:** do not introduce version-specific production
paths. The inline `ulong` candidate might outperform the helper
for DMD without penalizing LDC, and a *single* source path should
be preferred if it qualifies across the supported compiler and
architecture matrix. If future compiler/CPU combinations require
different implementations, isolate each behind one internal
selection point, retain the same typed result/status and scalar
fallback, and test every selected and unselected path explicitly
before promotion. Neither CPU SIMD feature detection nor AArch64
performance has been evaluated by the existing XPS data.

CI now independently runs the frozen-source complete DUB unit
tests for baseline and the one-site `ulong` candidate using DMD
2.111.0 and LDC 1.41.0. This is a **new gate awaiting completion**,
not a claim that the additional tests have passed. A successful
job would still not substitute for a dedicated differential
numeric oracle across all supported sample/accumulator pairs and
stride/overflow boundaries. Retain the XPS `raw.csv`,
`metadata.txt` and disassembly alongside this record before
accepting performance evidence into production.


## Added disposable-clone boundary regression matrix (2026-10-10)

The previous full `dub test` CI run
[38035879584](https://github.com/alex-1974/raster-d-research/actions/runs/38035879584)
completed successfully with both DMD 2.111.0 and LDC 1.41.0
for the frozen baseline and single-site `ulong` candidate.

A new **research-only** fragment,
`strict_sum_ulong_regression.dfrag`, is appended verbatim to the
internal strict-sum module in **both disposable CI clones** before
their existing `dub test` invocations. It probes:
(1) actual overflow following a successful addition,
(2) exactly `ulong.max` accepted without overflow,
(3) simultaneously negative row and sample strides with expected
logical sum, and (4) empty input with a null pointer and extreme
strides. Production source remains untouched. The resulting new
CI run must pass before these added test cases are credited.

This is a deterministic expected-value matrix, **not yet** a
wide randomized differential oracle; future qualification should
cover validated public view construction, representative all-type
accumulator legality, invalid plane ordering and architecture
variation. The existing XPS performance evidence is x86-64-only;
a `version (LDC)` or `version (X86_64)` path remains a contingent
future engineering choice rather than an adopted implementation.


## Linked production A/B call-site audit (2026-10-10)

`audit_production_codegen.py` reads **linked** baseline/candidate
`nm -anC` and `objdump -drwC` artifacts, separately scopes named
`executeStrictSum` instantiations and lists calls into
`tryAddChecked`. It produces `production-codegen-audit.json`.

The XPS A/B runner now invokes this read-only audit after measurement.
The CI workflow also rebuilds the identical real-consumer source
against both frozen-source clones and retains per-compiler linked
codegen artifacts. CI's per-compiler audit runs via `--compiler dmd`
or `--compiler ldc2`.

**Evidence boundary:** a call counted within a named function is a
static call site, not a runtime call count; missing symbols may mean
inlining or internalization, *not* removal of overflow tests.
Compare matching `ubyte, ulong` instantiations only, and check the
machine instruction path, compiler flags, and public status before
promotion. The new CI codegen collection has not yet been qualified.
No change to the raster-d v0.2 public API or production source.


## Qualified production-source linked codegen (2026-10-10)

Successful workflow [38037058275](https://github.com/alex-1974/raster-d-research/actions/runs/38037058275)
on commit `0a60363` completed DMD 2.111.0 and LDC 1.41.0
baseline/candidate unit tests and the linked production A/B audit.
The workflow retained the full `r07-production-ab-codegen-*`
artifacts. This is **real external-consumer linked code**, not
the earlier surrogate loop-shape probe.

| Compiler/arm | Named `executeStrictSum!(ubyte, ulong)` | Calls in that function | Direct `tryAddChecked` call sites |
| --- | ---: | ---: | ---: |
| DMD baseline | 1 | 3 | **1** |
| DMD candidate | 1 | 2 | **0** |
| LDC baseline | 0 visible | not attributable | not attributable |
| LDC candidate | 0 visible | not attributable | not attributable |

This verifies that the candidate **eliminates the direct checked-add
helper call site from the DMD production kernel** while retaining the
overflow precondition in source. A static call site count does not
measure dynamic call frequency or explain the entire XPS delta.
Under LDC, lack of a separately named function is consistent with
inlining/internalization, not evidence that numerical checks are
removed.

The same previously recorded paired XPS results remain:
DMD baseline **2293.22** versus candidate **1103.70** ns/ROI;
LDC baseline **587.075** versus candidate **591.35** ns/ROI.
No new physical-machine measurement was taken by this CI audit.

**Recommendation for the future production development branch:**
a single internal checked-`ulong` source path, rather than a
compiler-specific `version (LDC)` branch, is the smallest qualified
change *for the tested matrix*. This is an engineering recommendation,
**not approval to change the frozen raster-d v0.2 release**.
Architecture-specific variants remain research candidates requiring
their own AArch64/x86-64 regression, codegen and performance evidence.
Retain the raw XPS measurements and linked CI artifacts as provenance.
