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

## Supplemental preserved artifacts

Two research-specific R0.3 support artifacts lived outside the initial
experiments/** and docs/research/** snapshot and were preserved separately
before their removal from the current raster-d production tree.

Source repository: alex-1974/raster-d

Preserved artifacts:

- tools/codegen/r0_3_mir_codegen.sh
  - Git blob: 03bad82511f3d42503c93766bef8ac3e45b541ae
- .github/workflows/architecture.yml
  - Git blob: 6872b60ec0ece0d8c2d73719591d3c2853af5620

Both destination blobs were verified to be identical to their raster-d
source blobs.
