# Issue #250 — Phase 2 native CI observations

**Date:** 2026-10-14  
**Evidence status:** **verified positive/negative compiler gates**, not a production API decision.  
**Run:** [38552366281](https://github.com/alex-1974/raster-d-research/actions/runs/38552366281)  
**Exact tested research HEAD:** `569ddf5abb0c4806a1ad471688dc9348db21c7fa`  
**Producer:** signed/annotated `raster-d v0.2.0`, tag peeled to `2f2415851e45001df92ce56dad409f680684ba8d`; CI compares checked-out HEAD against this full SHA.  
**External consumer:** DUB resolution required exactly `raster-d ==0.2.0` in `dub.selections.json`.

## Four independently inspected CI job logs

| Toolchain | Job ID | Released raster-d unittests | Consumer debug + release | Public compile-only + DIP1000 negatives |
|---|---:|---|---|---|
| DMD 2.111.0 / DUB 1.40.0 | 115813134542 | 57 modules PASS | PASS / PASS | PASS |
| DMD 2.113.0 / DUB 1.42.0 | 115813134624 | 57 modules PASS | PASS / PASS | PASS |
| LDC 1.41.0 (frontend 2.111, LLVM 20.1.5) / DUB 1.40.0 | 115813134749 | 57 modules PASS | PASS / PASS | PASS |
| LDC 1.43.0 (frontend 2.113, LLVM 22.1.8) / DUB 1.42.0 | 115813134070 | 57 modules PASS | PASS / PASS | PASS |

Observed literal gate output in **each** job:

```text
57 modules passed unittests
PASS: pinned raster-d ==0.2.0
PASS: public lease copy, move, borrow and eviction semantics
LIMITATION: no last-physical-release observation
PASS: public lease copy, move, borrow and eviction semantics
LIMITATION: no last-physical-release observation
PASS: negative_has_backing compile-negative
PASS: negative_physical_bytes compile-negative
PASS: negative_owner_count compile-negative
PASS: negative_callback compile-negative
PASS: negative_borrow_escape / DIP1000 compile-only
PASS: external public-contract gates on <compiler>
```

The job logs show successful source-mode positive import control before the negative probes. The negative fixtures were rejected during compilation (`-c`), not treated as linker failures. Explicit DIP1000 was confined to the borrow lifetime gates.

A Git message that the annotated `v0.2.0` tag object “is not a commit” occurs during shallow tag checkout; the workflow subsequently verifies the **peeled** checked-out HEAD against the exact release commit. It did not affect the success outcome.

## Supported conclusions

1. The existing release `RasterLease` copy/move/borrow lifecycle and retained original/surviving subscriber samples work under all four compilers in both build modes.
2. The release's existing internal counted backing-release tests run as part of all four full unittest suites.
3. The package visibility boundary is enforced for `hasBacking`, `tryPhysicalResourceBytes`, private owner fields and package-only resource metadata.
4. The explicitly scoped local-borrow-escape negative is rejected under DIP1000 in all four compiler versions.
5. External callers are **not** given a final-release event by any of these tests; no refcount getter or last-release callback was introduced. The inability of a snapshot to signal a later arbitrary last release remains a logical/semantic result, not a runtime performance finding.

## Not established

- Multi-threaded lifetime/observer correctness, read races, atomicity or a noalias/uniqueness contract.
- Exact whole-process or per-resource memory accounting via arbitrary externally copied raw leases.
- Safe ABI shape or benchmark cost of a proposed public count getter or callback.
- Whether M2/M3's required general subscriber model must expose raw owning `RasterLease` at all.
- Any acceptance into production; DMD/LDC pass is one necessary gate, not the architecture decision.

## Subsequent gate

Compare two candidate *consumer contracts*, not just two implementations:

(A) imagery owns all delivery handles and no raw RasterLease escapes; (B) arbitrary external RasterLease escape with exact last-release credit. Determine if (B) is actually a requirement before designing new raster ownership observability. If needed, prototype the smallest package-internal snapshot and final-release hook on an isolated checkout of the v0.2.0 source; never modify the published tag or adopt the prototype as public by default.
