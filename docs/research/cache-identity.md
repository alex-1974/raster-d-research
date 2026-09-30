# Cache Identity Boundary Research

Status: complete. E8.1 through E8.5 passed on the workspace baseline compilers.

Issue: raster-d-research #5

## 1. Purpose

This research asks when two retained raster materializations represent the same
reusable semantic value after production M1.4.

The problem is deliberately separated from cache replacement, scheduling and
provider-native tiling.

The established invariant remains:

```text
ProviderBlock != CacheBlock != Region != ProcessingTask
```

M1.4 additionally established that physical residency accounting is independent
of cache policy.

## 2. Central distinction

The first identity hypothesis separates:

```text
semantic raster value identity
!=
resident representation compatibility
```

Two retained rasters may represent exactly the same logical samples while using:

- different row stride;
- different padding;
- different allocation addresses;
- different physical resource ownership.

Those representation differences must not automatically make the semantic
source value different.

Conversely, identical logical regions are not reusable when they come from:

- different semantic sources;
- different source generations;
- incompatible schemas.

## 3. Initial semantic identity candidate

E8.1 uses a research-local structural key:

```text
SemanticRasterKey
    source identity
    source generation
    logical region
    schema identity
```

Provider block/tile identity is absent.

Resident stride/layout is also absent from semantic identity.

This is not yet a production type proposal.

## 4. Why generation is explicit

A stable source instance may change its content.

Without a generation/version component, the same source identity and logical
region could create a false cache hit after mutation.

E8.1 therefore tests generation as semantic invalidation rather than cache
replacement policy.

## 5. Schema identity

Schema identity represents semantic interpretation that can make equal raw
coordinates incompatible, for example:

- plane/component meaning;
- sample interpretation;
- other caller-owned semantic distinctions.

The exact production representation is deliberately unresolved.

D template sample type may already distinguish some incompatible values at
compile time. E8.1 does not duplicate compile-time type identity into a runtime
token merely by default.

## 6. Resident representation

A cache entry contains a concrete retained representation.

Semantic equality alone does not guarantee that one representation directly
satisfies every later destination-layout requirement.

The working distinction is:

```text
same semantic value
+
representation acceptable to consumer
=
direct reusable resident value
```

A later layer may instead copy/repack the semantic value into another resident
layout.

This allows semantic identity to stay independent of stride/padding while still
making representation compatibility explicit.

## 7. E8.1 — semantic false-hit matrix

Status: **PASS** on DMD 2.111.0 and LDC 1.41.0.

Verified research head:

`8f91f84074db062f6047890988c4995e08fd87ff`

Verified raster-d develop:

`8dc3180979c908f305274adab8f78b61ecfe7f14`

GitHub Actions run:

`36708342513`

Both compiler jobs produced:

```text
E8.1 PASS: semantic identity prevents false hits without resident-layout coupling
```

E8.1 tests:

- same source/generation/region/schema -> equal identity;
- different source -> different identity;
- different generation -> different identity;
- different region -> different identity;
- different schema -> different identity;
- same semantic identity with compact versus padded resident layout -> semantic
  identity remains equal while representation metadata differs;
- provider block geometry does not participate in identity;
- huge logical origins remain valid identity coordinates.

## 8. Promotion rule

A passing E8.1 does not justify a production cache key.

Later experiments must compare whether raster-d should:

- define the structural key;
- accept a caller-owned opaque/generic key;
- require identity capabilities from the source;
- or leave reusable caching entirely to adapters/consumers.

The preferred production shape is the one that prevents false hits while
requiring raster-d to know the least source-domain semantics.


## 9. E8.2 — caller-owned generic key responsibility

Status: **PASS** on DMD 2.111.0 and LDC 1.41.0.

Verified research head:

`3948ade028663d171e621d4b9bb2308748e5d135`

Verified raster-d develop:

`8dc3180979c908f305274adab8f78b61ecfe7f14`

GitHub Actions run:

`36708813685`

Both compiler jobs produced:

```text
E8.2 PASS: caller-owned generic keys preserve semantics without raster-d source knowledge
```

The E8.2 cache is generic over `Key` and does not inspect any source-domain
fields.

The caller-owned key fixtures cover:

- procedural sources;
- in-memory sources;
- scientific field schemas;
- block-backed sources;
- fully opaque caller keys;
- automatically assigned source-instance IDs.

Measured conclusions:

1. raster-d cache machinery does not need to know the decomposition of source,
   generation, region or schema identity if the caller supplies one key with
   correct equality semantics;
2. two separately constructed but semantically equivalent procedural sources
   can deliberately share one key and reuse one value;
3. two sources with equal logical extents but different behavior remain
   distinct when the caller key distinguishes them;
4. generation changes and schema changes can invalidate identity without cache
   machinery understanding either concept;
