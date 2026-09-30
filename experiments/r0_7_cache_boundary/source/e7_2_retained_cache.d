module e7_2_retained_cache;

import core.stdc.stdlib : malloc;
import std.algorithm.mutation : move;

import raster :
    OwnedByteResource,
    PlaneByteLayout,
    RasterLease,
    Region2D,
    tryAdoptMallocResource,
    tryImportOwnedRaster;


private struct RetainedCacheKey
{
    size_t sourceId;
    Region2D logicalRegion;
    size_t schemaId;
}


private struct RetainedCacheEntry
{
    bool occupied;
    RetainedCacheKey key;
    size_t physicalBytes;
    ulong lastUse;
    RasterLease!ubyte lease;
}


private struct RetainedRasterCache(size_t SlotCount)
{
    size_t budgetBytes;
    size_t retainedCacheBytes;
    ulong clock;
    size_t hits;
    size_t misses;
    size_t evictions;
    RetainedCacheEntry[SlotCount] entries;


    bool acquire(
        RetainedCacheKey key,
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
                ++clock;
                entry.lastUse = clock;
                lease = entry.lease;
                ++hits;
                return true;
            }
        }

        ++misses;
        return false;
    }


    private ptrdiff_t findFreeSlot() const
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


    private ptrdiff_t findEvictionVictim() const
    {
        ptrdiff_t victim = -1;
        ulong oldestUse = ulong.max;

        foreach (i, ref const entry; entries)
        {
            if (
                entry.occupied
                && (
                    victim < 0
                    || entry.lastUse < oldestUse
                )
            )
            {
                victim = cast(ptrdiff_t) i;
                oldestUse = entry.lastUse;
            }
        }

        return victim;
    }


    private bool evictOne()
    {
        const victim = findEvictionVictim();

        if (victim < 0)
        {
            return false;
        }

        const index = cast(size_t) victim;

        assert(entries[index].occupied);
        assert(
            retainedCacheBytes
            >= entries[index].physicalBytes
        );

        retainedCacheBytes -=
            entries[index].physicalBytes;

        /*
         * Dropping the cache's RasterLease releases only the cache's retained
         * reference. Independent copied leases may continue to retain the same
         * RasterBacking.
         */
        entries[index].lease =
            RasterLease!ubyte.init;

        entries[index] =
            RetainedCacheEntry.init;

        ++evictions;
        return true;
    }


    bool insertOwned(
        RetainedCacheKey key,
        size_t physicalBytes,
        ref RasterLease!ubyte lease
    )
    {
        if (
            physicalBytes > budgetBytes
            || physicalBytes > size_t.max - retainedCacheBytes
        )
        {
            return false;
        }

        RasterLease!ubyte existing;

        if (acquireWithoutStats(key, existing))
        {
            return false;
        }

        while (
            retainedCacheBytes
            > budgetBytes - physicalBytes
        )
        {
            if (!evictOne())
            {
                return false;
            }
        }

        ptrdiff_t slot =
            findFreeSlot();

        if (slot < 0)
        {
            if (!evictOne())
            {
                return false;
            }

            slot =
                findFreeSlot();
        }

        assert(slot >= 0);

        const index =
            cast(size_t) slot;

        ++clock;

        entries[index].occupied = true;
        entries[index].key = key;
        entries[index].physicalBytes =
            physicalBytes;
        entries[index].lastUse = clock;
        entries[index].lease =
            move(lease);

        retainedCacheBytes +=
            physicalBytes;

        assert(
            retainedCacheBytes
            <= budgetBytes
        );

        return true;
    }


    private bool acquireWithoutStats(
        RetainedCacheKey key,
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
                return true;
            }
        }

        return false;
    }


    bool contains(
        RetainedCacheKey key
    )
    {
        RasterLease!ubyte lease;

        return acquireWithoutStats(
            key,
            lease
        );
    }
}


private ubyte scalarValue(
    size_t x,
    size_t y
)
@safe
pure
nothrow
@nogc
{
    return cast(ubyte)(
        cast(ubyte) x
        ^ cast(ubyte) y
        ^ cast(ubyte) (y >> 8)
    );
}


private bool makeScalarLease(
    Region2D logicalRegion,
    size_t rowPaddingBytes,
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
            > size_t.max - rowPaddingBytes
    )
    {
        return false;
    }

    const rowStride =
        logicalRegion.width
        + rowPaddingBytes;

    if (
        rowStride > cast(size_t) ptrdiff_t.max
        || logicalRegion.height
            > size_t.max / rowStride
    )
    {
        return false;
    }

    physicalBytes =
        logicalRegion.height
        * rowStride;

    auto memory =
        cast(ubyte*) malloc(
            physicalBytes
        );

    if (memory is null)
    {
        physicalBytes = 0;
        return false;
    }

    foreach (y; 0 .. logicalRegion.height)
    {
        foreach (x; 0 .. logicalRegion.width)
        {
            memory[
                y * rowStride + x
            ] =
                scalarValue(
                    logicalRegion.x + x,
                    logicalRegion.y + y
                );
        }
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

    if (!result.ok)
    {
        physicalBytes = 0;
        return false;
    }

    return true;
}


