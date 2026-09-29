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

## Snapshot

- destination repository: `alex-1974/raster-d-research`
- exact snapshot commit: `dee2e0097a335139362d936b4c8bd47c2d21af17`
- selected files: **228**
- selected bytes: **2,840,033**

The imported research corpus was independently verified before commit:

- identical relative paths;
- identical file modes;
- identical Git blob identities;
- identical total byte count.

## History model

This split intentionally does not rewrite `raster-d` history.

Historical commits in the production repository remain available. After the
snapshot is independently verified, duplicate detailed research paths may be
removed from the current production tree while accepted production code,
tests, ADRs, compact architecture documentation, and release engineering remain
in `raster-d`.

Research does not become public API merely by existing here. Promotion into
production remains an explicit production change.
