# R0.7 — pragmatic RasterLease/RasterView contract audit

Date: 2026-10-10  
Status: source-backed audit, **not** a new production contract or completed compiler proof.  
Scope: read-only inspection of `alex-1974/raster-d` `develop`,
especially `source/raster/backing.d`, `source/raster/view.d`,
`source/raster/resource.d` and `README.md`. Read-only comparison with
`containers-d` `develop` ownership contracts.

## Engineering decision: explicit limits

R0.7 aims for defensible user-facing guarantees, not a complete language-level
borrow checker. Do not implement a bespoke lifetime runtime, mandatory per-pixel
refcounting, universal container policy layer, or automatic adaptation to every
compiler mode. Use D's existing `scope`/`return` annotations, the existing
owner/view split and narrowly bounded `@trusted` boundaries, then test the
actual supported compiler configurations. Do not equate rejected compilation
with proven escape prevention until the diagnostic reason is verified.

The ordinary-mode acceptance of several unsafe escapes in the prior toy
matrix is a genuine **proof boundary**, not by itself evidence of a production
UAF. No exploit of current `RasterLease.view` is claimed here.

## Actual raster-d ownership graph

```
RasterLease!T (copyable retained capability)
  -> RasterBackingOwner (private, non-atomic reference count)
     -> RasterBackingControl
        -> RasterBacking (one resource table; one stable descriptor table)
           -> ResourceEntry[] (releaseFn/context obligations)
           -> PlaneDescriptor[] (read-only borrowed by RasterView)
RasterView!T: const(PlaneDescriptor)[] + Region2D; non-owning
WritableRasterView!T: lease-bound writable capability, not unique/noalias
```

Confirmed directly in `source/raster/backing.d`:
- `RasterBacking` disables copy and releases resources/metadata at final
  destruction; `RasterBackingOwner` increments on postblit and decrements on
  destruction. `opAssign` uses a retained-by-value RHS and swap.
- `RasterLease.view()` has `return @trusted` and returns the inert empty
  view for an uninitialized lease. A returned view borrows storage and must
  not outlive an owning lease.
- `tryWritableView()` requires a mutable lease, reuses writable
  certification and **does not** promise uniqueness, noalias, non-overlap
  or thread exclusion.
- `RasterView.tryRoi` reuses the descriptor block without allocation;
  `trySample` is a `@trusted` checked value read, while internal pointer
  formation assumes validated region/strides/reachability.
- `ResourceEntry.releaseContext` is *not* independently retained.
  Adapter-supplied callback state must itself live until final release.
- The owner implementation is intentionally independent of Phobos
  `SafeRefCounted` to avoid prior DIP1000-dependent, cross-module layout/
  codegen behavior.

## Practical boundaries (what we will and will not guarantee)

| Subject | Existing/appropriate guarantee | Explicit non-goal |
| --- | --- | --- |
| Lease ownership | Backing persists while one valid retained lease owns it; last release disposes registered resources | All independent `@system` pointer aliases automatically kept alive |
| Borrowed view | Valid while its descriptor and pixel backing stay retained; zero-copy ROI | Self-owning views or runtime refcount on sample access |
| Compile-time escape | Use current `return`/`scope` and test under supported compilers | Claiming full Rust-style lifetime checking in D ordinary mode |
| Writable borrow | Mutable lease + certified writable resources | Implicit exclusive/noalias/thread-safe writes |
| Resource callbacks | One final callback per registered resource | Automatic management of arbitrary opaque user callback contexts |
| Multithreading | No undocumented concurrent retain/mutation guarantee: private count is non-atomic | Retrofitting atomic shared ownership absent explicit consumer need |
| Raw storage | Validate layout, reachability and signed-stride arithmetic at construction boundary | Repeat full pointer proof on each pixel |
| Generic sample types | Existing restricted POD/non-indirection sample contract | Support all nested/context-bearing element types by raw relocation |

## Comparison to containers-d: transfer principles, not implementations

`containers-d` `RingBuffer!T` makes owner move, final destruction and
borrow invalidation explicit, but its owner is **unique**, not shared-retained.
`ScratchBuffer.reset()` intentionally ends element lifetimes while
reusing backing storage. That invalidation model is useful vocabulary, not
a drop-in replacement for raster-d retained backing.

`containers-d` M8 excludes `__traits(isNested,T)` raw-storage elements due
to hidden lexical context requirements; raster-d's sample type restriction
already excludes many unsuitable payload types. Do not transplant
`isNested` exclusions without demonstrating an actually reachable sample
type and a failing constructor/relocation path.

`containers-d` warns `@safe` cannot enforce its work-stealing deque's
one-owner thread protocol. Similarly `@safe` alone must not be presented
as proof that consumers cannot violate borrowed-resource lifetime.

## Ranked, minimal follow-ups

1. **P0 contract matrix**: inspect production *public* `RasterLease.view`,
   `tryWritableView`, `tryRoi`, copying and moving a lease; distinguish
   validated behavior from caller obligations.
2. **P0 focused consumer compile probes**: realistic `@safe` owner/view
   return/global/closure escapes under DMD 2.111 and LDC 1.41, ordinary
   and DIP1000, including a correctly typed callback negative. Record
   compiler diagnostics. Do not assert failures that were not measured.
3. **P1 final-release probes**: exercise copy/assign/move and observable
   disposal exactly once using *real* production `RasterLease`; include a
   lease copy that outlives another lease, plus inert `.init`.
4. **P1 explicitly characterize threading**: confirm private non-atomic
   retained count means shared concurrent owner manipulation is not a
   supported promise. Document only if an existing public claim is ambiguous.
5. **Stop condition**: if no reproducible contract violation and no
   meaningful consumer demand, close R0.7 with a precise documented
   limitation rather than creating new owner/callback/container APIs.

**No production changes authorized by this audit.** Keep release/API-freeze
branches untouched, preserve original research and perform selective promotion
only on demonstrated defects. No `containers-d` repository writes.


## Executable real-consumer tranche

`production_contract/run.sh` checks out the exact integrated production
merge `694c539fc54efe14fa9b8a015bcc52728bfa42b6` in a disposable
directory, compiles external source importing the actual public raster API
under ordinary and DIP1000 modes, and runs the unmodified production
`dub test` suite. The dedicated research workflow
`.github/workflows/r07-production-lifetime-contract.yml` covers
DMD 2.111.0 and LDC 1.41.0.

Cases:
- `positive.d`: borrowed read-only view, ROI, value read, copied retained
  lease with a second borrow. **Must compile**.
- `escape_return.d`: attempts to return a view borrowed from a parameter.
- `escape_global.d`: attempts to assign a borrowed view to a module-global.
- `escape_closure.d`: attempts to store an escaping capturing delegate.

The latter three are **observational** until both expected outcomes and
specific failure reasons are verified from this production-consumer run.
Do not mark acceptance as safe; do not misclassify unrelated errors as lifetime
enforcement. This is intentionally a small matrix instead of a new generic
borrow-checker framework.

The production `dub test` invocation reuses existing lifecycle and resource
release tests rather than introducing another owner implementation. After CI
results are recorded, add *only* missing real-owner edge tests if concrete
gaps remain; do not duplicate the already qualified toy retained-owner
life-cycle model.

This stage does **not** change the public lease/view ABI, do not alter
`containers-d` ownership rules, and do not imply that non-atomic retained
handles are cross-thread safe. CI qualification is pending as of this edit.
