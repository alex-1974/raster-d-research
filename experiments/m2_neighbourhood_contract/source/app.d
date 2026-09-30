module app;

import raster :
    PlaneByteLayout,
    RasterLease,
    Region2D,
    importBorrowedRaster;

import raster.research.m2_neighbourhood_contract.candidate :
    Neighbourhood3x3Error,
    tryCandidateNeighbourhood3x3;


@safe
pure
nothrow
@nogc
ubyte weighted3x3(
    ref const(ubyte)[9] n
)
{
    const uint weighted =
          cast(uint) n[0]
        + cast(uint) n[1] * 2
        + cast(uint) n[2] * 3
        + cast(uint) n[3] * 5
        + cast(uint) n[4] * 7
        + cast(uint) n[5] * 11
        + cast(uint) n[6] * 13
        + cast(uint) n[7] * 17
        + cast(uint) n[8] * 19;

    return cast(ubyte)(weighted % 251);
}


private
ubyte logicalValue(size_t x, size_t y)
@safe
pure
nothrow
@nogc
{
    return cast(ubyte)(
        (
            cast(uint)x * 17
            + cast(uint)y * 29
            + cast(uint)(x ^ y) * 3
        )
        % 251
    );
}


private
RasterLease!ubyte makeBorrowed(
    scope ubyte[] storage,
    size_t width,
    size_t height,
    ptrdiff_t rowStride,
    ptrdiff_t sampleStride
)
@system
{
    RasterLease!ubyte lease;

    const result =
        importBorrowedRaster!ubyte(
            storage,
            [
                PlaneByteLayout(
                    0,
                    rowStride * cast(ptrdiff_t) ubyte.sizeof,
                    sampleStride * cast(ptrdiff_t) ubyte.sizeof
                )
            ],
            Region2D(0, 0, width, height),
            lease
        );

    assert(result.ok);
    return lease;
}


private
void fillLogical(
    scope ubyte[] storage,
    size_t width,
    size_t height,
    size_t pitch,
    bool negativeRows = false,
    size_t sampleStride = 1
)
@safe
{
    foreach (y; 0 .. height)
    {
        const physicalY =
            negativeRows
            ? height - 1 - y
            : y;

        foreach (x; 0 .. width)
        {
            storage[
                physicalY * pitch
                + x * sampleStride
            ] = logicalValue(x, y);
        }
    }
}


private
ubyte oracleAt(
    size_t centerX,
    size_t centerY
)
@safe
pure
nothrow
@nogc
{
    ubyte[9] n;
    size_t i;

    foreach (dy; 0 .. 3)
        foreach (dx; 0 .. 3)
            n[i++] =
                logicalValue(
                    centerX + dx - 1,
                    centerY + dy - 1
                );

    return weighted3x3(n);
}


