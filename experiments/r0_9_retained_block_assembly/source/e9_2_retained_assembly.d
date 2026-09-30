module e9_2_retained_assembly;

import core.stdc.stdlib : malloc;
import std.algorithm.mutation : move;

import raster :
    OwnedByteResource,
    PlaneByteLayout,
    RasterLease,
    Region2D,
    WritableRasterView,
    tryAdoptMallocResource,
    tryImportOwnedRaster;


private struct BlockGridPolicy
{
    size_t blockWidth;
    size_t blockHeight;
    size_t anchorX;
    size_t anchorY;
}


private struct BlockKey
{
    size_t sourceId;
    size_t generation;
    Region2D region;
    size_t schemaId;
}


private struct StoreEntry
{
    bool occupied;
    BlockKey key;
    RasterLease!ubyte lease;
}


private struct ResearchRetainedStore(size_t Capacity)
{
    StoreEntry[Capacity] entries;
    size_t hits;
    size_t misses;


    bool tryAcquire(
        ref const BlockKey key,
        out RasterLease!ubyte lease
    )
    {
        lease = RasterLease!ubyte.init;

        foreach (ref entry; entries)
        {
            if (
                entry.occupied
                && entry.key == key
            )
            {
                lease = entry.lease;
                ++hits;
                return true;
            }
        }

        ++misses;
        return false;
    }


    bool insertOwned(
        BlockKey key,
        ref RasterLease!ubyte lease
    )
    {
        foreach (ref entry; entries)
        {
            if (
                entry.occupied
                && entry.key == key
            )
            {
                return false;
            }
        }

        foreach (ref entry; entries)
        {
            if (!entry.occupied)
            {
                entry.occupied = true;
                entry.key = key;
                entry.lease = move(lease);
                return true;
            }
        }

        return false;
    }
}


private struct BlockBackedSource
{
    size_t sourceId;
    size_t generation;
    size_t providerBlockWidth;
    size_t providerBlockHeight;
    size_t materializations;


    ubyte expected(
        size_t logicalX,
        size_t logicalY
    ) const
    @safe
    pure
    nothrow
    @nogc
    {
        const blockX =
            logicalX / providerBlockWidth;

        const blockY =
            logicalY / providerBlockHeight;

        const inBlockX =
            logicalX % providerBlockWidth;

        const inBlockY =
            logicalY % providerBlockHeight;

        const reconstructedX =
            blockX * providerBlockWidth
            + inBlockX;

        const reconstructedY =
            blockY * providerBlockHeight
            + inBlockY;

        return cast(ubyte)(
            cast(ubyte) reconstructedX
            ^ cast(ubyte) reconstructedY
            ^ cast(ubyte) generation
        );
    }


    bool materializeInto(
        Region2D logicalRegion,
        scope WritableRasterView!ubyte destination
    )
    @safe
    nothrow
    @nogc
    {
        if (
            destination.width != logicalRegion.width
            || destination.height != logicalRegion.height
            || destination.planeCount != 1
        )
        {
            return false;
        }

        foreach (y; 0 .. logicalRegion.height)
        {
            foreach (x; 0 .. logicalRegion.width)
            {
                if (
                    !destination.trySetSample(
                        0,
                        x,
                        y,
                        expected(
                            logicalRegion.x + x,
                            logicalRegion.y + y
                        )
                    )
                )
                {
                    return false;
                }
            }
        }

        ++materializations;
        return true;
    }
}


private bool tryEnd(
    Region2D region,
    out size_t endX,
    out size_t endY
)
@safe
pure
nothrow
@nogc
{
    endX = 0;
    endY = 0;

    if (
        region.width > size_t.max - region.x
        || region.height > size_t.max - region.y
    )
    {
        return false;
    }

    endX = region.x + region.width;
    endY = region.y + region.height;
    return true;
}


private bool containsRegion(
    Region2D outer,
    Region2D inner
)
@safe
pure
nothrow
@nogc
{
    size_t outerEndX;
    size_t outerEndY;
    size_t innerEndX;
    size_t innerEndY;

    if (
        !tryEnd(outer, outerEndX, outerEndY)
        || !tryEnd(inner, innerEndX, innerEndY)
    )
    {
        return false;
    }

    return
        inner.x >= outer.x
        && inner.y >= outer.y
        && innerEndX <= outerEndX
        && innerEndY <= outerEndY;
}


