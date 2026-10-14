# Issue #250 — RasterLease retention observability (first-pass research)

**Date:** 2026-10-14  
**Status:** exploratory; source audit + abstract-model proof, **not** public API approval or compiler qualification.  
**Parent:** [raster-d #250](https://github.com/alex-1974/raster-d/issues/250)  
**Consumer:** [imagery-d M3 retention contract](https://github.com/alex-1974/imagery-d/blob/47add6dce02b04d2071e06e62c4955c78967dc8d/docs/research/m3-rgba-closed-lease-retention-contract.md)  
**Scope:** read-only inspection of raster-d released v0.2.0 and develop; no production or sibling-repository modifications.

## Questions to keep separate

1. Is an observer of the *existing* owner-reference count feasible without changing the ownership contract?
2. Would a snapshot permit **exact** retained physical-memory accounting after arbitrary public `RasterLease` copies escape?
3. If not, what alternative minimizes new public surface, complexity, cost and semantic risk?

A refcount getter must not be assumed to solve the second question.

## Source-backed findings

- [raster.backing, control block](https://github.com/alex-1974/raster-d/blob/v0.2.0/source/raster/backing.d#L175-L198): the private `RasterBackingControl` stores the backing and `size_t referenceCount`.
- [retain/release](https://github.com/alex-1974/raster-d/blob/v0.2.0/source/raster/backing.d#L214-L295): increments and decrements are non-atomic; on last release, `RasterBacking` is destroyed and the control block is freed.
- [postblit, destructor, assignment](https://github.com/alex-1974/raster-d/blob/v0.2.0/source/raster/backing.d#L297-L330) manage owner-copy transitions. Compiler and transient-copy effects must still be probed independently.
- [public lease contract](https://github.com/alex-1974/raster-d/blob/v0.2.0/source/raster/backing.d#L555-L565): `view()` borrows; writable access does not imply uniqueness, noalias or thread exclusivity.
- [package-only helpers](https://github.com/alex-1974/raster-d/blob/v0.2.0/source/raster/backing.d#L588-L645): `hasBacking` and `tryPhysicalResourceBytes` are `package(raster)`.
- [backing destructor](https://github.com/alex-1974/raster-d/blob/v0.2.0/source/raster/backing.d#L136-L169) invokes a release callback for each physical resource, prior to metadata deallocation. This is an **internal release transition**, not a consumer-observable last-lease hook.
- [resource.d](https://github.com/alex-1974/raster-d/blob/v0.2.0/source/raster/resource.d), [owned_resource.d](https://github.com/alex-1974/raster-d/blob/v0.2.0/source/raster/owned_resource.d), [public package exports](https://github.com/alex-1974/raster-d/blob/v0.2.0/source/raster/package.d): arbitrary callback/context adoption is package-internal. The public `tryAdoptMallocResource` does not expose a caller-defined release observer.
- v0.2.0 and current develop share these reviewed core sections; this is **not** a claim of full-file or full-repository identity.
- [D struct specification](https://dlang.org/spec/struct.html) describes postblit/copy, and its runtime/container caveat; [D type qualifiers](https://dlang.org/spec/const3.html) describes explicit shared/atomic synchronization. These references supplement, not replace, actual compiler-matrix tests.

The count represents owner handles **for one control block**, not physical resource count, bytes, views, cache entries, physical-resource uniqueness or writable noalias.

## Logical counterexample: count snapshot is insufficient by itself

For one payload B, 1,088 bytes:

| Event | Cache owner | Subscriber owner | Backing alive | Correct physical payload charge |
|---|---|---|---|---:|
| Create | yes | no | yes | 1088 |
| Subscriber retains a copy | yes | yes | yes | 1088 |
| Cache evicts its lease | no | yes | yes | 1088 |
| Subscriber eventually releases | no | no | no | 0 |

A cache observing only create → deliver → evict cannot distinguish (A) the subscriber remains alive from (B) the subscriber later releases. Both histories have the same cache-visible event sequence, but require different current physical charges. A readonly refcount *snapshot* does not deliver the missing release event.

The accompanying **abstract**, self-contained Python model checks 49 legal teardown orders for 0–3 subscribers and verifies this indistinguishability. It does **not** compile D or reproduce raster-d backend behavior, refcount-copy lowering, thread races or ABI.

## Candidate comparison — no promotion

| Candidate | New public raster API? | Arbitrary escaped raw leases accurately accounted? | Open issues |
|---|---|---|---|
| Readonly count snapshot | yes | **not by itself** | lifetime and synchronization, transient copies, misleading uniqueness interpretations, compiler ABI |
| Package-only diagnostic snapshot | no public API | no | diagnostic value vs maintenance cost |
| Imagery-controlled delivery handles, raw raster owner never exported | potentially no | only inside **closed** controlled delivery model | real multi-subscriber semantics, copy policy, error/reentrancy costs |
| Consumer-delivery budget charged until session end | no | conservative, not exact during overlap | memory admission/latency tradeoff |
| Final-release event for backing | yes | potentially, with defined accounting scope | callback timing, failure, reentrancy, threading, per-backing vs per-resource, overhead |
| Custom per-physical-resource release callback | currently unavailable publicly | maybe for narrowly instrumented resources, not yet proven generally | more ownership API; multiple resources; import pre/post commit |
| Weak reference to control block | yes/new state | not safely from released storage alone | UAF/ABA/control-block redesign |

The [imagery-d M3 closed-world experiment](https://github.com/alex-1974/imagery-d/blob/47add6dce02b04d2071e06e62c4955c78967dc8d/docs/research/m3-rgba-closed-lease-retention-contract.md) already demonstrates internally controlled cache/subscriber accounting. It does **not** prove correct accounting for freely copied/escaped raster leases.

## Next empirical gate (not run)

1. Independent external DUB consumer pinned to `raster-d ==0.2.0`; positive tests: `RasterLease.init`, one owner, owner copy, assignment/move, borrowed view, cache drop, survivor read.
2. Package-internal test fixture with a counted physical-release callback to confirm one last destruction over corresponding ownership traces.
3. Compile-only negative external consumer cases: `hasBacking`, `tryPhysicalResourceBytes`, and package-only callback access. Avoid false passes from missing imports or linker errors.
4. Only if a candidate observer is justified, prototype **outside production**, qualify `@safe`/DIP1000, DMD and LDC support, codegen and hot-path cost. Preserve v0.2.0 public ABI; do not insert a public getter in production as part of this research.
5. Investigate any final-release API only after specifying observable event, synchronization and allocation/accounting boundaries, especially when multiple physical resources belong to one backing.

**Environment limitation:** No DMD, LDC or DUB installed in the research author's execution environment. No D compiler matrix or native timing has been run for this pass.

**Current position (not a final decision):** Existing ownership machinery appears sufficient; adding a readonly snapshot might be technically possible but does not answer the requested last-release accounting question. Keep all candidates open until the consumer delivery contract and native probes are settled.
