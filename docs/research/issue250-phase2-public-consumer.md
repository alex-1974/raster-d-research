# Issue #250 — Phase 2: pinned external DUB and source-contract probes

**Date:** 2026-10-14  
**Status:** Research fixtures created; native DMD/LDC results not yet verified. No production change.

## Baseline
- Published `alex-1974/raster-d` v0.2.0 at `2f2415851e45001df92ce56dad409f680684ba8d`.
- Research branch: `raster-d-research/research/issue250-lease-observability`.
- Independent executable: `experiments/issue250_lease_consumer`, depends on exact `raster-d ==0.2.0`.
- Branch-only GitHub Actions workflow: `.github/workflows/issue250-lease-consumer.yml`.

## Covered operations

1. `RasterLease!ubyte.init.view()` returns an inert view.
2. Allocate an actual 2×2 buffer, adopt via public `tryAdoptMallocResource`, and import with `tryImportOwnedRaster`.
3. Confirm explicit transfer of the resource obligation and validate pixel values.
4. Retain through an independent subscriber copy, evict the cache owner and read the survivor.
5. Retain another copy, retire the original subscriber and read the final survivor.
6. Move the survivor, confirm moved-from inert state and last known handle cleanup.
7. Explicit limitation: the public consumer cannot prove physical final-release timing. Existing package-native raster-d v0.2.0 unittests separately verify that release callbacks run exactly once after the last owner.

Checks use explicit exceptions rather than relying on release-mode assertions. The main test makes no unsupported claim of last-release observability.

## Compile-only contract controls

A successful `positive_import.d` compilation is a prerequisite to interpreting each negative. All negatives are compiled with `-c`, DUB-resolved import directories and the *same* compiler; link failures are not accepted as contract evidence.

| Source | Expected |
|---|---|
| `positive_import.d` | compile |
| `negative_has_backing.d` | reject: package-only presence query |
| `negative_physical_bytes.d` | reject: package-only physical byte query |
| `negative_owner_count.d` | reject: private owner/control fields |
| `negative_callback.d` | reject: package-only raw resource entry |
| `negative_borrow_escape.d` | reject: returned local owner-borrow under explicit `-preview=dip1000` |

## Toolchain coverage

The workflow plans DMD 2.111.0, DMD 2.113.0, LDC 1.41.0 and LDC 1.43.0 on Ubuntu 24.04, both debug and release consumer builds, plus pinned release-native `dub test`. No workflow result should be marked PASS until its logs and exact commit have been independently inspected.

## Additional impossibility boundary for a strong observer

If an observer continues holding an ordinary `RasterLease` so it can safely query the count, **its own reference prevents the count from reaching zero**. It can observe `1` but not the final free. If it releases its owner, its ordinary public handle becomes inert, and it cannot safely inspect the former control block. Therefore a snapshot getter on an ordinary owner is not, by itself, a last-release detector even for an observer that polls. A non-owning observer of a freed control block would instead require a separate safe lifetime protocol (for example some form of weak state), which the published API does not have. This follows from the inspected ownership transitions; it is **reasoning**, not measured compiler behavior.

This distinction is independent of a cache trying to infer noalias from `count == 1`: unique retained-owner count is neither physical-memory uniqueness nor thread exclusivity.

## Next research questions

- If the lifetime negative behaves differently among compilers, isolate the language/toolchain boundary before drawing safety conclusions.
- Investigate a **package-internal** count snapshot only as a limited diagnostic; it cannot by itself refund arbitrary escaped owners' retained bytes.
- Compare imagery-controlled delivery handles with a genuine final-backing-release event; do not conflate a callback for each physical resource with one event per control block.
- Specify observer reentrancy, allocation, error handling, threading, identity and metadata/payload byte accounting before proposing any public event hook.
- Decide whether existing M2/M3 subscriber delivery actually requires freely copyable raw raster leases. This may allow a solution entirely in the imagery layer.

**No admission or API decision.** This file records probes and the remaining evidence gate, not validated native results.
