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

## Prototype B — retained/adopted source output

Purpose:

Test the structurally different case where the source allocates and fills
resident storage itself, then transfers ownership into raster-d retained
storage.

Contract under test:

- source allocates and fills one resident buffer;
- source wraps the allocation in `OwnedByteResource`;
- successful `tryImportOwnedRaster` transfers the release obligation to a
  `RasterLease`;
- the published resident raster is still rebased to `(0,0)`;
- logical origin remains source metadata, not pointer geometry;
- a deliberately invalid backing layout fails before ownership commit;
- PRE-COMMIT failure leaves the `OwnedByteResource` armed and the output lease
  empty.

Expected additional result:

`R0.6 Prototype B PASS: retained source transfer and PRE-COMMIT ownership preservation`

Prototype B does not prove that source-owned allocation should be the primary
production path. It tests whether retained/adopted output can coexist cleanly
as a secondary capability beside caller-owned materialization.

## Prototype C — non-image multi-plane strided consumer

Purpose:

Test the candidate caller-owned contract with a structurally different
non-image source: a two-component scientific vector field.

Storage under test:

- two logical planes (U and V components);
- one physical allocation;
- interleaved samples;
- explicit sample stride of 2 bytes;
- padded rows;
- logical origin independent of resident descriptor origin.

The source writes through the same public `WritableRasterView!ubyte` capability
used by Prototype A.

This checks that the candidate contract is not accidentally image-specific or
restricted to single-plane contiguous storage.

Expected additional result:

`R0.6 Prototype C PASS: non-image two-plane interleaved padded vector field`

## Prototype D — provider/block independence

Purpose:

Test whether a source whose own internal organisation is fixed-block based can
still satisfy an arbitrary logical request through the same generic
caller-owned materialization boundary.

Fixture:

- source-internal blocks: 16 x 8;
- logical request origin: (123,77), deliberately misaligned to both axes;
- logical request size: 23 x 13, crossing multiple internal blocks;
- caller-owned resident destination with padded rows.

The source reconstructs each logical coordinate from simulated internal block
coordinates before writing to the resident destination.

The generic materialization contract receives no provider-block geometry.

Expected additional result:

`R0.6 Prototype D PASS: arbitrary logical request independent of provider blocks`
