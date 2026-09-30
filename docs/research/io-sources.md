# R0.6 — Generic raster source and materialization boundary

Status: ACTIVE RESEARCH

Production target: `alex-1974/raster-d` M1.3

Tracking issue: #1

## 1. Question

Determine the smallest generic source/materialization contract needed by
`raster-d` after M1.1 request/dependency geometry and M1.2 logical-to-resident
materialization planning.

The contract must support real raster producers without coupling the core
library to:

- GDAL;
- codecs;
- provider-native tiles;
- imagery-specific source identity;
- cache policy;
- worker pools or schedulers;
- asynchronous frameworks;
- border policy.

## 2. Current production inputs

`raster-d` already provides the following relevant production contracts:

- `Region2D` as coordinate-neutral rectangular geometry;
- package-internal request-bounded dependency expansion;
- explicit directional context deficit;
- package-internal `RequestMaterializationPlan`;
- logical/global dependency geometry separated from resident descriptor geometry;
- retained raster ownership/import through `OwnedByteResource` and raster import;
- lease-bound `RasterLease` / `RasterView` resident storage semantics;
- byte-oriented external layout metadata through `PlaneByteLayout`.

R0.6 must build on these contracts rather than inventing a parallel raster
representation.

## 3. Reference-system observations

### 3.1 GDAL

GDAL RasterIO exposes a rectangular source window independently from the
destination buffer dimensions and allows explicit pixel, line and band spacing.

Relevant properties:

- arbitrary raster windows do not have to align with source tile boundaries;
- callers may supply the destination memory buffer;
- buffer shape may differ from source window shape, allowing resampling;
- pixel/line/band spacing describes external memory layout;
- a dataset groups one or more raster bands;
- `AdviseRead` is an optional performance hint, not a correctness requirement.

R0.6 interpretation:

- KEEP the idea that logical request geometry is independent of provider-native
  block/tile geometry;
- KEEP caller-provided destination storage as a first-class candidate;
- KEEP explicit layout/stride description;
- REJECT GDAL dataset, band numbering, resampling and geospatial metadata as
  generic `raster-d` source semantics.

Primary documentation:

- https://gdal.org/en/stable/api/gdaldataset_cpp.html

### 3.2 libvips

libvips is demand-driven: loading commonly fetches header/metadata first and
pixel evaluation occurs when an output is demanded. It supports sequential
access hints, cancellation/kill during evaluation, operation caching and
bounded cache configuration.

R0.6 interpretation:

- KEEP separation between source metadata/opening and actual pixel
  materialization;
- KEEP demand-driven region materialization as an architectural reference;
- DEFER cancellation, operation cache and concurrency to scheduler/cache
  research rather than placing them in the first source contract;
- REJECT image-domain metadata and libvips pipeline semantics as core raster
  source requirements.

Primary documentation:

- https://libvips.github.io/pyvips/intro.html
- https://libvips.github.io/pyvips/vimage.html

### 3.3 GEGL

GEGL source operations receive an output buffer plus an ROI and write their
result into that supplied buffer. Area filters separately declare required
neighbourhood pixels beyond the output window.

R0.6 interpretation:

- KEEP caller-owned/output-buffer materialization as a strong candidate;
- KEEP output ROI separate from dependency/halo geometry;
- KEEP neighbourhood dependency as operation semantics rather than source
  policy;
- REJECT GEGL graph/object hierarchy as a required `raster-d` abstraction.

Primary documentation:

- https://www.gegl.org/gegl-operation-source.h.html
- https://www.gegl.org/operation-api.html

### 3.4 Halide

Halide separates the requested realization domain from the buffer that stores
the result. A pipeline may allocate a result or realize into an existing
caller-provided buffer. Returned buffers are not guaranteed to be contiguous.

R0.6 interpretation:

- KEEP caller-owned realization as a central candidate;
- KEEP allocation as a policy separable from computation/materialization;
- KEEP non-contiguous resident layouts legal;
- REJECT Halide scheduling/JIT semantics as generic source semantics.