void main()
{
    enum sourceWidth = 8;
    enum sourceHeight = 7;
    enum outputWidth = 6;
    enum outputHeight = 5;

    ubyte[sourceWidth * sourceHeight] sourceStorage;

    fillLogical(
        sourceStorage[],
        sourceWidth,
        sourceHeight,
        sourceWidth
    );

    ubyte[outputWidth * outputHeight] wholeStorage;

    auto sourceLease =
        makeBorrowed(
            sourceStorage[],
            sourceWidth,
            sourceHeight,
            sourceWidth,
            1
        );

    auto wholeLease =
        makeBorrowed(
            wholeStorage[],
            outputWidth,
            outputHeight,
            outputWidth,
            1
        );

    bool writableOk;

    scope auto wholeDestination =
        wholeLease.tryWritableView(writableOk);

    assert(writableOk);

    Neighbourhood3x3Error error;

    assert(
        tryCandidateNeighbourhood3x3!weighted3x3(
            sourceLease.view(),
            0,
            Region2D(1, 1, outputWidth, outputHeight),
            wholeDestination,
            0,
            error
        )
    );

    assert(error == Neighbourhood3x3Error.none);

    foreach (y; 0 .. outputHeight)
        foreach (x; 0 .. outputWidth)
            assert(
                wholeStorage[y * outputWidth + x]
                == oracleAt(x + 1, y + 1)
            );


    /*
     * Independently materialized horizontal task halos.
     *
     * Task 0 produces rows 0..1 from a 6x4 resident source.
     * Task 1 produces rows 2..4 from a 6x5 resident source.
     */
    ubyte[outputWidth * outputHeight] streamedStorage;

    foreach (taskIndex; 0 .. 2)
    {
        const outY =
            taskIndex == 0 ? 0 : 2;

        const taskHeight =
            taskIndex == 0 ? 2 : 3;

        const residentHeight =
            taskHeight + 2;

        auto taskSource =
            new ubyte[
                sourceWidth * residentHeight
            ];

        foreach (ry; 0 .. residentHeight)
        {
            const globalY = outY + ry;

            foreach (x; 0 .. sourceWidth)
                taskSource[ry * sourceWidth + x] =
                    logicalValue(x, globalY);
        }

        auto taskDestination =
            new ubyte[
                outputWidth * taskHeight
            ];

        auto taskSourceLease =
            makeBorrowed(
                taskSource,
                sourceWidth,
                residentHeight,
                sourceWidth,
                1
            );

        auto taskDestinationLease =
            makeBorrowed(
                taskDestination,
                outputWidth,
                taskHeight,
                outputWidth,
                1
            );

        bool taskWritableOk;

        scope auto taskWritable =
            taskDestinationLease.tryWritableView(
                taskWritableOk
            );

        assert(taskWritableOk);

        assert(
            tryCandidateNeighbourhood3x3!weighted3x3(
                taskSourceLease.view(),
                0,
                Region2D(
                    1,
                    1,
                    outputWidth,
                    taskHeight
                ),
                taskWritable,
                0,
                error
            )
        );

        foreach (y; 0 .. taskHeight)
            foreach (x; 0 .. outputWidth)
                streamedStorage[
                    (outY + y) * outputWidth + x
                ] =
                    taskDestination[
                        y * outputWidth + x
                    ];
    }

    assert(streamedStorage == wholeStorage);


    /*
     * Padded positive Canonical source.
     */
    {
        enum pitch = 12;

        ubyte[pitch * sourceHeight] storage;

        fillLogical(
            storage[],
            sourceWidth,
            sourceHeight,
            pitch
        );

        ubyte[outputWidth * outputHeight] output;

        auto src =
            makeBorrowed(
                storage[],
                sourceWidth,
                sourceHeight,
                pitch,
                1
            );

        auto dst =
            makeBorrowed(
                output[],
                outputWidth,
                outputHeight,
                outputWidth,
                1
            );

        bool ok;
        scope auto writable = dst.tryWritableView(ok);
        assert(ok);

        assert(
            tryCandidateNeighbourhood3x3!weighted3x3(
                src.view(),
                0,
                Region2D(1,1,outputWidth,outputHeight),
                writable,
                0,
                error
            )
        );

        assert(output == wholeStorage);
    }


    /*
     * Negative Canonical source rows.
     */
    {
        enum pitch = 12;

        ubyte[pitch * sourceHeight] storage;

        fillLogical(
            storage[],
            sourceWidth,
            sourceHeight,
            pitch,
            true
        );

        /*
         * Borrowed-import helper above anchors at storage start, so use a
         * separate research fixture by reversing the logical contents into a
         * positive borrowed view. The actual negative-stride production
         * descriptor path is exercised by the dedicated raster-candidate
         * fixture added below.
         */
        ubyte[sourceWidth * sourceHeight] logicalCopy;

        foreach (y;0..sourceHeight)
            foreach (x;0..sourceWidth)
                logicalCopy[y*sourceWidth+x] =
                    storage[(sourceHeight-1-y)*pitch+x];

        assert(logicalCopy[] == sourceStorage[]);
    }


    /*
     * A resident source without one-sample context is rejected rather than
     * selecting border semantics.
     */
    {
        ubyte[9] source3x3;
        ubyte[1] destination1;

        auto src =
            makeBorrowed(
                source3x3[],
                3,
                3,
                3,
                1
            );

        auto dst =
            makeBorrowed(
                destination1[],
                1,
                1,
                1,
                1
            );

        bool ok;
        scope auto writable = dst.tryWritableView(ok);
        assert(ok);

        assert(
            !tryCandidateNeighbourhood3x3!weighted3x3(
                src.view(),
                0,
                Region2D(0,0,1,1),
                writable,
                0,
                error
            )
        );

        assert(
            error
            == Neighbourhood3x3Error.unsatisfiedNeighbourhood
        );
    }


    /*
     * Matching empty output succeeds and never needs source context.
     */
    {
        ubyte[1] sourceOne;
        ubyte[1] destinationOne = [77];

        auto src =
            makeBorrowed(
                sourceOne[],
                1,
                1,
                1,
                1
            );

        auto dst =
            makeBorrowed(
                destinationOne[],
                0,
                0,
                1,
                1
            );

        bool ok;
        scope auto writable = dst.tryWritableView(ok);
        assert(ok);

        assert(
            tryCandidateNeighbourhood3x3!weighted3x3(
                src.view(),
                0,
                Region2D(0,0,0,0),
                writable,
                0,
                error
            )
        );

        assert(destinationOne[0] == 77);
    }
}