5. provider block geometry remains absent from identity;
6. resident layout remains outside semantic identity;
7. automatic source-instance IDs are safe against false hits but
   over-discriminate semantically equivalent source instances and therefore
   cause avoidable misses;
8. D template instantiation already distinguishes typed cache values, so E8.2
   does not justify a mandatory duplicate runtime sample-type token.

### Interim ownership conclusion

The strongest candidate is now:

```text
cache mechanics own storage / lookup
caller owns semantic key construction
```

rather than:

```text
raster-d owns one universal source/schema/generation identity model
```

This remains an interim result until real retained RasterLease integration is
tested.

## 10. E8.3 — compile-time hash/equality specialization

Status: **PASS** on DMD 2.111.0 and LDC 1.41.0.

Final verified research head:

`0bc7fd9d5c8815261eb50b839afdac5f8bcf4be2`

Verified raster-d develop:

`8dc3180979c908f305274adab8f78b61ecfe7f14`

GitHub Actions run:

`36709070680`

Both compiler jobs produced:

```text
E8.3 PASS: compile-time hash/equality specialization keeps identity lookup @nogc
```

E8.3 uses:

```d
HashedIdentityCache!(
    Key,
    Value,
    SlotCount,
    hashKey,
    sameKey
)
```

where both `hashKey` and `sameKey` are alias template parameters.

The fixed-capacity open-addressed lookup and insertion paths remain:

```text
@safe pure nothrow @nogc
```

in the experiment.

This demonstrates that a generic caller-owned identity model does not require:

- a boxed runtime key object;
- inheritance;
- a universal key base class;
- dynamic allocation merely for identity dispatch;
- runtime source-type switching.

Different key domains instantiate specialized cache code.

### D-language correction encountered

The first E8.3 run failed identically on DMD and LDC because the test code used
two invalid D source forms:

1. `auto` initialized from a `const` struct retained the const qualification
   and was then mutated;
2. temporary struct rvalues were passed to `ref const` parameters.

The experiment was corrected by constructing the changed keys explicitly and by
passing named lvalue keys.

No hash/equality design change was needed.

This is ordinary D type/reference semantics, not evidence against the generic
key approach.

## 11. Identity candidate comparison

| Candidate | False-hit safety | Semantic reuse across equivalent source instances | raster-d source-domain coupling | Specializable hot path | Current result |
| --- | --- | --- | --- | --- | --- |
| Universal raster-d structural source/schema key | potentially strong | possible only if raster-d understands equivalence | high | yes | reject as mandatory generic contract |
| Source capability returning identity token | strong if source implements correctly | source-dependent | medium | yes | defer / possibly optional adapter capability |
| Caller-owned generic key | strong if caller contract is correct | yes | minimal | yes, E8.3 | strongest KEEP candidate |
| Automatic source-instance ID | strong against false hits | no | low | yes | reject as sole generic identity |
| Structural source configuration derived by raster-d | unknowable generically | potentially | high / domain-specific | possible | caller responsibility, not raster-d |
| No reusable cache machinery in raster-d | avoids raster-d identity contract | consumer-specific | none | consumer-specific | still possible, but duplicates generic mechanics |

The remaining major gate is real retained-value integration.

## 12. Next experiment — E8.4 retained identity integration

E8.4 must combine caller-owned identity with real raster-d ownership:

- cache values are real `RasterLease`;
- same semantic key reuses retained data;
- a copied lease survives independently of cache storage;
- generation changes produce misses;
- different source behavior with equal logical extent produces no false hit;
- provider block geometry remains source-local;
- retained scientific/multi-plane storage remains compatible with caller-owned
  identity;
- semantic identity remains separate from resident stride/padding.

Only after E8.4 passes should Issue #5 move toward final KEEP / REJECT / DEFER
conclusions.


## 13. E8.4 — retained RasterLease identity integration

Status: **PASS** on DMD 2.111.0 and LDC 1.41.0.

Verified research head:

`f5e20a3f446db8d70e0d3f670abdeb287c8cd4ee`

Verified raster-d develop:

`8dc3180979c908f305274adab8f78b61ecfe7f14`

GitHub Actions run:

`36709522454`

Both compiler jobs produced:

```text
E8.4 PASS: caller-owned identity integrates with retained RasterLease and source generations
```

E8.4 uses real `RasterLease!ubyte` values.

It demonstrates:

1. two separately constructed procedural source objects can reuse one retained
   value when the caller deliberately assigns them the same semantic identity;
2. those source objects may use different provider-native block geometry without
   changing semantic identity;
3. different source behavior over the same logical region produces a miss when
   the caller key distinguishes the behavior;
4. source generation changes invalidate identity without the cache
   understanding what a generation means;
5. an externally copied RasterLease remains valid after the cache container
   releases its copy;
