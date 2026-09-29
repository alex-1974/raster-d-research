# raster-d-research

Research, experiments, benchmarks, compiler/code-generation probes, validation
evidence, and historical design work for
[raster-d](https://github.com/alex-1974/raster-d).

This repository is the research/evidence companion to the production
`raster-d` library. It intentionally contains material that should not be part
of normal DUB consumer downloads.

## Relationship to raster-d

- `raster-d` is the production and release repository.
- `raster-d-research` preserves detailed evidence behind design decisions.
- Production APIs must not depend on this repository.
- Relevant conclusions are promoted back to `raster-d` through production
  code, tests, compact ADRs, architecture documentation, and release-quality
  maintenance contracts.
- Experimental APIs, compiler probes, benchmark harnesses, rejected designs,
  and long-form research evidence remain here.

## Initial snapshot

The initial research snapshot is imported from:

- source repository: `alex-1974/raster-d`
- source commit: `91fd96dceb70886f2cf33f7af8a6cce30f78168a`
- selected source paths:
  - `experiments/**`
  - `docs/research/**`

No Git history rewrite is required for the split. Historical `raster-d`
commits remain available in the production repository.

See `PROVENANCE.md` for the pinned source and verification record.