private bool verifyScalarLease(
    ref RasterLease!ubyte lease,
    Region2D logicalRegion
)
@safe
{
    auto view =
        lease.view();

    if (
        view.width != logicalRegion.width
        || view.height != logicalRegion.height
        || view.planeCount != 1
    )
    {
        return false;
    }

    foreach (y; 0 .. logicalRegion.height)
    {
        foreach (x; 0 .. logicalRegion.width)
        {
            ubyte actual;

            if (
                !view.trySample(
                    0,
                    x,
                    y,
                    actual
                )
            )
            {
                return false;
            }

            if (
                actual
                != scalarValue(
                    logicalRegion.x + x,
                    logicalRegion.y + y
                )
            )
            {
                return false;
            }
        }
    }

    return true;
}


private ubyte vectorU(
    size_t x,
    size_t y
)
@safe
pure
nothrow
@nogc
{
    return cast(ubyte)(
        cast(ubyte) (x * 3)
        + cast(ubyte) y
    );
}


private ubyte vectorV(
    size_t x,
    size_t y
)
@safe
pure
nothrow
@nogc
{
    return cast(ubyte)(
        cast(ubyte) x
        ^ cast(ubyte) (y * 5)
    );
}


private bool makeInterleavedVectorLease(
    Region2D logicalRegion,
    size_t rowPaddingBytes,
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
            > (size_t.max - rowPaddingBytes) / 2
    )
    {
        return false;
    }

    const rowStride =
        logicalRegion.width * 2
        + rowPaddingBytes;

    if (
        rowStride > cast(size_t) ptrdiff_t.max
        || logicalRegion.height
            > size_t.max / rowStride
    )
    {
        return false;
    }

    physicalBytes =
        logicalRegion.height
        * rowStride;

    auto memory =
        cast(ubyte*) malloc(
            physicalBytes
        );

    if (memory is null)
    {
        physicalBytes = 0;
        return false;
    }

    foreach (y; 0 .. logicalRegion.height)
    {
        foreach (x; 0 .. logicalRegion.width)
        {
            const offset =
                y * rowStride
                + x * 2;

            memory[offset] =
                vectorU(
                    logicalRegion.x + x,
                    logicalRegion.y + y
                );

            memory[offset + 1] =
                vectorV(
                    logicalRegion.x + x,
                    logicalRegion.y + y
                );
        }
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

    const result =
        tryImportOwnedRaster!ubyte(
            resource,
            [
                PlaneByteLayout(
                    0,
                    cast(ptrdiff_t) rowStride,
                    2
                ),
                PlaneByteLayout(
                    1,
                    cast(ptrdiff_t) rowStride,
                    2
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

    if (!result.ok)
    {
        physicalBytes = 0;
        return false;
    }

    return true;
}


private bool verifyVectorLease(
    ref RasterLease!ubyte lease,
    Region2D logicalRegion
)
@safe
{
    auto view =
        lease.view();

    if (
        view.width != logicalRegion.width
        || view.height != logicalRegion.height
        || view.planeCount != 2
    )
    {
        return false;
    }

    foreach (y; 0 .. logicalRegion.height)
    {
        foreach (x; 0 .. logicalRegion.width)
        {
            ubyte u;
            ubyte v;

            if (
                !view.trySample(
                    0,
                    x,
                    y,
                    u
                )
                || !view.trySample(
                    1,
                    x,
                    y,
                    v
                )
            )
            {
                return false;
            }

            const logicalX =
                logicalRegion.x + x;

            const logicalY =
                logicalRegion.y + y;

            if (
                u != vectorU(
                    logicalX,
                    logicalY
                )
                || v != vectorV(
                    logicalX,
                    logicalY
                )
            )
            {
                return false;
            }
        }
    }

    return true;
}


private RetainedCacheKey cacheKey(
    size_t sourceId,
    Region2D logicalRegion,
    size_t schemaId
)
{
    return RetainedCacheKey(
        sourceId,
        logicalRegion,
        schemaId
    );
}


private bool runExternalLeaseSurvivesEviction()
@system
{
    RetainedRasterCache!3 cache;
    cache.budgetBytes = 192;

    const regionA =
        Region2D(
            1_000_000,
            2_000_000,
            10,
            8
        );

    const regionB =
        Region2D(
            1_000_010,
            2_000_000,
            10,
            8
        );

    const regionC =
        Region2D(
            1_000_020,
            2_000_000,
            10,
            8
        );

    const keyA =
        cacheKey(1, regionA, 1);

    const keyB =
        cacheKey(1, regionB, 1);

    const keyC =
        cacheKey(1, regionC, 1);

    RasterLease!ubyte leaseA;
    RasterLease!ubyte leaseB;
    RasterLease!ubyte leaseC;

    size_t bytesA;
    size_t bytesB;
    size_t bytesC;

    assert(
        makeScalarLease(
            regionA,
            2,
            leaseA,
            bytesA
        )
    );

    assert(
        makeScalarLease(
            regionB,
            2,
            leaseB,
            bytesB
        )
    );

    assert(
        makeScalarLease(
            regionC,
            2,
            leaseC,
            bytesC
        )
    );

    assert(bytesA == 96);
    assert(bytesB == 96);
    assert(bytesC == 96);

    assert(
        cache.insertOwned(
            keyA,
            bytesA,
            leaseA
        )
    );

    RasterLease!ubyte externalA;

    assert(
        cache.acquire(
            keyA,
            externalA
        )
    );

    assert(
        cache.insertOwned(
            keyB,
            bytesB,
            leaseB
        )
    );

    /*
     * Touch B after A so A becomes the cache eviction victim.
     */
    RasterLease!ubyte temporaryB;

    assert(
        cache.acquire(
            keyB,
            temporaryB
        )
    );

    temporaryB =
        RasterLease!ubyte.init;

    assert(
        cache.insertOwned(
            keyC,
            bytesC,
            leaseC
        )
    );

    assert(!cache.contains(keyA));
    assert(cache.contains(keyB));
    assert(cache.contains(keyC));
    assert(cache.evictions == 1);

    /*
     * Cache accounting is now exactly B + C. A has been evicted from the
     * cache, but the copied external lease intentionally keeps A's physical
     * backing alive.
     */
    assert(cache.retainedCacheBytes == 192);

    assert(
        verifyScalarLease(
            externalA,
            regionA
        )
    );

    /*
     * Important semantic result:
     *
     * strict cache bytes are not the same quantity as total process-resident
     * bytes while independent RasterLease copies exist.
     */
    const knownExternallyRetainedBytes =
        bytesA;

    assert(
        cache.retainedCacheBytes
        + knownExternallyRetainedBytes
        == 288
    );

    externalA =
        RasterLease!ubyte.init;

    return true;
}


private bool runPhysicalResourceAccounting()
@system
{
    RetainedRasterCache!2 cache;
    cache.budgetBytes = 256;

    const logicalRegion =
        Region2D(
            size_t.max - 10_000,
            size_t.max - 20_000,
            11,
            5
        );

    RasterLease!ubyte lease;
    size_t physicalBytes;

    assert(
        makeInterleavedVectorLease(
            logicalRegion,
            7,
            lease,
            physicalBytes
        )
    );

    /*
     * One physical interleaved allocation:
     *
     * rowStride = 11 * 2 + 7 = 29
     * bytes     = 29 * 5     = 145
     *
     * Two logical planes must not double-count this physical resource.
     */
    assert(physicalBytes == 145);

    const key =
        cacheKey(
            8,
            logicalRegion,
            2
        );

    assert(
        cache.insertOwned(
            key,
            physicalBytes,
            lease
        )
    );

    assert(
        cache.retainedCacheBytes
        == 145
    );

    RasterLease!ubyte acquired;

    assert(
        cache.acquire(
            key,
            acquired
        )
    );

    assert(
        verifyVectorLease(
            acquired,
            logicalRegion
        )
    );

    return true;
}


private bool runLeaseDoesNotExposeByteCost()
@system
{
    /*
     * The public RasterLease capability intentionally exposes retained
     * lifetime and views, not physical-resource byte accounting.
     *
     * E7.2 therefore carries the materializer-known physical byte count next
     * to the lease in research-local cache metadata.
     *
     * This is a research finding: a future production cache cannot derive
     * truthful physical-byte cost from RasterLease alone through the current
     * public surface.
     */
    const logicalRegion =
        Region2D(
            50,
            70,
            9,
            4
        );

    RasterLease!ubyte lease;
    size_t physicalBytes;

    assert(
        makeScalarLease(
            logicalRegion,
            3,
            lease,
            physicalBytes
        )
    );

    assert(physicalBytes == 48);

    return verifyScalarLease(
        lease,
        logicalRegion
    );
}


bool runE72()
@system
{
    return
        runExternalLeaseSurvivesEviction()
        && runPhysicalResourceAccounting()
        && runLeaseDoesNotExposeByteCost();
}
