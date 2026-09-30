# Cache Identity Boundary Research

Status: active research. E8.1 complete.

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
