# Cache Boundary and Bounded Residency Research

Status: active research. E7.1 complete.

Issue: raster-d-research #3

## 1. Purpose

This research determines the smallest generic cache and bounded-residency
contract that may later support raster-d M1 after the completed M1.3
synchronous caller-owned materialization slice.

The work must preserve the distinction:

```text
ProviderBlock != CacheBlock != Region != ProcessingTask
```

A cache is a storage/reuse mechanism. It is not source/provider geometry, not
logical dependency geometry, and not scheduler policy.

## 2. Established evidence

Existing raster-d and raster-d-research work already establishes:

- logical/global coordinates are distinct from resident descriptor coordinates;
- logical datasets may be substantially larger than RAM;
- streamed/decomposed processing can preserve whole-request semantics with
  bounded resident input;
- provider block geometry is not required by the generic materialization
  boundary;
- M1.3 can materialize an arbitrary logical valid-input region into
  caller-owned resident storage without cache or scheduler concepts;
- R0.4a through R0.4d establish execution semantics but explicitly do not
  promote a cache, scheduler or pipeline API;
- operational constraints require configurable memory budgets;
- mature reference systems demonstrate that explicit cache limits and
  reusable resident blocks are practical, but their concrete cache designs are
  not raster-d specifications.

## 3. Research rule

The first experiment is a semantic cache reference model.

It deliberately does not use retained raster storage yet.

This separation is intentional:

```text
E7.1 semantic cache identity/accounting
        |
        v
E7.2 retained raster ownership integration
        |
        v
E7.3 request/cache/source geometry interaction
        |
        v
promotion decision
```

If E7.1 cannot state coherent invariants without raster storage, adding
RasterLease ownership would only hide the ambiguity.

## 4. Candidate cache identity

The initial hypothesis is that cache identity requires a stable source domain
plus the logical raster region and enough schema identity to prevent
semantically incompatible reuse.

Initial research-local key:

```text
CacheKey
    sourceId
    logicalRegion
    schemaId
```

This is not a production API proposal.

Provider-native tile/block coordinates are deliberately absent.

Questions still open:

- whether source identity belongs in raster-d or in an adapter/consumer;
- what production form schema identity could take;
- whether layout belongs to identity or only to the retained resident value;
- how transformed/intermediate results would be distinguished.

## 5. Byte budget

E7.1 uses an explicit retained-cache byte budget:

```text
retainedCacheBytes <= cacheBudgetBytes
```

This is intentionally narrower than total engine memory.

It does not yet account for:

- active caller-owned destinations;
- temporary kernel workspace;
- source/decode staging;
- scheduler queues;
- GPU memory.

Those classes remain separate so the first cache contract does not falsely
claim to solve total engine memory accounting.

## 6. Pinning and eviction

A resident cache entry that is actively retained/borrowed must not be selected
for eviction.

E7.1 represents this with research-local pin counts.

Initial deterministic eviction oracle:

1. consider only unpinned entries;
2. choose the least recently used entry;
3. break ties by stable slot order.

LRU is an experiment policy, not a proposed permanent raster-d policy.

The semantic requirement under test is weaker:

> eviction policy must never invalidate an actively pinned resident value and
> must make budget accounting truthful.

## 7. Oversized entries

An entry whose own retained byte size exceeds the configured cache budget
cannot be admitted.

The first reference behaviour is explicit rejection rather than silently
exceeding the budget.

A later materialization/execution layer may choose to process an oversized
working set outside the cache if its own contract allows that. Cache admission
failure and request-execution impossibility are therefore not assumed to be
the same condition.

## 8. Experiments

### E7.1 — semantic cache accounting

Status: **PASS** on the workspace baseline compilers.

Verified against:

- raster-d-research branch head `5f2a4ab35d41b42a62fd13a1f5a1ebf0fc01ed4b`;
- raster-d `develop` head `2ea33562ca217ef9f552d0be397100326847c08d`;
- DMD 2.111.0 + DUB 1.40.0;
- LDC 1.41.0 + DUB 1.40.0.

GitHub Actions run: `36705940582`.

Both compiler jobs produced:

```text
E7.1 PASS: cache identity, byte budget, pinning and deterministic eviction
```

The preceding run `36705822444` failed before compilation because CI had
checked out raster-d inside the research repository while the experiment's
workspace-local path dependency expects raster-d as a sibling repository. The
CI harness was corrected to mirror the sibling workspace layout; the experiment
source itself was unchanged.

Questions:

- can cache identity remain independent of provider geometry?
- can strict retained-byte accounting be maintained?
- can deterministic eviction preserve pinned entries?
- can repeated lookup distinguish hits from materialization misses?
- can an oversized entry fail explicitly?
- can cache geometry remain different from request geometry?

No raster storage ownership is tested yet.

### E7.2 — retained raster integration

Planned only after E7.1 passes.

Use existing raster-d retained ownership and RasterLease semantics to test:

- cache owns/retains resident raster state;
- borrowers remain valid while pinned/retained;
- eviction releases cache ownership but does not invalidate independent retained
  ownership;
- multi-plane and padded/strided retained values;
- exact byte accounting for retained physical resources.

### E7.3 — geometry and reuse

Planned after E7.2.

Test:

- source/provider blocks misaligned with cache blocks;
- cache blocks misaligned with logical requests;
- one request assembled from multiple cache entries;
- overlapping halo/dependency requests reuse existing cached resident data;
- huge logical origins remain outside resident pointer geometry.

## 9. Promotion gate

No production cache API is justified merely by a passing E7.1.

Promotion requires evidence for:

- stable identity;
- ownership/lifetime;
- truthful byte accounting;
- pinned/borrowed eviction safety;
- source/cache/request geometry independence;
- explicit failure semantics;
- DMD/LDC verification;
- public-surface review.

Possible result states remain:

```text
KEEP
REJECT
DEFER
```

A production M1 follow-up is created only if the research supports a narrowly
scoped contract.