Primary documentation:

- https://halide-lang.org/docs/api/generated/Func.html
- https://halide-lang.org/docs/api/generated/Pipeline.html
- https://halide-lang.org/docs/tutorial/lesson_06_realizing_over_shifted_domains.html

### 3.5 OpenCV

`cv::Mat` is primarily an in-memory dense-array/view abstraction. It supports
O(1) ROI headers, external memory and explicit row step, but it is not a
streaming source contract.

R0.6 interpretation:

- KEEP it as evidence that external storage plus stride metadata is a common
  interoperability boundary;
- KEEP O(1) resident ROI/view semantics as already reflected by `RasterView`;
- REJECT `Mat` itself as a source/provider architecture model.

Primary documentation:

- https://docs.opencv.org/4.13.0/d3/d63/classcv_1_1Mat.html

## 4. Preliminary comparison matrix

| Property | GDAL | libvips | GEGL | Halide | OpenCV | R0.6 direction |
|---|---|---|---|---|---|---|
| rectangular region request | yes | yes / demand driven | yes | realization domain | ROI only | KEEP |
| caller-provided output memory | yes | not the primary high-level model | yes | yes | external memory/header | KEEP |
| explicit resident stride/layout | yes | internal/image layout | buffer-backed | Buffer layout | yes | KEEP |
| provider-native tile required by API | no | no | no | no | no | REJECT |
| allocation owned by source required | no | no | no | no | no | REJECT |
| source metadata separable from pixel evaluation | yes | yes | yes | yes | n/a | KEEP |
| cache policy part of minimal source contract | no | separate mechanism | framework-level | schedule/runtime | no | REJECT/DEFER |
| scheduler/threading part of source contract | no | separate evaluation policy | framework policy | schedule | no | REJECT/DEFER |
| neighbourhood/halo belongs to source | no | pipeline dependency | operation dependency | computation bounds | no | REJECT |

## 5. First candidate boundary

The first candidate is deliberately package-internal and synchronous.

Conceptually:

    materialization plan
        + caller-owned resident destination
        + source capability
        -> materialization result

The source capability should initially need only enough information to populate
the already-planned logical `validInput` into the supplied resident raster
geometry.

This candidate intentionally separates:

1. source metadata/capability;
2. logical request/dependency planning;
3. resident destination allocation/ownership;
4. pixel materialization;
5. cache and scheduling policy.

## 6. Caller-owned destination versus retained-source output

### Candidate A — caller-owned destination

The engine/caller supplies resident storage and the source fills it.

Advantages:

- maps directly to GDAL RasterIO-style buffers;
- maps directly to GEGL source output buffers;
- maps directly to Halide realization into an existing buffer;
- keeps memory budgeting outside the source;
- allows cache-owned storage later;
- makes bounded residency explicit;
- avoids forcing every source to expose transferable ownership.

Risks/questions:

- source must understand the destination sample/layout contract;
- conversion responsibility must be explicit;
- some decoders/providers may already own an optimal retained buffer.

Preliminary status: KEEP AS PRIMARY EXPERIMENT.

### Candidate B — source returns retained resident storage

The source materializes and returns/adopts storage as a `RasterLease` or
equivalent retained result.

Advantages:

- can permit zero-copy adoption of decoder/provider-owned memory;
- may be natural for sources that already produce stable retained buffers.

Risks/questions:

- makes allocation/ownership policy part of the source boundary;
- complicates memory-budget enforcement;
- can encourage provider-native layout to leak into processing policy;
- borrowed versus retained outputs need separate lifetime semantics.

Preliminary status: KEEP AS SECONDARY EXPERIMENT; DO NOT MAKE THE ONLY
PRODUCTION PATH.

## 7. Runtime interface versus compile-time capability

No evidence currently requires a public inheritance-based `RasterSource`
interface.

The first experiment should prefer a package-internal callable/template
capability so that:

- procedural and test sources remain zero-overhead;
- adapter libraries can wrap external APIs without inheriting from a raster-d
  base class;
