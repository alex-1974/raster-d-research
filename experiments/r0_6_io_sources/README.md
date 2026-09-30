# R0.6 I/O Source Experiments

Status: active research.

## Prototype A — caller-owned materialization

Purpose:

Test whether a generic source can materialize a logical raster region directly
into caller/engine-owned resident storage using only the existing public
`raster-d` API.

Contract under test:

- caller owns allocation policy;
- caller constructs retained writable resident raster storage;
- source receives only logical region geometry plus a writable resident view;
- source writes samples into resident coordinates;
- source does not allocate or return ownership;
- provider tile geometry is absent;
- cache and scheduler concepts are absent;
- logical coordinates remain outside resident descriptor coordinates.

Cases:

1. contiguous single-plane ubyte destination;
2. padded-row single-plane ubyte destination;
3. non-zero and very large logical origins;
4. verification through the read-only RasterView path after materialization.

Expected result:

`R0.6 Prototype A PASS: caller-owned contiguous and padded materialization`

## Local workspace run

From this experiment directory:

    dub run --compiler=dmd
    dub run --compiler=ldc2

The experiment uses a workspace-local path dependency on the sibling
`raster-d` repository so it tests the current production develop implementation
rather than an older registry release.

## Interpretation rule

A passing prototype demonstrates only that caller-owned materialization is
viable with current raster ownership/view semantics.

It does not establish a production source API.

Promotion still requires at least one structurally different source shape and
the remaining R0.6 ownership/error-boundary experiments.
