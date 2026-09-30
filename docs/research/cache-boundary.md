# Cache Boundary and Bounded Residency Research

Status: complete. E7.1 through E7.4 passed on the workspace baseline compilers.

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

Status: **PASS** on DMD 2.111.0 and LDC 1.41.0.

Verified research head:

`0e126982f40d658decbd6708be64501f6efdb60a`

Verified raster-d develop:

`2ea33562ca217ef9f552d0be397100326847c08d`

GitHub Actions run:

`36706421827`

Both compiler jobs produced:

```text
E7.2 PASS: RasterLease retention, eviction survival and physical-byte accounting
```

Measured semantic results:

1. A cache entry may be evicted while an independently copied `RasterLease`
   continues to retain and read the same backing correctly.
2. Therefore:
   ```text
   cache-retained bytes != total process-resident raster bytes
   ```
   whenever lease copies escape the cache.
3. A strict cache byte budget remains truthful for cache ownership, but cannot by
   itself serve as the complete engine residency budget.
4. Multi-plane interleaved storage must be accounted by physical resource bytes,
   not by summing logical plane spans. The two-plane fixture occupied one 145-byte
   physical allocation and was counted once.
5. The current public `RasterLease` capability does not expose physical-resource
   byte cost. E7.2 therefore carries materializer-known byte cost beside the lease
   in research-local cache metadata.
6. `RasterLease` copying requires mutable access to the source lease because the
   retained-owner refcount changes. A `const RasterLease` is therefore not a
   copy source, which is consistent with its ownership semantics.

This narrows the next research question: cache retention and total residency
admission must be treated as distinct accounting layers rather than hidden
behind one counter.

### E7.3 — geometry and reuse

Status: **PASS** on DMD 2.111.0 and LDC 1.41.0.

Verified research head:

`d75798fcc2cf73de37f8522a6bbf31c64027b5aa`

Verified raster-d develop:

`2ea33562ca217ef9f552d0be397100326847c08d`

GitHub Actions run:

`36706677585`

Both compiler jobs produced:

```text
E7.3 PASS: provider/cache/request independence and overlap reuse
```

Fixture geometry:

```text
provider blocks: 16 x 8
cache blocks:    12 x 10
request 1:       (13,11,23,13)
```

The first request required four cache blocks and produced:

```text
materializations = 4
misses           = 4
hits             = 0
```

A second halo-expanded dependency request reused four existing blocks and
materialized only two new blocks:

```text
cumulative materializations = 6
cumulative misses           = 6
cumulative hits             = 4
```

Six padded cache blocks retained 780 physical bytes in total.

The experiment demonstrates that:

- provider block geometry can remain entirely inside the source adapter;
- cache-block geometry can be chosen independently of provider and request
  geometry;
- one logical request can be assembled from several cache entries;
- overlapping neighbourhood/halo dependencies can reuse cache entries without
  making halo geometry part of cache identity;
- cache identity need not contain provider-native tile coordinates.

### E7.4 — failure isolation and residency admission

Status: **PASS** on DMD 2.111.0 and LDC 1.41.0.

Verified research head:

`4aaa631f7c81353a008807775e8b7fd17525fdf4`

Verified raster-d develop:

`2ea33562ca217ef9f552d0be397100326847c08d`

GitHub Actions run:

`36706970424`

Both compiler jobs produced:

```text
E7.4 PASS: empty work, failure isolation and separate residency admission
```

The experiment demonstrates that:

1. a valid empty logical request is zero work: no allocation, source call,
   cache hit or cache miss is required;
2. source/materialization failure before cache commit leaves existing cached
   state unchanged and readable;
3. a failed candidate is not published into cache state;
4. a request whose minimum simultaneous resident working set is 288 bytes is
   explicitly rejected by a 256-byte residency-admission budget;
5. a smaller 192-byte working set can be admitted and released;
6. cache-retention budget and request-residency admission are separate
   accounting domains.

## 9. Research conclusions

The evidence supports a narrower architecture than a monolithic cache manager.

### KEEP

Keep these semantics for production design:

- `ProviderBlock != CacheBlock != Region != ProcessingTask`;
- cache identity is independent of provider-native block/tile coordinates;
- logical cache-block regions may differ from source/provider and processing
  request geometry;
- retained cache values can use existing `RasterLease` ownership;
- consumer-retained leases may outlive cache eviction safely;
- cache ownership must be accounted in physical resource bytes;
- one shared/interleaved physical allocation is counted once, independent of
  logical plane count;
- failed materialization is not committed into cache state;
- empty requests remain zero work;
- cache-retention accounting and total/request residency admission are distinct
  contracts;
- an operation whose minimum admitted working set exceeds its residency budget
  fails explicitly rather than silently oversubscribing memory.

### REJECT

Do not build production semantics around these assumptions:

- provider tile/block identity as the generic cache key;
- cache block equal to processing region;
- cache block equal to provider block;
- logical plane spans as a substitute for physical resource byte cost;
- cache eviction implies immediate physical deallocation;
- cache byte budget equals total engine memory budget;
- cache policy embedded in RasterView, Region2D or source materialization;
- scheduler or worker-pool semantics required merely to make cache reuse work.

### DEFER

The experiments do not yet justify:

- a public `RasterCache` API;
- a public source-identity type;
- the exact production schema-identity representation;
- one mandatory cache-block size or geometry policy;
- LRU as the required production eviction policy;
- borrowed cache outputs whose lifetime depends directly on cache mutation;
- concurrent cache mutation/locking semantics;
- async materialization, prefetch, scheduling or worker pools;
- GPU residency accounting;
- a unified total-engine memory manager;
- cache policy for imagery pyramids or provider-specific encoded data.

## 10. Promotion decision

**Do not promote the research cache implementation itself.**

The fixed-size arrays, research-local keys, LRU oracle, source fixture and
assembly code are disposable evidence.

The evidence does justify a smaller production follow-up focused first on
package-internal bounded-residency accounting and retained-resource cost
metadata. That production slice must remain independent of:

- source/provider identity;
- cache replacement policy;
- scheduler policy;
- imagery semantics;
- public cache API.

A later cache-reuse production slice can build on that accounting contract once
its concrete source/schema identity requirements are justified by consumers.

## 11. Completion gate result

Issue #3's research completion gate is satisfied:

- stable provider-independent cache identity shape was demonstrated;
- retained ownership and eviction lifetime were exercised with real
  `RasterLease`;
- strict cache byte accounting was demonstrated;
- cache and total residency accounting were separated;
- provider/cache/request geometry independence was demonstrated;
- multi-block assembly and halo-overlap reuse were demonstrated;
- multi-plane padded/interleaved physical accounting was demonstrated;
- empty-work and materialization-failure semantics were demonstrated;
- over-budget working-set admission was demonstrated;
- DMD 2.111.0 and LDC 1.41.0 both pass.

The next step is explicit promotion review in raster-d, not additional cache
machinery in this research branch.