6. a scientific two-plane padded/interleaved retained raster works with the same
   caller-owned identity approach;
7. incompatible scientific schema identity prevents false reuse;
8. huge logical origins remain ordinary caller-key coordinates.

This closes the main gap between the abstract E8.2/E8.3 key model and actual
raster-d retained ownership.

## 14. E8.5 — caller identity correctness contract

Status: **PASS** on DMD 2.111.0 and LDC 1.41.0.

Verified research head:

`683ae8beadcf98d191287e633c59975c2fec4aa2`

Verified raster-d develop:

`8dc3180979c908f305274adab8f78b61ecfe7f14`

GitHub Actions run:

`36709677358`

Both compiler jobs produced:

```text
E8.5 PASS: identity correctness is an explicit caller contract
```

E8.5 demonstrates the failure boundary directly:

- if the caller omits a semantic distinction from the key, the generic cache
  can produce a false hit and cannot detect that the reused value is wrong;
- if the caller includes unstable accidental state in the key, semantically
  identical data produces avoidable misses;
- a complete semantic key prevents the false hit;
- hash/equality implementations must satisfy:

```text
sameKey(a, b) => hashKey(a) == hashKey(b)
```

The cache cannot infer or repair contradictory semantic identity supplied by
the caller.

Therefore identity correctness is a caller contract, while cache mechanics are
responsible only for honoring the supplied equality/hash semantics.

## 15. Final conclusions

### KEEP

Keep these semantics for any production reusable-retained layer:

- semantic value identity is distinct from resident representation;
- provider block/tile geometry is not generic cache identity;
- resident stride, padding and allocation address are not semantic identity;
- caller-owned key construction is the generic identity boundary;
- mutable/changing sources express invalidation through caller-owned identity,
  commonly by generation/version;
- schema distinctions belong to caller identity when they change sample
  semantics;
- cache machinery may be templated over `Key` without understanding source,
  generation, Region2D or schema fields;
- equality and hashing may be compile-time alias/template parameters;
- specialized fixed-capacity lookup can remain `@safe pure nothrow @nogc`;
- real retained `RasterLease` values are compatible with this model;
- independent retained leases may outlive cache storage;
- the caller must guarantee stable, complete identity and consistent
  hash/equality semantics.

### REJECT

Do not make these the mandatory generic raster-d identity model:

- provider-native tile/block ID;
- one universal raster-d `SourceId + Generation + Region + Schema` runtime
  struct;
- automatically assigned source-instance ID as the sole semantic source
  identity;
- resident stride/layout/padding as semantic identity;
- structural introspection of arbitrary source configuration by raster-d;
- boxed runtime key hierarchy or mandatory inheritance;
- duplicate runtime sample-type identity when D template instantiation already
  separates typed cache values;
- cache-side attempts to infer whether a caller key is semantically complete.

### DEFER

This research does not yet require:

- a public cache-key API;
- a public `RasterSourceId`;
- one standardized schema-identity type;
- cross-process/persistent cache identity;
- serialization of keys;
- distributed/network cache identity;
- source identity capabilities on every source type;
- concurrent cache lookup/mutation;
- replacement/eviction policy;
- async/prefetch/scheduler behavior;
- imagery pyramid or HTTP cache-control semantics.

## 16. Promotion recommendation

Do **not** promote `SemanticKey`, `ProceduralKey`, or any other research key
type.

The reusable production concept is smaller:

```text
generic retained lookup/store over caller-owned Key
```

with identity semantics supplied by the caller.

A narrowly scoped production follow-up may therefore evaluate a package-internal
retained lookup/store that:

- is templated on caller-owned `Key`;
- stores typed `RasterLease!T`;
- accepts caller-compatible equality/hash specialization;
- preserves the M1.4 bounded-residency contract;
- has explicit full/admission/miss failure behavior;
- introduces no provider/source/schema type of its own;
- introduces no scheduler;
- does not yet require one replacement policy.

The research cache implementations themselves remain disposable evidence.

## 17. Completion gate

Issue #5's completion gate is satisfied.

Evidence now covers:

- procedural equivalent and different-behavior sources;
- mutable generation invalidation;
- retained/in-memory ownership behavior;
- scientific two-plane retained storage;
- block-backed/provider-independent source geometry;
- huge logical origins;
- semantic versus resident-representation separation;
- caller-owned opaque and composite keys;
- compile-time specialized hash/equality;
- real RasterLease reuse/lifetime;
- incorrect/incomplete/unstable identity failure modes;
- DMD 2.111.0 and LDC 1.41.0 verification.

The minimum identity required to prevent false hits is therefore not one
raster-d-defined field layout. It is a caller-owned key whose equality/hash
contract completely and stably represents the semantic value the caller wishes
to reuse.
