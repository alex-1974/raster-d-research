module e7_4_failure_admission;

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


private ubyte valueAt(size_t x, size_t y)
@safe pure nothrow @nogc
{
    return cast(ubyte)(
        cast(ubyte) x
        + cast(ubyte) (y * 3)
    );
}


private struct FailableSource
{
    bool failNext;
    size_t calls;


    bool materializeInto(
        Region2D logicalRegion,
        scope WritableRasterView!ubyte destination
    )
    @safe nothrow @nogc
    {
        ++calls;

        if (failNext)
        {
            failNext = false;
            return false;
        }

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
                        valueAt(
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

        return true;
    }
}


private bool makeLease(
    Region2D region,
    out RasterLease!ubyte lease,
    out size_t physicalBytes
)
@system
{
    lease = RasterLease!ubyte.init;
    physicalBytes = 0;

    if (region.empty())
    {
        return false;
    }

    if (
        region.width > cast(size_t) ptrdiff_t.max
        || region.height > size_t.max / region.width
    )
    {
        return false;
    }

    physicalBytes =
        region.width * region.height;

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

    const result =
        tryImportOwnedRaster!ubyte(
            resource,
            [
                PlaneByteLayout(
                    0,
                    cast(ptrdiff_t) region.width,
                    1
                )
            ],
            Region2D(
                0,
                0,
                region.width,
                region.height
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


private struct Entry
{
    bool occupied;
    Region2D logicalRegion;
    size_t physicalBytes;
    RasterLease!ubyte lease;
}


private struct FailureCache
{
    size_t budgetBytes;
    size_t retainedCacheBytes;
    size_t hits;
    size_t misses;
    Entry[4] entries;


    bool contains(Region2D region)
    {
        foreach (ref entry; entries)
        {
            if (
                entry.occupied
                && entry.logicalRegion == region
            )
            {
                return true;
            }
        }

        return false;
    }


    bool acquire(
        Region2D region,
        out RasterLease!ubyte lease
    )
    {
        lease = RasterLease!ubyte.init;

        foreach (ref entry; entries)
        {
            if (
                entry.occupied
                && entry.logicalRegion == region
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


    bool materializeAndInsert(
        Region2D region,
        ref FailableSource source
    )
    @system
    {
        RasterLease!ubyte existing;

        if (acquire(region, existing))
        {
            return true;
        }

        RasterLease!ubyte candidate;
        size_t physicalBytes;

        if (
            !makeLease(
                region,
                candidate,
                physicalBytes
            )
        )
        {
            return false;
        }

        bool writableOk;

        scope auto writable =
            candidate.tryWritableView(
                writableOk
            );

        if (
            !writableOk
            || !source.materializeInto(
                region,
                writable
            )
        )
        {
            /*
             * Candidate remains local and is never published into cache state.
             * Its lease destructor owns cleanup.
             */
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

        foreach (ref entry; entries)
        {
            if (!entry.occupied)
            {
                entry.occupied = true;
                entry.logicalRegion = region;
                entry.physicalBytes =
                    physicalBytes;
                entry.lease =
                    move(candidate);

                retainedCacheBytes +=
                    physicalBytes;

                return true;
            }
        }

        return false;
    }
}


private bool verifyLease(
    ref RasterLease!ubyte lease,
    Region2D region
)
@safe
{
    auto view =
        lease.view();

    if (
        view.width != region.width
        || view.height != region.height
    )
    {
        return false;
    }

    foreach (y; 0 .. region.height)
    {
        foreach (x; 0 .. region.width)
        {
            ubyte actual;

            if (
                !view.trySample(
                    0,
                    x,
                    y,
                    actual
                )
                || actual
                    != valueAt(
                        region.x + x,
                        region.y + y
                    )
            )
            {
                return false;
            }
        }
    }

    return true;
}


private bool materializeRequest(
    Region2D request,
    ref FailureCache cache,
    ref FailableSource source
)
@system
{
    /*
     * Empty logical requests are valid zero-work requests.
     *
     * They do not create cache identity, allocate resident storage or call the
     * source.
     */
    if (request.empty())
    {
        return true;
    }

    return cache.materializeAndInsert(
        request,
        source
    );
}


private struct ResidencyAdmission
{
    size_t budgetBytes;
    size_t admittedBytes;


    bool tryAdmit(size_t requiredBytes)
    @safe pure nothrow @nogc
    {
        if (
            requiredBytes > budgetBytes
            || admittedBytes
                > budgetBytes - requiredBytes
        )
        {
            return false;
        }

        admittedBytes += requiredBytes;
        return true;
    }


    void release(size_t bytes)
    @safe pure nothrow @nogc
    {
        assert(admittedBytes >= bytes);
        admittedBytes -= bytes;
    }
}


private bool runEmptyRequestCase()
@system
{
    FailureCache cache;
    cache.budgetBytes = 256;

    FailableSource source;

    assert(
        materializeRequest(
            Region2D(
                77,
                88,
                0,
                0
            ),
            cache,
            source
        )
    );

    assert(source.calls == 0);
    assert(cache.retainedCacheBytes == 0);
    assert(cache.hits == 0);
    assert(cache.misses == 0);

    return true;
}


private bool runFailurePreservesCacheCase()
@system
{
    FailureCache cache;
    cache.budgetBytes = 256;

    FailableSource source;

    const stable =
        Region2D(
            100,
            200,
            8,
            8
        );

    assert(
        cache.materializeAndInsert(
            stable,
            source
        )
    );

    assert(source.calls == 1);
    assert(cache.retainedCacheBytes == 64);
    assert(cache.contains(stable));

    RasterLease!ubyte stableLease;

    assert(
        cache.acquire(
            stable,
            stableLease
        )
    );

    assert(
        verifyLease(
            stableLease,
            stable
        )
    );

    const beforeBytes =
        cache.retainedCacheBytes;

    const beforeHits =
        cache.hits;

    const failing =
        Region2D(
            108,
            200,
            8,
            8
        );

    source.failNext = true;

    assert(
        !cache.materializeAndInsert(
            failing,
            source
        )
    );

    assert(source.calls == 2);

    /*
     * The failed candidate was never committed.
     */
    assert(!cache.contains(failing));

    /*
     * Existing cache state remains unchanged and readable.
     */
    assert(cache.contains(stable));
    assert(cache.retainedCacheBytes == beforeBytes);
    assert(cache.hits == beforeHits);

    RasterLease!ubyte afterFailure;

    assert(
        cache.acquire(
            stable,
            afterFailure
        )
    );

    assert(
        verifyLease(
            afterFailure,
            stable
        )
    );

    return true;
}


private bool runSeparateAdmissionCase()
@safe
{
    /*
     * E7.2 established that cache ownership and total residency are different
     * accounting domains. E7.4 therefore models request admission separately.
     *
     * Imagine a request that minimally needs three resident 96-byte blocks
     * simultaneously for one operation.
     */
    enum size_t blockBytes = 96;
    enum size_t requiredBlocks = 3;
    enum size_t minimumWorkingSet =
        blockBytes * requiredBlocks;

    ResidencyAdmission admission;
    admission.budgetBytes = 256;

    assert(minimumWorkingSet == 288);

    assert(
        !admission.tryAdmit(
            minimumWorkingSet
        )
    );

    assert(admission.admittedBytes == 0);

    /*
     * A smaller two-block request fits and can later release its admission.
     */
    assert(
        admission.tryAdmit(
            blockBytes * 2
        )
    );

    assert(admission.admittedBytes == 192);

    admission.release(
        blockBytes * 2
    );

    assert(admission.admittedBytes == 0);

    return true;
}


private bool runCacheBudgetIsNotAdmissionCase()
@safe
{
    /*
     * A cache may legally retain less than the request working set. Conversely,
     * cached entries can remain alive outside cache ownership through copied
     * RasterLease values.
     *
     * Therefore cache budget and request-residency admission must not be
     * represented by one counter.
     */
    enum size_t cacheBudget = 128;
    enum size_t requestResidencyBudget = 256;

    static assert(
        cacheBudget
        != requestResidencyBudget
    );

    ResidencyAdmission admission;
    admission.budgetBytes =
        requestResidencyBudget;

    assert(admission.tryAdmit(192));
    admission.release(192);

    return true;
}


bool runE74()
@system
{
    return
        runEmptyRequestCase()
        && runFailurePreservesCacheCase()
        && runSeparateAdmissionCase()
        && runCacheBudgetIsNotAdmissionCase();
}
