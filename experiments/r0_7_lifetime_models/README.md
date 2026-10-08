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
