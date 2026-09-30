module e7_3_geometry_reuse;

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


private ubyte proceduralValue(
    size_t logicalX,
    size_t logicalY
)
@safe
pure
nothrow
@nogc
{
    return cast(ubyte)(
        cast(ubyte) logicalX
        ^ cast(ubyte) logicalY
        ^ cast(ubyte) (logicalY >> 8)
    );
}


private struct BlockBackedSource
{
    Region2D logicalExtent;
    size_t providerBlockWidth;
    size_t providerBlockHeight;
    size_t materializations;


    bool materializeInto(
        Region2D logicalRegion,
        scope WritableRasterView!ubyte destination
    )
    @safe
    nothrow
    @nogc
    {
        if (
            providerBlockWidth == 0
            || providerBlockHeight == 0
            || destination.width != logicalRegion.width
            || destination.height != logicalRegion.height
            || destination.planeCount != 1
            || logicalRegion.x < logicalExtent.x
            || logicalRegion.y < logicalExtent.y
            || logicalRegion.width
                > logicalExtent.width
            || logicalRegion.height
                > logicalExtent.height
            || logicalRegion.x - logicalExtent.x
                > logicalExtent.width - logicalRegion.width
            || logicalRegion.y - logicalExtent.y
                > logicalExtent.height - logicalRegion.height
        )
        {
            return false;
        }

        foreach (y; 0 .. logicalRegion.height)
        {
            foreach (x; 0 .. logicalRegion.width)
            {
                const logicalX =
                    logicalRegion.x + x;

                const logicalY =
                    logicalRegion.y + y;

                /*
                 * Provider-native block geometry is deliberately used only
                 * inside the source. The caller supplies an arbitrary logical
                 * region and never observes these block coordinates.
                 */
                const providerBlockX =
                    logicalX / providerBlockWidth;

                const providerBlockY =
                    logicalY / providerBlockHeight;

                const inProviderX =
                    logicalX % providerBlockWidth;

                const inProviderY =
                    logicalY % providerBlockHeight;

                const reconstructedX =
                    providerBlockX
                    * providerBlockWidth
                    + inProviderX;

                const reconstructedY =
                    providerBlockY
                    * providerBlockHeight
                    + inProviderY;

                if (
                    !destination.trySetSample(
                        0,
                        x,
                        y,
                        proceduralValue(
                            reconstructedX,
                            reconstructedY
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


private struct CacheKey
{
    size_t sourceId;
    Region2D logicalRegion;
    size_t schemaId;
}


private struct CacheEntry
{
    bool occupied;
    CacheKey key;
    size_t physicalBytes;
    RasterLease!ubyte lease;
}


private bool makeWritableBlock(
    Region2D logicalRegion,
    out RasterLease!ubyte lease,
    out size_t physicalBytes
)
@system
{
    lease = RasterLease!ubyte.init;
    physicalBytes = 0;

    if (
        logicalRegion.empty()
        || logicalRegion.width
            == size_t.max
    )
    {
        return false;
    }

    const rowStride =
        logicalRegion.width + 1;

    if (
        rowStride > cast(size_t) ptrdiff_t.max
        || logicalRegion.height
            > size_t.max / rowStride
    )
    {
        return false;
    }

    physicalBytes =
        rowStride * logicalRegion.height;

    auto memory =
        malloc(physicalBytes);

    if (memory is null)
    {
        physicalBytes = 0;
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
        physicalBytes = 0;
        return false;
    }

    const importResult =
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

    if (!importResult.ok)
    {
        physicalBytes = 0;
        return false;
    }

    return true;
}


private struct GeometryCache(size_t SlotCount)
{
    size_t budgetBytes;
    size_t retainedCacheBytes;
    size_t hits;
    size_t misses;
    CacheEntry[SlotCount] entries;


    private bool acquire(
        CacheKey key,
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


    private ptrdiff_t freeSlot() const
    {
        foreach (i, ref const entry; entries)
        {
            if (!entry.occupied)
            {
                return cast(ptrdiff_t) i;
            }
        }

        return -1;
    }


    bool acquireOrMaterialize(
        size_t sourceId,
        size_t schemaId,
        Region2D cacheBlockRegion,
        ref BlockBackedSource source,
        out RasterLease!ubyte lease
    )
    @system
    {
        const key =
            CacheKey(
                sourceId,
                cacheBlockRegion,
                schemaId
            );

        if (acquire(key, lease))
        {
            return true;
        }

        RasterLease!ubyte created;
        size_t physicalBytes;

        if (
            !makeWritableBlock(
                cacheBlockRegion,
                created,
                physicalBytes
            )
        )
        {
            return false;
        }

        bool writableOk;

        scope auto writable =
            created.tryWritableView(
                writableOk
            );

        if (
            !writableOk
            || !source.materializeInto(
                cacheBlockRegion,
                writable
            )
        )
        {
            return false;
        }

        if (
            physicalBytes > budgetBytes
            || retainedCacheBytes
                > budgetBytes - physicalBytes
        )
        {
            return false;
        }

        const slot =
            freeSlot();

        if (slot < 0)
        {
            return false;
        }

        const index =
            cast(size_t) slot;

        entries[index].occupied = true;
        entries[index].key = key;
        entries[index].physicalBytes =
            physicalBytes;
        entries[index].lease =
            move(created);

        retainedCacheBytes +=
            physicalBytes;

        lease =
            entries[index].lease;

        return true;
    }
}


private size_t minSize(
    size_t a,
    size_t b
)
@safe
pure
nothrow
@nogc
{
    return a < b ? a : b;
}


private size_t maxSize(
    size_t a,
    size_t b
)
@safe
pure
nothrow
@nogc
{
    return a > b ? a : b;
}


private bool assembleRegion(
    ref GeometryCache!16 cache,
    ref BlockBackedSource source,
    Region2D request,
    ubyte[] output
)
@system
{
    enum size_t cacheBlockWidth = 12;
    enum size_t cacheBlockHeight = 10;

    if (
        request.empty()
        || request.width
            > size_t.max / request.height
        || output.length
            != request.width * request.height
    )
    {
        return false;
    }

    const requestEndX =
        request.x + request.width;

    const requestEndY =
        request.y + request.height;

    const firstBlockX =
        (request.x / cacheBlockWidth)
        * cacheBlockWidth;

    const firstBlockY =
        (request.y / cacheBlockHeight)
        * cacheBlockHeight;

    for (
        size_t blockY = firstBlockY;
        blockY < requestEndY;
        blockY += cacheBlockHeight
    )
    {
        for (
            size_t blockX = firstBlockX;
            blockX < requestEndX;
            blockX += cacheBlockWidth
        )
        {
            const cacheRegion =
                Region2D(
                    blockX,
                    blockY,
                    cacheBlockWidth,
                    cacheBlockHeight
                );

            RasterLease!ubyte lease;

            if (
                !cache.acquireOrMaterialize(
                    42,
                    1,
                    cacheRegion,
                    source,
                    lease
                )
            )
            {
                return false;
            }

            auto view =
                lease.view();

            const copyStartX =
                maxSize(
                    request.x,
                    cacheRegion.x
                );

            const copyStartY =
                maxSize(
                    request.y,
                    cacheRegion.y
                );

            const copyEndX =
                minSize(
                    requestEndX,
                    cacheRegion.x
                        + cacheRegion.width
                );

            const copyEndY =
                minSize(
                    requestEndY,
                    cacheRegion.y
                        + cacheRegion.height
                );

            foreach (
                logicalY;
                copyStartY .. copyEndY
            )
            {
                foreach (
                    logicalX;
                    copyStartX .. copyEndX
                )
                {
                    ubyte value;

                    if (
                        !view.trySample(
                            0,
                            logicalX - cacheRegion.x,
                            logicalY - cacheRegion.y,
                            value
                        )
                    )
                    {
                        return false;
                    }

                    output[
                        (logicalY - request.y)
                            * request.width
                        + (logicalX - request.x)
                    ] =
                        value;
                }
            }
        }
    }

    return true;
}


private bool verifyOutput(
    Region2D request,
    const(ubyte)[] output
)
@safe
{
    if (
        output.length
        != request.width * request.height
    )
    {
        return false;
    }

    foreach (y; 0 .. request.height)
    {
        foreach (x; 0 .. request.width)
        {
            if (
                output[
                    y * request.width + x
                ]
                != proceduralValue(
                    request.x + x,
                    request.y + y
                )
            )
            {
                return false;
            }
        }
    }

    return true;
}


bool runE73()
@system
{
    /*
     * Logical source extent is aligned to neither provider nor request
     * semantics merely because the experiment uses fixed fixture dimensions.
     */
    BlockBackedSource source =
        BlockBackedSource(
            Region2D(
                0,
                0,
                96,
                80
            ),
            16,
            8,
            0
        );

    GeometryCache!16 cache;
    cache.budgetBytes = 2_000;

    /*
     * Request 1 is unaligned to:
     *
     * - provider blocks 16 x 8;
     * - cache blocks    12 x 10.
     *
     * It requires exactly four cache blocks:
     * (12,10), (24,10), (12,20), (24,20).
     */
    const request1 =
        Region2D(
            13,
            11,
            23,
            13
        );

    auto output1 =
        new ubyte[
            request1.width
            * request1.height
        ];

    assert(
        assembleRegion(
            cache,
            source,
            request1,
            output1
        )
    );

    assert(
        verifyOutput(
            request1,
            output1
        )
    );

    assert(source.materializations == 4);
    assert(cache.misses == 4);
    assert(cache.hits == 0);

    /*
     * Request 2 models an already-expanded halo/dependency request around a
     * smaller output. Its region overlaps all four blocks from request 1 and
     * needs two new blocks at x=36.
     *
     * Therefore the second assembly should add:
     *
     *     hits   = 4
     *     misses = 2
     */
    const output2 =
        Region2D(
            21,
            17,
            19,
            9
        );

    const dependency2 =
        Region2D(
            output2.x - 1,
            output2.y - 1,
            output2.width + 2,
            output2.height + 2
        );

    auto dependencyBuffer =
        new ubyte[
            dependency2.width
            * dependency2.height
        ];

    assert(
        assembleRegion(
            cache,
            source,
            dependency2,
            dependencyBuffer
        )
    );

    assert(
        verifyOutput(
            dependency2,
            dependencyBuffer
        )
    );

    assert(source.materializations == 6);
    assert(cache.misses == 6);
    assert(cache.hits == 4);

    /*
     * The provider's 16 x 8 geometry never appears in CacheKey and never
     * determines the request or cache-block dimensions.
     */
    static assert(
        16 != 12
        && 8 != 10
    );

    /*
     * Six cache blocks, each with padded resident rows:
     *
     * physical bytes = (12 + 1) * 10 = 130
     * total cache ownership = 780
     */
    assert(cache.retainedCacheBytes == 780);

    return true;
}