- public virtual dispatch is not frozen before multiple real consumers exist.

Preliminary status:

- public runtime-polymorphic base class: DEFER;
- package-internal callable/template experiment: KEEP.

## 8. Generic metadata question

A source/materializer may eventually need metadata such as:

- logical extent;
- sample type;
- plane count;
- possibly per-plane semantics/layout capability.

However R0.6 has not yet established which of these belong in one persistent
`SourceInfo` type versus being known statically or supplied by a focused
adapter.

Do not promote a broad metadata object until the experiments require it.

## 9. Failure boundary

The generic layer should distinguish at least:

- invalid logical/materialization request;
- unsupported destination representation;
- source/materialization failure.

Provider-specific diagnostics should remain available to adapters without
requiring `raster-d` to standardize every external error domain.

The exact error carrier remains open.

## 10. Cancellation and asynchronous I/O

libvips and external I/O systems show cancellation/prefetch can matter, but
the current evidence does not justify placing cancellation tokens, futures,
event loops or worker-pool concepts in the first materialization contract.

Preliminary status: DEFER TO EXECUTION/SCHEDULER INTEGRATION.

## 11. Required experiments

R0.6 should now implement small competing prototypes for:

1. caller-owned contiguous single-plane `ubyte` materialization;
2. caller-owned padded/strided destination;
3. caller-owned representative multi-plane destination;
4. retained-source/adopted storage path;
5. huge logical extent with a small requested materialization;
6. non-zero logical origin rebased to resident `(0,0)`;
7. ownership-transfer failure before and after adoption;
8. a GDAL-shaped adapter mock whose logical requests are intentionally
   misaligned with provider/block geometry.

## 12. Current KEEP / REJECT / DEFER

KEEP:

- logical region requests independent of provider tiles;
- caller-owned destination materialization;
- explicit resident layout/stride contract;
- separate source metadata and pixel materialization;
- optional retained/adopted source result as a secondary path;
- package-internal compile-time/callable capability for the first experiment.

REJECT for the minimal source contract:

- provider tile geometry;
- cache-block identity;
- scheduler/worker ownership;
- image-domain metadata;
- GDAL dataset/band types;
- mandatory source-owned allocation;
- mandatory contiguous output.

DEFER:

- public `RasterSource` type;
- cancellation tokens;
- async/futures;
- prefetch hints;
- cache integration;
- resampling semantics;
- public source-error hierarchy;
- public source metadata type.

## 13. Prototype A result — caller-owned destination

Status: PASS on both supported fast-floor compilers used locally for this research run.

Verified:

- DMD: PASS;
- LDC: PASS;
- contiguous single-plane ubyte destination;
- padded-row single-plane ubyte destination;
- non-zero and very large logical origins;
- resident descriptor geometry rebased independently of logical origin;
- materialization through public `WritableRasterView` sample writes;
- verification through public read-only `RasterView` access;
- no provider-tile, cache, scheduler or source-owned allocation requirement.

Observed D engineering detail:

`RasterLease.view()` requires a mutable non-scope lease receiver in this test
context. The verification helper therefore accepts `ref RasterLease!ubyte`.
This is a test/lifetime-callability constraint, not a source-contract semantic.

Conclusion:

Caller-owned destination materialization is viable with the current public
`raster-d` ownership/view surface and should remain the primary R0.6 candidate.

Prototype A alone is not sufficient for production promotion. R0.6 still
requires a structurally different retained/adopted source path and ownership
failure-boundary evidence.
## 13. Promotion gate

R0.6 must not promote a production M1.3 source API until experiments show:

- at least two materially different source shapes can use the same contract;
- one non-image consumer shape remains natural;
- caller-owned destination semantics integrate with current raster ownership
  and writable-view rules;
- retained-source adoption is either cleanly optional or shown necessary;
- provider tile/cache/scheduler concerns remain outside the contract;
- DMD and LDC pass;
- ownership and failure semantics are explicit.

Until then, this document is research evidence, not a production contract.
