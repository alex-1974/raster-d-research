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
