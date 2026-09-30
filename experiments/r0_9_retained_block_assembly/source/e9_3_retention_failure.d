module e9_3_retention_failure;

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


private enum InsertResult : ubyte
{
    inserted,
    duplicate,
    byteBudgetExceeded,
    capacityExceeded
}


private struct BlockKey
{
    Region2D region;
}


private struct Entry
{
    bool occupied;
    BlockKey key;
    size_t physicalBytes;
    RasterLease!ubyte lease;
}


private struct LimitedStore(size_t Capacity)
{
    size_t byteLimit;
    size_t retainedBytes;
    size_t entryCount;
    size_t hits;
    size_t misses;
    size_t byteRejects;
    size_t capacityRejects;
    Entry[Capacity] entries;


    bool tryAcquire(
        ref const BlockKey key,
        out RasterLease!ubyte lease
    )
    {
        lease = RasterLease!ubyte.init;

        foreach (ref entry; entries)
        {
            if (entry.occupied && entry.key == key)
            {
                lease = entry.lease;
                ++hits;
                return true;
            }
        }

        ++misses;
        return false;
    }


    InsertResult insertOwned(
        BlockKey key,
        size_t physicalBytes,
        ref RasterLease!ubyte lease
    )
    {
        foreach (ref entry; entries)
        {
            if (entry.occupied && entry.key == key)
            {
                return InsertResult.duplicate;
            }
        }

        if (
            physicalBytes > byteLimit
            || retainedBytes > byteLimit - physicalBytes
        )
        {
            ++byteRejects;
            return InsertResult.byteBudgetExceeded;
        }

        foreach (ref entry; entries)
        {
            if (!entry.occupied)
            {
                entry.occupied = true;
                entry.key = key;
                entry.physicalBytes = physicalBytes;
                entry.lease = move(lease);

                retainedBytes += physicalBytes;
                ++entryCount;

                return InsertResult.inserted;
            }
        }

        ++capacityRejects;
        return InsertResult.capacityExceeded;
    }
}


private struct Source
{
    size_t materializations;


    ubyte expected(size_t x, size_t y) const
    @safe pure nothrow @nogc
    {
        return cast(ubyte)(
            cast(ubyte) x
            ^ cast(ubyte) y
            ^ cast(ubyte) (y >> 8)
        );
    }


    bool materializeInto(
        Region2D logicalRegion,
        scope WritableRasterView!ubyte destination
    )
    @safe nothrow @nogc
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


private bool makeLease(
    ref Source source,
    Region2D region,
    size_t padding,
    out RasterLease!ubyte lease,
    out size_t physicalBytes
)
@system
{
    lease = RasterLease!ubyte.init;
    physicalBytes = 0;

    if (
        region.empty()
        || region.width > size_t.max - padding
    )
    {
        return false;
    }

    const rowStride =
        region.width + padding;

    if (
        region.height > size_t.max / rowStride
    )
    {
        return false;
    }

    physicalBytes =
        rowStride * region.height;

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

    const imported =
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
                region.width,
                region.height
            ),
            lease
        );

    if (!imported.ok)
    {
        return false;
    }

    bool writableOk;

    scope auto writable =
        lease.tryWritableView(writableOk);

    return
        writableOk
        && source.materializeInto(
            region,
            writable
        );
}


private bool makeDestination(
    Region2D request,
    out RasterLease!ubyte destination
)
@system
{
    Source unused;
    size_t bytes;

    /*
     * Allocate through the same retained construction path, then overwrite
     * every requested sample during assembly.
     */
    return makeLease(
        unused,
        request,
        2,
        destination,
        bytes
    );
}


