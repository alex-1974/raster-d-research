# Cache Boundary Experiments

Issue: raster-d-research #3

Status: E7.1 PASS on DMD 2.111.0 and LDC 1.41.0.

## E7.1

The first experiment isolates cache semantics from raster ownership.

It tests a bounded research-local cache with:

- `CacheKey = sourceId + logicalRegion + schemaId`;
- strict retained-byte accounting;
- lookup hit/miss accounting;
- explicit pin/unpin state;
- deterministic least-recently-used eviction among unpinned entries;
- explicit rejection when one entry exceeds the entire budget;
- logical request geometry independent of both provider and cache block
  geometry.

This is not a production cache implementation.

A passing E7.1 only permits the next experiment to integrate real
`RasterLease` retained ownership.

## Local run

From this directory:

    dub run --compiler=dmd
    dub run --compiler=ldc2

Expected final line:

    E7.1 PASS: cache identity, byte budget, pinning and deterministic eviction


## Verified matrix

GitHub Actions run: `36705940582`

- DMD 2.111.0 / DUB 1.40.0 — PASS
- LDC 1.41.0 / DUB 1.40.0 — PASS
- raster-d develop: `2ea33562ca217ef9f552d0be397100326847c08d`

Both jobs printed the expected final line.