private bool appendExtentAnchoredBlocks(
    Region2D extent,
    Region2D request,
    BlockGridPolicy policy,
    ref Region2D[] blocks
)
{
    blocks.length = 0;

    if (
        policy.blockWidth == 0
        || policy.blockHeight == 0
        || request.empty()
        || policy.anchorX != extent.x
        || policy.anchorY != extent.y
        || !containsRegion(extent, request)
    )
    {
        return false;
    }

    size_t requestEndX;
    size_t requestEndY;
    size_t extentEndX;
    size_t extentEndY;

    if (
        !tryEnd(request, requestEndX, requestEndY)
        || !tryEnd(extent, extentEndX, extentEndY)
    )
    {
        return false;
    }

    const firstX =
        extent.x
        + ((request.x - extent.x) / policy.blockWidth)
            * policy.blockWidth;

    const firstY =
        extent.y
        + ((request.y - extent.y) / policy.blockHeight)
            * policy.blockHeight;

    size_t y = firstY;

    while (y < requestEndY)
    {
        const height =
            policy.blockHeight > extentEndY - y
            ? extentEndY - y
            : policy.blockHeight;

        size_t x = firstX;

        while (x < requestEndX)
        {
            const width =
                policy.blockWidth > extentEndX - x
                ? extentEndX - x
                : policy.blockWidth;

            blocks ~=
                Region2D(
                    x,
                    y,
                    width,
                    height
                );

            if (policy.blockWidth > size_t.max - x)
            {
                break;
            }

            x += policy.blockWidth;
        }

        if (policy.blockHeight > size_t.max - y)
        {
            break;
        }

        y += policy.blockHeight;
    }

    return blocks.length != 0;
}


private bool makeWritableLease(
    Region2D logicalRegion,
    size_t rowPaddingBytes,
    out RasterLease!ubyte lease
)
@system
{
    lease = RasterLease!ubyte.init;

    if (
        logicalRegion.empty()
        || logicalRegion.width
            > size_t.max - rowPaddingBytes
    )
    {
        return false;
    }

    const rowStride =
        logicalRegion.width + rowPaddingBytes;

    if (
        logicalRegion.height
            > size_t.max / rowStride
    )
    {
        return false;
    }

    const physicalBytes =
        rowStride * logicalRegion.height;

    auto memory =
        malloc(physicalBytes);

    if (memory is null)
    {
        return false;
    }

    OwnedByteResource resource;

    if (
        !tryAdoptMallocResource(
            memory,
            physicalBytes,
            resource
        )
    )
    {
        return false;
    }

    const result =
        tryImportOwnedRaster!ubyte(
            resource,
            [
                PlaneByteLayout(
                    0,
                    cast(ptrdiff_t) rowStride,
                    1
                )
            ],
            Region2D(
                0,
                0,
                logicalRegion.width,
                logicalRegion.height
            ),
            lease
        );

    return result.ok;
}


private bool materializeLease(
    ref BlockBackedSource source,
    Region2D logicalRegion,
    size_t rowPaddingBytes,
    out RasterLease!ubyte lease
)
@system
{
    if (
        !makeWritableLease(
            logicalRegion,
            rowPaddingBytes,
            lease
        )
    )
    {
        return false;
    }

    bool writableOk;

    scope auto writable =
        lease.tryWritableView(
            writableOk
        );

    return
        writableOk
        && source.materializeInto(
            logicalRegion,
            writable
        );
}


private bool copyOverlapIntoRequest(
    Region2D blockRegion,
    ref RasterLease!ubyte blockLease,
    Region2D request,
    scope WritableRasterView!ubyte destination
)
@safe
{
    size_t blockEndX;
    size_t blockEndY;
    size_t requestEndX;
    size_t requestEndY;

    if (
        !tryEnd(blockRegion, blockEndX, blockEndY)
        || !tryEnd(request, requestEndX, requestEndY)
    )
    {
        return false;
    }

    const startX =
        blockRegion.x > request.x
        ? blockRegion.x
        : request.x;

    const startY =
        blockRegion.y > request.y
        ? blockRegion.y
        : request.y;

    const endX =
        blockEndX < requestEndX
        ? blockEndX
        : requestEndX;

    const endY =
        blockEndY < requestEndY
        ? blockEndY
        : requestEndY;

    auto sourceView =
        blockLease.view();

    foreach (logicalY; startY .. endY)
    {
        foreach (logicalX; startX .. endX)
        {
            ubyte value;

            if (
                !sourceView.trySample(
                    0,
                    logicalX - blockRegion.x,
                    logicalY - blockRegion.y,
                    value
                )
                || !destination.trySetSample(
                    0,
                    logicalX - request.x,
                    logicalY - request.y,
                    value
                )
            )
            {
                return false;
            }
        }
    }

    return true;
}


