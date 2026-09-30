module e8_4_retained_identity_integration;

import core.stdc.stdlib : malloc;
import std.algorithm.mutation : move;

import raster :
    OwnedByteResource,
    PlaneByteLayout,
    RasterLease,
    Region2D,
    tryAdoptMallocResource,
    tryImportOwnedRaster;


/++
    Caller-owned semantic key used only by this experiment.

    raster-d cache mechanics do not define these fields.
+/
private struct SemanticKey
{
    size_t sourceSemanticId;

    size_t generation;

    Region2D logicalRegion;

    size_t schemaId;
}


private struct RetainedEntry
{
    bool occupied;

    SemanticKey key;

    RasterLease!ubyte lease;
}


private struct RetainedIdentityCache(size_t SlotCount)
{
    RetainedEntry[SlotCount] entries;

    size_t hits;

    size_t misses;


    bool tryAcquire(
        ref const SemanticKey key,
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
                /*
                 * RasterLease copy retains the same backing.
                 */
                lease = entry.lease;
                ++hits;
                return true;
            }
        }

        ++misses;
        return false;
    }


    bool insertOwned(
        SemanticKey key,
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


private struct ProceduralSource
{
    /*
     * Object identity is deliberately separate from semantic identity.
     */
    size_t objectInstanceId;

    size_t semanticBehaviorId;

    size_t generation;

    size_t providerBlockWidth;

    size_t providerBlockHeight;

    size_t materializations;


    SemanticKey semanticKey(
        Region2D region,
        size_t schemaId
    ) const
    @safe
    pure
    nothrow
    @nogc
    {
        return
            SemanticKey(
                semanticBehaviorId,
                generation,
                region,
                schemaId
            );
    }


    ubyte sample(
        size_t logicalX,
        size_t logicalY
    ) const
    @safe
    pure
    nothrow
    @nogc
    {
        /*
         * Provider blocks are intentionally part of source-local mechanics.
         * Reconstructing the coordinates through them proves that different
         * provider geometry can serve the same logical semantic value.
         */
        const blockX =
            logicalX / providerBlockWidth;

        const blockY =
            logicalY / providerBlockHeight;

        const inBlockX =
            logicalX % providerBlockWidth;

        const inBlockY =
            logicalY % providerBlockHeight;

        const reconstructedX =
            blockX * providerBlockWidth + inBlockX;

        const reconstructedY =
            blockY * providerBlockHeight + inBlockY;

        return
            cast(ubyte)(
                cast(ubyte) reconstructedX
                ^ cast(ubyte) reconstructedY
                ^ cast(ubyte) semanticBehaviorId
                ^ cast(ubyte) generation
            );
    }
}


private bool makeScalarLease(
    ref ProceduralSource source,
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

    const physicalBytes =
        logicalRegion.height
        * rowStride;

    auto memory =
        cast(ubyte*) malloc(
            physicalBytes
        );

    if (memory is null)
    {
        return false;
    }

    foreach (y; 0 .. logicalRegion.height)
    {
        foreach (x; 0 .. logicalRegion.width)
        {
            memory[
                y * rowStride + x
            ] =
                source.sample(
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
        return false;
    }

    ++source.materializations;
    return true;
}


private bool verifyScalarLease(
    ref RasterLease!ubyte lease,
    ref const ProceduralSource source,
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
                != source.sample(
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


private ubyte scientificU(
    size_t x,
    size_t y,
    size_t generation
)
@safe
pure
nothrow
@nogc
{
    return
        cast(ubyte)(
            cast(ubyte) (x * 3)
            + cast(ubyte) y
            + cast(ubyte) generation
        );
}


private ubyte scientificV(
    size_t x,
    size_t y,
    size_t generation
)
@safe
pure
nothrow
@nogc
{
    return
        cast(ubyte)(
            cast(ubyte) x
            ^ cast(ubyte) (y * 5)
            ^ cast(ubyte) generation
        );
}


private bool makeScientificLease(
    Region2D logicalRegion,
    size_t generation,
    size_t rowPaddingBytes,
    out RasterLease!ubyte lease
)
@system
{
    lease = RasterLease!ubyte.init;

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

    const physicalBytes =
        logicalRegion.height
        * rowStride;

    auto memory =
        cast(ubyte*) malloc(
            physicalBytes
        );

    if (memory is null)
    {
        return false;
    }

    foreach (y; 0 .. logicalRegion.height)
    {
        foreach (x; 0 .. logicalRegion.width)
        {
            const offset =
                y * rowStride
                + x * 2;

            const logicalX =
                logicalRegion.x + x;

            const logicalY =
                logicalRegion.y + y;

            memory[offset] =
                scientificU(
                    logicalX,
                    logicalY,
                    generation
                );

            memory[offset + 1] =
                scientificV(
                    logicalX,
                    logicalY,
                    generation
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

    return result.ok;
}


private bool verifyScientificLease(
    ref RasterLease!ubyte lease,
    Region2D logicalRegion,
    size_t generation
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
                u != scientificU(
                    logicalX,
                    logicalY,
                    generation
                )
                || v != scientificV(
                    logicalX,
                    logicalY,
                    generation
                )
            )
            {
                return false;
            }
        }
    }

    return true;
}


private bool runEquivalentSourceReuse()
@system
{
    RetainedIdentityCache!8 cache;

    ProceduralSource sourceA =
        ProceduralSource(
            1001,
            77,
            4,
            16,
            8,
            0
        );

    /*
     * Different source object instance and different provider block geometry,
     * but deliberately identical semantic behavior/generation.
     */
    ProceduralSource sourceB =
        ProceduralSource(
            2002,
            77,
            4,
            7,
            5,
            0
        );

    const region =
        Region2D(
            13,
            11,
            23,
            13
        );

    const keyA =
        sourceA.semanticKey(
            region,
            1
        );

    const keyB =
        sourceB.semanticKey(
            region,
            1
        );

    assert(keyA == keyB);

    RasterLease!ubyte created;

    assert(
        makeScalarLease(
            sourceA,
            region,
            9,
            created
        )
    );

    assert(sourceA.materializations == 1);

    assert(
        cache.insertOwned(
            keyA,
            created
        )
    );

    RasterLease!ubyte reused;

    assert(
        cache.tryAcquire(
            keyB,
            reused
        )
    );

    assert(cache.hits == 1);
    assert(sourceB.materializations == 0);

    /*
     * Source B can consume the retained value even though its provider-native
     * block geometry differs from Source A.
     */
    assert(
        verifyScalarLease(
            reused,
            sourceB,
            region
        )
    );

    return true;
}


private bool runDifferentBehaviorNoFalseHit()
@system
{
    RetainedIdentityCache!8 cache;

    ProceduralSource sourceA =
        ProceduralSource(
            1,
            10,
            2,
            16,
            8,
            0
        );

    ProceduralSource sourceB =
        ProceduralSource(
            2,
            11,
            2,
            16,
            8,
            0
        );

    const region =
        Region2D(
            50,
            60,
            12,
            10
        );

    const keyA =
        sourceA.semanticKey(
            region,
            1
        );

    const keyB =
        sourceB.semanticKey(
            region,
            1
        );

    assert(keyA != keyB);

    RasterLease!ubyte created;

    assert(
        makeScalarLease(
            sourceA,
            region,
            0,
            created
        )
    );

    assert(
        cache.insertOwned(
            keyA,
            created
        )
    );

    RasterLease!ubyte wrong;

    assert(
        !cache.tryAcquire(
            keyB,
            wrong
        )
    );

    assert(cache.misses == 1);

    return true;
}


private bool runMutableGenerationInvalidation()
@system
{
    RetainedIdentityCache!8 cache;

    ProceduralSource source =
        ProceduralSource(
            88,
            33,
            7,
            16,
            8,
            0
        );

    const region =
        Region2D(
            400,
            500,
            10,
            8
        );

    const oldKey =
        source.semanticKey(
            region,
            1
        );

    RasterLease!ubyte oldLease;

    assert(
        makeScalarLease(
            source,
            region,
            3,
            oldLease
        )
    );

    assert(
        cache.insertOwned(
            oldKey,
            oldLease
        )
    );

    /*
     * Source content changes. Identity invalidation is expressed only by the
     * caller-owned generation component.
     */
    ++source.generation;

    const newKey =
        source.semanticKey(
            region,
            1
        );

    assert(oldKey != newKey);

    RasterLease!ubyte stale;

    assert(
        !cache.tryAcquire(
            newKey,
            stale
        )
    );

    RasterLease!ubyte newLease;

    assert(
        makeScalarLease(
            source,
            region,
            7,
            newLease
        )
    );

    assert(
        cache.insertOwned(
            newKey,
            newLease
        )
    );

    RasterLease!ubyte current;

    assert(
        cache.tryAcquire(
            newKey,
            current
        )
    );

    assert(
        verifyScalarLease(
            current,
            source,
            region
        )
    );

    return true;
}


private bool runExternalLeaseLifetime()
@system
{
    RetainedIdentityCache!2 cache;

    ProceduralSource source =
        ProceduralSource(
            9,
            90,
            1,
            16,
            8,
            0
        );

    const region =
        Region2D(
            700,
            800,
            9,
            6
        );

    const key =
        source.semanticKey(
            region,
            1
        );

    RasterLease!ubyte created;

    assert(
        makeScalarLease(
            source,
            region,
            4,
            created
        )
    );

    assert(
        cache.insertOwned(
            key,
            created
        )
    );

    RasterLease!ubyte external;

    assert(
        cache.tryAcquire(
            key,
            external
        )
    );

    /*
     * Destroy the entire cache storage while the copied external lease remains.
     */
    cache =
        RetainedIdentityCache!2.init;

    assert(
        verifyScalarLease(
            external,
            source,
            region
        )
    );

    return true;
}


private bool runScientificMultiPlaneReuse()
@system
{
    RetainedIdentityCache!4 cache;

    const region =
        Region2D(
            size_t.max - 10_000,
            size_t.max - 20_000,
            11,
            5
        );

    enum size_t scientificDatasetId = 5_001;
    enum size_t generation = 12;
    enum size_t uvSchemaId = 44;
    enum size_t temperatureSchemaId = 45;

    const uvKey =
        SemanticKey(
            scientificDatasetId,
            generation,
            region,
            uvSchemaId
        );

    RasterLease!ubyte uvLease;

    assert(
        makeScientificLease(
            region,
            generation,
            7,
            uvLease
        )
    );

    assert(
        cache.insertOwned(
            uvKey,
            uvLease
        )
    );

    RasterLease!ubyte acquired;

    assert(
        cache.tryAcquire(
            uvKey,
            acquired
        )
    );

    assert(
        verifyScientificLease(
            acquired,
            region,
            generation
        )
    );

    const incompatibleSchema =
        SemanticKey(
            scientificDatasetId,
            generation,
            region,
            temperatureSchemaId
        );

    RasterLease!ubyte wrong;

    assert(
        !cache.tryAcquire(
            incompatibleSchema,
            wrong
        )
    );

    return true;
}


bool runE84()
@system
{
    return
        runEquivalentSourceReuse()
        && runDifferentBehaviorNoFalseHit()
        && runMutableGenerationInvalidation()
        && runExternalLeaseLifetime()
        && runScientificMultiPlaneReuse();
}