private bool copyBlock(
    Region2D block,
    ref RasterLease!ubyte lease,
    Region2D request,
    scope WritableRasterView!ubyte destination
)
@safe
{
    auto view = lease.view();

    const blockEndX = block.x + block.width;
    const blockEndY = block.y + block.height;
    const requestEndX = request.x + request.width;
    const requestEndY = request.y + request.height;

    const startX = block.x > request.x ? block.x : request.x;
    const startY = block.y > request.y ? block.y : request.y;
    const endX = blockEndX < requestEndX ? blockEndX : requestEndX;
    const endY = blockEndY < requestEndY ? blockEndY : requestEndY;

    foreach (y; startY .. endY)
    {
        foreach (x; startX .. endX)
        {
            ubyte value;

            if (
                !view.trySample(
                    0,
                    x - block.x,
                    y - block.y,
                    value
                )
                || !destination.trySetSample(
                    0,
                    x - request.x,
                    y - request.y,
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


private bool verify(
    ref RasterLease!ubyte destination,
    ref const Source source,
    Region2D request
)
@safe
{
    auto view = destination.view();

    foreach (y; 0 .. request.height)
    {
        foreach (x; 0 .. request.width)
        {
            ubyte actual;

            if (
                !view.trySample(0, x, y, actual)
                || actual
                    != source.expected(
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


private void fourBlocks(
    Region2D request,
    ref Region2D[4] blocks
)
@safe pure nothrow @nogc
{
    /*
     * Fixture deliberately matches the four 12 x 10 cache blocks covering
     * request (13,11,23,13) on a zero-anchored grid.
     */
    blocks[0] = Region2D(12, 10, 12, 10);
    blocks[1] = Region2D(24, 10, 12, 10);
    blocks[2] = Region2D(12, 20, 12, 10);
    blocks[3] = Region2D(24, 20, 12, 10);

    assert(request == Region2D(13, 11, 23, 13));
}


private bool assemble(
    size_t Capacity
)(
    ref LimitedStore!Capacity store,
    ref Source source,
    Region2D request,
    out RasterLease!ubyte destination
)
@system
{
    if (!makeDestination(request, destination))
    {
        return false;
    }

    bool writableOk;
    scope auto writable =
        destination.tryWritableView(writableOk);

    if (!writableOk)
    {
        return false;
    }

    Region2D[4] blocks;
    fourBlocks(request, blocks);

    foreach (block; blocks)
    {
        const key = BlockKey(block);

        RasterLease!ubyte acquired;

        if (store.tryAcquire(key, acquired))
        {
            if (
                !copyBlock(
                    block,
                    acquired,
                    request,
                    writable
                )
            )
            {
                return false;
            }

            continue;
        }

        RasterLease!ubyte created;
        size_t physicalBytes;

        if (
            !makeLease(
                source,
                block,
                1,
                created,
                physicalBytes
            )
        )
        {
            return false;
        }

        /*
         * Keep a transient retained copy before attempting store ownership.
         *
         * If store insertion succeeds, the original moves into the store and
         * transient remains available for this request.
         *
         * If insertion fails, original still owns the same backing and the
         * transient copy remains equally valid.
         */
        RasterLease!ubyte transient =
            created;

        const insertResult =
            store.insertOwned(
                key,
                physicalBytes,
                created
            );

        assert(
            insertResult == InsertResult.inserted
            || insertResult == InsertResult.byteBudgetExceeded
            || insertResult == InsertResult.capacityExceeded
        );

        if (
            !copyBlock(
                block,
                transient,
                request,
                writable
            )
        )
        {
            return false;
        }

        transient =
            RasterLease!ubyte.init;
    }

    return true;
}


private bool runByteBudgetFailure()
@system
{
    enum size_t oneBlockBytes =
        (12 + 1) * 10;

    LimitedStore!8 store;
    store.byteLimit = oneBlockBytes;

    Source source;

    const request =
        Region2D(13, 11, 23, 13);

    RasterLease!ubyte first;

    assert(
        assemble(
            store,
            source,
            request,
            first
        )
    );

    assert(verify(first, source, request));

    assert(store.entryCount == 1);
    assert(store.retainedBytes == oneBlockBytes);
    assert(store.byteRejects == 3);
    assert(store.capacityRejects == 0);
    assert(source.materializations == 4);

    const retainedBytesBefore =
        store.retainedBytes;

    RasterLease!ubyte second;

    assert(
        assemble(
            store,
            source,
            request,
            second
        )
    );

    assert(verify(second, source, request));

    /*
     * One retained block hits; the other three are rematerialized because
     * their previous retention failed.
     */
    assert(source.materializations == 7);
    assert(store.retainedBytes == retainedBytesBefore);
    assert(store.entryCount == 1);
    assert(store.byteRejects == 6);

    return true;
}


private bool runCapacityFailure()
@system
{
    LimitedStore!1 store;
    store.byteLimit = size_t.max;

    Source source;

    const request =
        Region2D(13, 11, 23, 13);

    RasterLease!ubyte first;

    assert(
        assemble(
            store,
            source,
            request,
            first
        )
    );

    assert(verify(first, source, request));

    assert(store.entryCount == 1);
    assert(store.capacityRejects == 3);
    assert(store.byteRejects == 0);
    assert(source.materializations == 4);

    RasterLease!ubyte second;

    assert(
        assemble(
            store,
            source,
            request,
            second
        )
    );

    assert(verify(second, source, request));

    assert(source.materializations == 7);
    assert(store.entryCount == 1);
    assert(store.capacityRejects == 6);

    return true;
}


bool runE93()
@system
{
    return
        runByteBudgetFailure()
        && runCapacityFailure();
}
