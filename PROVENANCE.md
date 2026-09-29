# Initial snapshot provenance

The initial `raster-d-research` corpus is a preserved snapshot of detailed
research/evidence that previously lived in the production `raster-d`
repository.

## Source

- repository: `alex-1974/raster-d`
- source branch at research closeout: `research/r0_5-cpu-simd`
- source commit: `91fd96dceb70886f2cf33f7af8a6cce30f78168a`

Selected source paths:

- `experiments/**`
- `docs/research/**`

## History model

This split intentionally does not rewrite `raster-d` history.

Historical commits in the production repository remain available. After the
snapshot is independently verified, duplicate detailed research paths may be
removed from the current production tree while accepted production code,
tests, ADRs, compact architecture documentation, and release engineering remain
in `raster-d`.

Research does not become public API merely by existing here. Promotion into
production remains an explicit production change.