private bool assembleRequest(
    ref ResearchRetainedStore!16 store,
    ref BlockBackedSource source,
    Region2D logicalExtent,
    Region2D request,
    BlockGridPolicy policy,
    out RasterLease!ubyte destination
)
@system
{
    destination = RasterLease!ubyte.init;

    Region2D[] blocks;

    if (
        !appendExtentAnchoredBlocks(
            logicalExtent,
            request,
            policy,
            blocks
        )
        || !makeWritableLease(
            request,
            3,
            destination
        )
    )
    {
        return false;
    }

    bool destinationOk;

    scope auto writable =
        destination.tryWritableView(
            destinationOk
        );

    if (!destinationOk)
    {
        return false;
    }

    foreach (blockRegion; blocks)
    {
        const key =
            BlockKey(
                source.sourceId,
                source.generation,
                blockRegion,
                1
            );

        RasterLease!ubyte blockLease;

        if (
            !store.tryAcquire(
                key,
                blockLease
            )
        )
        {
            RasterLease!ubyte created;

            if (
                !materializeLease(
                    source,
                    blockRegion,
                    1,
                    created
                )
            )
            {
                return false;
            }

            if (
                !store.insertOwned(
                    key,
                    created
                )
                || !store.tryAcquire(
                    key,
                    blockLease
                )
            )
            {
                return false;
            }
        }

        if (
            !copyOverlapIntoRequest(
                blockRegion,
                blockLease,
                request,
                writable
            )
        )
        {
            return false;
        }

        /*
         * Release the transient acquired copy before processing the next block.
         */
        blockLease =
            RasterLease!ubyte.init;
    }

    return true;
}


private bool directMaterialize(
    ref BlockBackedSource source,
    Region2D request,
    out RasterLease!ubyte lease
)
@system
{
    return
        materializeLease(
            source,
            request,
            3,
            lease
        );
}


private bool equalRaster(
    ref RasterLease!ubyte lhs,
    ref RasterLease!ubyte rhs
)
@safe
{
    auto a = lhs.view();
    auto b = rhs.view();

    if (
        a.width != b.width
        || a.height != b.height
        || a.planeCount != b.planeCount
    )
    {
        return false;
    }

    foreach (y; 0 .. a.height)
    {
        foreach (x; 0 .. a.width)
        {
            ubyte av;
            ubyte bv;

            if (
                !a.trySample(0, x, y, av)
                || !b.trySample(0, x, y, bv)
                || av != bv
            )
            {
                return false;
            }
        }
    }

    return true;
}


bool runE92()
@system
{
    const extent =
        Region2D(
            0,
            0,
            96,
            80
        );

    const policy =
        BlockGridPolicy(
            12,
            10,
            extent.x,
            extent.y
        );

    BlockBackedSource source =
        BlockBackedSource(
            42,
            1,
            16,
            8,
            0
        );

    BlockBackedSource referenceSource =
        BlockBackedSource(
            42,
            1,
            7,
            5,
            0
        );

    ResearchRetainedStore!16 store;

    const first =
        Region2D(
            13,
            11,
            23,
            13
        );

    RasterLease!ubyte cold;
    RasterLease!ubyte directCold;

    assert(
        assembleRequest(
            store,
            source,
            extent,
            first,
            policy,
            cold
        )
    );

    assert(source.materializations == 4);
    assert(store.misses == 4);
    assert(store.hits == 4);

    assert(
        directMaterialize(
            referenceSource,
            first,
            directCold
        )
    );

    assert(
        equalRaster(
            cold,
            directCold
        )
    );

    const materializationsAfterCold =
        source.materializations;

    const hitsAfterCold =
        store.hits;

    const missesAfterCold =
        store.misses;

    RasterLease!ubyte warm;

    assert(
        assembleRequest(
            store,
            source,
            extent,
            first,
            policy,
            warm
        )
    );

    assert(
        source.materializations
        == materializationsAfterCold
    );

    assert(
        store.hits
        == hitsAfterCold + 4
    );

    assert(
        store.misses
        == missesAfterCold
    );

    assert(
        equalRaster(
            warm,
            directCold
        )
    );

    /*
     * This request is an already-expanded halo/dependency region.
     * It overlaps the four existing blocks and requires two new x=36 blocks.
     */
    const overlap =
        Region2D(
            20,
            16,
            21,
            11
        );

    const beforeOverlapHits =
        store.hits;

    const beforeOverlapMisses =
        store.misses;

    RasterLease!ubyte overlapAssembled;
    RasterLease!ubyte overlapDirect;

    assert(
        assembleRequest(
            store,
            source,
            extent,
            overlap,
            policy,
            overlapAssembled
        )
    );

    assert(
        source.materializations
        == materializationsAfterCold + 2
    );

    assert(
        store.hits
        == beforeOverlapHits + 6
    );

    assert(
        store.misses
        == beforeOverlapMisses + 2
    );

    assert(
        directMaterialize(
            referenceSource,
            overlap,
            overlapDirect
        )
    );

    assert(
        equalRaster(
            overlapAssembled,
            overlapDirect
        )
    );

    /*
     * Provider-native geometry differs between source and reference source
     * without changing the logical result.
     */
    assert(source.providerBlockWidth == 16);
    assert(source.providerBlockHeight == 8);
    assert(referenceSource.providerBlockWidth == 7);
    assert(referenceSource.providerBlockHeight == 5);

    return true;
}
