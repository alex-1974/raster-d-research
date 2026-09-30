module app;

import core.stdc.stdlib : malloc;

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
        ^ cast(ubyte) (logicalY >> 8)
        ^ cast(ubyte) (logicalY)
    );
}


struct ProceduralUbyteSource
{
    bool materializeInto(
        Region2D logicalRegion,
        scope WritableRasterView!ubyte destination
    )
    @safe
    pure
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
                const value =
                    proceduralValue(
                        logicalRegion.x + x,
                        logicalRegion.y + y
                    );

                if (
                    !destination.trySetSample(
                        0,
                        x,
                        y,
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
}


private bool makeWritableResident(
    size_t width,
    size_t height,
    size_t rowStrideBytes,
    out RasterLease!ubyte lease
)
@system
{
    lease = RasterLease!ubyte.init;

    if (
        width == 0
        || height == 0
        || rowStrideBytes < width
    )
    {
        return false;
    }

    if (
        height > size_t.max / rowStrideBytes
    )
    {
        return false;
    }

    const byteLength =
        height * rowStrideBytes;

    auto memory =
        malloc(byteLength);

    if (memory is null)
    {
        return false;
    }

    OwnedByteResource resource;

    if (
        !tryAdoptMallocResource(
            memory,
            byteLength,
            resource
        )
    )
    {
        return false;
    }

    const importResult =
        tryImportOwnedRaster!ubyte(
            resource,
            [
                PlaneByteLayout(
                    0,
                    cast(ptrdiff_t) rowStrideBytes,
                    1
                )
            ],
            Region2D(
                0,
                0,
                width,
                height
            ),
            lease
        );

    return importResult.ok;
}


private bool verifyResident(
    scope ref RasterLease!ubyte lease,
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

            const expected =
                proceduralValue(
                    logicalRegion.x + x,
                    logicalRegion.y + y
                );

            if (actual != expected)
            {
                return false;
            }
        }
    }

    return true;
}


private bool runContiguousCase()
@system
{
    const logicalRegion =
        Region2D(
            1_000_000,
            2_000_000,
            17,
            9
        );

    RasterLease!ubyte lease;

    if (
        !makeWritableResident(
            logicalRegion.width,
            logicalRegion.height,
            logicalRegion.width,
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

    if (!writableOk)
    {
        return false;
    }

    ProceduralUbyteSource source;

    if (
        !source.materializeInto(
            logicalRegion,
            writable
        )
    )
    {
        return false;
    }

    return verifyResident(
        lease,
        logicalRegion
    );
}


private bool runPaddedCase()
@system
{
    const logicalRegion =
        Region2D(
            size_t.max - 1000,
            size_t.max - 2000,
            13,
            7
        );

    enum size_t rowPadding = 11;

    RasterLease!ubyte lease;

    if (
        !makeWritableResident(
            logicalRegion.width,
            logicalRegion.height,
            logicalRegion.width + rowPadding,
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

    if (!writableOk)
    {
        return false;
    }

    ProceduralUbyteSource source;

    if (
        !source.materializeInto(
            logicalRegion,
            writable
        )
    )
    {
        return false;
    }

    return verifyResident(
        lease,
        logicalRegion
    );
}


void main()
{
    assert(runContiguousCase());
    assert(runPaddedCase());

    import std.stdio : writeln;

    writeln(
        "R0.6 Prototype A PASS: caller-owned contiguous and padded materialization"
    );
}
