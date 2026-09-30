module raster.research.m2_neighbourhood_contract.candidate;

import raster.internal.affine_relation :
    affine2DMappingIsInjective;

import raster.region :
    Region2D;

import raster.view :
    RasterView;

import raster.writable_view :
    WritableRasterView;


enum Neighbourhood3x3Error : ubyte
{
    none,
    invalidSourcePlane,
    invalidDestinationPlane,
    destinationShapeMismatch,
    unsatisfiedNeighbourhood,
    nonInjectiveDestination,
    sourceDestinationOverlap
}


private
T invokeKernel(alias kernel, T)(
    ref const(T)[9] neighbourhood
)
@safe
pure
nothrow
@nogc
{
    return kernel(neighbourhood);
}


private
bool exactRectangularSampleBytesOverlap(T)(
    scope const(T)* sourceBase,
    ptrdiff_t sourceRowStride,
    ptrdiff_t sourceSampleStride,
    size_t sourceWidth,
    size_t sourceHeight,

    scope T* destinationBase,
    ptrdiff_t destinationRowStride,
    ptrdiff_t destinationSampleStride,
    size_t destinationWidth,
    size_t destinationHeight
)
@trusted
nothrow
@nogc
{
    assert(sourceBase !is null);
    assert(destinationBase !is null);

    auto sourceRow = sourceBase;

    foreach (sourceY; 0 .. sourceHeight)
    {
        auto sourceSample = sourceRow;

        foreach (sourceX; 0 .. sourceWidth)
        {
            const sourceAddress =
                cast(size_t) sourceSample;

            auto destinationRow =
                destinationBase;

            foreach (destinationY; 0 .. destinationHeight)
            {
                auto destinationSample =
                    destinationRow;

                foreach (destinationX; 0 .. destinationWidth)
                {
                    const destinationAddress =
                        cast(size_t) destinationSample;

                    const distance =
                        sourceAddress <= destinationAddress
                        ? destinationAddress - sourceAddress
                        : sourceAddress - destinationAddress;

                    if (distance < T.sizeof)
                        return true;

                    if (destinationX + 1 < destinationWidth)
                        destinationSample += destinationSampleStride;
                }

                if (destinationY + 1 < destinationHeight)
                    destinationRow += destinationRowStride;
            }

            if (sourceX + 1 < sourceWidth)
                sourceSample += sourceSampleStride;
        }

        if (sourceY + 1 < sourceHeight)
            sourceRow += sourceRowStride;
    }

    return false;
}


bool tryCandidateNeighbourhood3x3(alias kernel, T)(
    scope RasterView!T source,
    size_t sourcePlaneIndex,

    Region2D sourceOutputRegion,

    scope ref WritableRasterView!T destination,
    size_t destinationPlaneIndex,

    out Neighbourhood3x3Error error
)
@safe
nothrow
@nogc
{
    error = Neighbourhood3x3Error.none;

    ptrdiff_t sourceRowStride;
    ptrdiff_t sourceSampleStride;

    if (!source.tryExecutionPlaneStrides(
        sourcePlaneIndex,
        sourceRowStride,
        sourceSampleStride
    ))
    {
        error = Neighbourhood3x3Error.invalidSourcePlane;
        return false;
    }

    ptrdiff_t destinationRowStride;
    ptrdiff_t destinationSampleStride;

    if (!destination.tryExecutionPlaneStrides(
        destinationPlaneIndex,
        destinationRowStride,
        destinationSampleStride
    ))
    {
        error = Neighbourhood3x3Error.invalidDestinationPlane;
        return false;
    }

    if (
        destination.width != sourceOutputRegion.width
        || destination.height != sourceOutputRegion.height
    )
    {
        error = Neighbourhood3x3Error.destinationShapeMismatch;
        return false;
    }

    if (!source.region.containsRelative(sourceOutputRegion))
    {
        error = Neighbourhood3x3Error.unsatisfiedNeighbourhood;
        return false;
    }

    if (sourceOutputRegion.empty())
        return true;

    if (
        sourceOutputRegion.x == 0
        || sourceOutputRegion.y == 0
        || sourceOutputRegion.x >= source.width
        || sourceOutputRegion.y >= source.height
        || sourceOutputRegion.width > source.width - sourceOutputRegion.x
        || sourceOutputRegion.height > source.height - sourceOutputRegion.y
        || sourceOutputRegion.width == source.width - sourceOutputRegion.x
        || sourceOutputRegion.height == source.height - sourceOutputRegion.y
    )
    {
        error = Neighbourhood3x3Error.unsatisfiedNeighbourhood;
        return false;
    }

    if (!affine2DMappingIsInjective(
        destination.width,
        destination.height,
        destinationRowStride,
        destinationSampleStride
    ))
    {
        error = Neighbourhood3x3Error.nonInjectiveDestination;
        return false;
    }

    const requiredRelative =
        Region2D(
            sourceOutputRegion.x - 1,
            sourceOutputRegion.y - 1,
            sourceOutputRegion.width + 2,
            sourceOutputRegion.height + 2
        );

    bool roiOk;

    scope auto requiredSource =
        source.tryRoi(
            requiredRelative,
            roiOk
        );

    assert(roiOk);

    ptrdiff_t requiredSourceRowStride;
    ptrdiff_t requiredSourceSampleStride;

    assert(requiredSource.tryExecutionPlaneStrides(
        sourcePlaneIndex,
        requiredSourceRowStride,
        requiredSourceSampleStride
    ));

    const sourceBase =
        requiredSource.executionRegionBase(
            sourcePlaneIndex
        );

    auto destinationBase =
        destination.executionRegionBase(
            destinationPlaneIndex
        );

    assert(sourceBase !is null);
    assert(destinationBase !is null);

    if (exactRectangularSampleBytesOverlap(
        sourceBase,
        requiredSourceRowStride,
        requiredSourceSampleStride,
        requiredSource.width,
        requiredSource.height,

        destinationBase,
        destinationRowStride,
        destinationSampleStride,
        destination.width,
        destination.height
    ))
    {
        error = Neighbourhood3x3Error.sourceDestinationOverlap;
        return false;
    }

    foreach (y; 0 .. destination.height)
    {
        foreach (x; 0 .. destination.width)
        {
            T[9] values;
            size_t index;

            foreach (dy; 0 .. 3)
            {
                foreach (dx; 0 .. 3)
                {
                    const readOk =
                        source.trySample(
                            sourcePlaneIndex,
                            sourceOutputRegion.x + x + dx - 1,
                            sourceOutputRegion.y + y + dy - 1,
                            values[index]
                        );

                    assert(readOk);
                    ++index;
                }
            }

            const transformed =
                invokeKernel!kernel(values);

            const writeOk =
                destination.trySetSample(
                    destinationPlaneIndex,
                    x,
                    y,
                    transformed
                );

            assert(writeOk);
        }
    }

    return true;
}


import raster.descriptor : PlaneDescriptor;
import raster.resource : ResourceAccess, ResourceEntry;
import raster.validation :
    BackingValidationResult,
    WritableBackingCertificationResult;
import raster.view : makeRasterViewAssumeValidated;
import raster.writable_view : tryMakeWritableRasterView;


private
WritableRasterView!T makeWritable(T)(
    return scope const(ResourceEntry)[] resources,
    return scope const(PlaneDescriptor)[] descriptors,
    Region2D region
)
@safe
nothrow
@nogc
{
    BackingValidationResult validation;
    WritableBackingCertificationResult certification;

    auto result =
        tryMakeWritableRasterView!T(
            resources,
            descriptors,
            region,
            validation,
            certification
        );

    assert(validation.ok);
    assert(certification.ok);

    return result;
}


@safe
pure
nothrow
@nogc
private
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


@safe
pure
nothrow
@nogc
private
ubyte logicalValue(size_t x, size_t y)
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


@safe
pure
nothrow
@nogc
private
ubyte oracleAt(size_t centerX, size_t centerY)
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


private
void fillPositive(
    scope ubyte[] storage,
    size_t width,
    size_t height,
    size_t pitch,
    size_t sampleStride = 1
)
@safe
nothrow
@nogc
{
    foreach (y; 0 .. height)
        foreach (x; 0 .. width)
            storage[
                y * pitch
                + x * sampleStride
            ] = logicalValue(x, y);
}


bool runCandidateMatrix()
@system
{
    enum sourceWidth = 8;
    enum sourceHeight = 7;
    enum outputWidth = 6;
    enum outputHeight = 5;

    /*
     * Whole contiguous execution.
     */
    ubyte[sourceWidth * sourceHeight] sourceStorage;

    fillPositive(
        sourceStorage[],
        sourceWidth,
        sourceHeight,
        sourceWidth
    );

    ubyte[outputWidth * outputHeight] wholeStorage;

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr,
            sourceWidth,
            1
        )
    ];

    const PlaneDescriptor[1] wholeDescriptors =
    [
        PlaneDescriptor(
            wholeStorage.ptr,
            outputWidth,
            1
        )
    ];

    const ResourceEntry[1] wholeResources =
    [
        ResourceEntry(
            wholeStorage.ptr,
            wholeStorage.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(
            sourceDescriptors[],
            Region2D(0,0,sourceWidth,sourceHeight)
        );

    scope auto wholeDestination =
        makeWritable!ubyte(
            wholeResources[],
            wholeDescriptors[],
            Region2D(0,0,outputWidth,outputHeight)
        );

    Neighbourhood3x3Error error;

    assert(
        tryCandidateNeighbourhood3x3!weighted3x3(
            source,
            0,
            Region2D(1,1,outputWidth,outputHeight),
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
     * Padded Canonical source.
     */
    {
        enum pitch = 12;

        ubyte[pitch * sourceHeight] storage;
        ubyte[outputWidth * outputHeight] output;

        fillPositive(
            storage[],
            sourceWidth,
            sourceHeight,
            pitch
        );

        const PlaneDescriptor[1] srcDesc =
        [
            PlaneDescriptor(storage.ptr,pitch,1)
        ];

        const PlaneDescriptor[1] dstDesc =
        [
            PlaneDescriptor(output.ptr,outputWidth,1)
        ];

        const ResourceEntry[1] dstRes =
        [
            ResourceEntry(
                output.ptr,
                output.sizeof,
                null,
                null,
                ResourceAccess.readWrite
            )
        ];

        scope auto src =
            makeRasterViewAssumeValidated!ubyte(
                srcDesc[],
                Region2D(0,0,sourceWidth,sourceHeight)
            );

        scope auto dst =
            makeWritable!ubyte(
                dstRes[],
                dstDesc[],
                Region2D(0,0,outputWidth,outputHeight)
            );

        assert(
            tryCandidateNeighbourhood3x3!weighted3x3(
                src,
                0,
                Region2D(1,1,outputWidth,outputHeight),
                dst,
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
        ubyte[outputWidth * outputHeight] output;

        foreach (y;0..sourceHeight)
            foreach (x;0..sourceWidth)
                storage[
                    (sourceHeight - 1 - y) * pitch + x
                ] = logicalValue(x,y);

        const PlaneDescriptor[1] srcDesc =
        [
            PlaneDescriptor(
                storage.ptr + (sourceHeight - 1) * pitch,
                -cast(ptrdiff_t)pitch,
                1
            )
        ];

        const PlaneDescriptor[1] dstDesc =
        [
            PlaneDescriptor(output.ptr,outputWidth,1)
        ];

        const ResourceEntry[1] dstRes =
        [
            ResourceEntry(
                output.ptr,
                output.sizeof,
                null,
                null,
                ResourceAccess.readWrite
            )
        ];

        scope auto src =
            makeRasterViewAssumeValidated!ubyte(
                srcDesc[],
                Region2D(0,0,sourceWidth,sourceHeight)
            );

        scope auto dst =
            makeWritable!ubyte(
                dstRes[],
                dstDesc[],
                Region2D(0,0,outputWidth,outputHeight)
            );

        assert(
            tryCandidateNeighbourhood3x3!weighted3x3(
                src,
                0,
                Region2D(1,1,outputWidth,outputHeight),
                dst,
                0,
                error
            )
        );

        assert(output == wholeStorage);
    }


    /*
     * Universal/sample-strided source and signed-stride destination.
     */
    {
        enum sourcePitch = 20;
        enum sourceSampleStride = 2;
        enum destinationPitch = 8;

        ubyte[sourcePitch * sourceHeight] storage;
        ubyte[destinationPitch * outputHeight] output;

        fillPositive(
            storage[],
            sourceWidth,
            sourceHeight,
            sourcePitch,
            sourceSampleStride
        );

        const PlaneDescriptor[1] srcDesc =
        [
            PlaneDescriptor(
                storage.ptr,
                sourcePitch,
                sourceSampleStride
            )
        ];

        const PlaneDescriptor[1] dstDesc =
        [
            PlaneDescriptor(
                output.ptr + (outputHeight - 1) * destinationPitch,
                -cast(ptrdiff_t)destinationPitch,
                1
            )
        ];

        const ResourceEntry[1] dstRes =
        [
            ResourceEntry(
                output.ptr,
                output.sizeof,
                null,
                null,
                ResourceAccess.readWrite
            )
        ];

        scope auto src =
            makeRasterViewAssumeValidated!ubyte(
                srcDesc[],
                Region2D(0,0,sourceWidth,sourceHeight)
            );

        scope auto dst =
            makeWritable!ubyte(
                dstRes[],
                dstDesc[],
                Region2D(0,0,outputWidth,outputHeight)
            );

        assert(
            tryCandidateNeighbourhood3x3!weighted3x3(
                src,
                0,
                Region2D(1,1,outputWidth,outputHeight),
                dst,
                0,
                error
            )
        );

        foreach (y;0..outputHeight)
            foreach (x;0..outputWidth)
                assert(
                    output[
                        (outputHeight - 1 - y) * destinationPitch + x
                    ]
                    == wholeStorage[y * outputWidth + x]
                );
    }


    /*
     * Independently materialized task-local halos reproduce whole output.
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

        ubyte[outputWidth + 2][5] taskSourceStorage;
        ubyte[outputWidth * 3] taskDestinationStorage;

        foreach (ry;0..residentHeight)
            foreach (x;0..sourceWidth)
                taskSourceStorage[ry][x] =
                    logicalValue(x,outY + ry);

        const PlaneDescriptor[1] srcDesc =
        [
            PlaneDescriptor(
                taskSourceStorage.ptr,
                outputWidth + 2,
                1
            )
        ];

        const PlaneDescriptor[1] dstDesc =
        [
            PlaneDescriptor(
                taskDestinationStorage.ptr,
                outputWidth,
                1
            )
        ];

        const ResourceEntry[1] dstRes =
        [
            ResourceEntry(
                taskDestinationStorage.ptr,
                taskDestinationStorage.sizeof,
                null,
                null,
                ResourceAccess.readWrite
            )
        ];

        scope auto src =
            makeRasterViewAssumeValidated!ubyte(
                srcDesc[],
                Region2D(0,0,sourceWidth,residentHeight)
            );

        scope auto dst =
            makeWritable!ubyte(
                dstRes[],
                dstDesc[],
                Region2D(0,0,outputWidth,taskHeight)
            );

        assert(
            tryCandidateNeighbourhood3x3!weighted3x3(
                src,
                0,
                Region2D(1,1,outputWidth,taskHeight),
                dst,
                0,
                error
            )
        );

        foreach (y;0..taskHeight)
            foreach (x;0..outputWidth)
                streamedStorage[
                    (outY + y) * outputWidth + x
                ] =
                    taskDestinationStorage[
                        y * outputWidth + x
                    ];
    }

    assert(streamedStorage == wholeStorage);


    /*
     * Missing resident halo is rejected; no border semantics are invented.
     */
    {
        ubyte[9] srcStorage;
        ubyte[1] dstStorage = [91];

        const PlaneDescriptor[1] srcDesc =
        [
            PlaneDescriptor(srcStorage.ptr,3,1)
        ];

        const PlaneDescriptor[1] dstDesc =
        [
            PlaneDescriptor(dstStorage.ptr,1,1)
        ];

        const ResourceEntry[1] dstRes =
        [
            ResourceEntry(
                dstStorage.ptr,
                dstStorage.sizeof,
                null,
                null,
                ResourceAccess.readWrite
            )
        ];

        scope auto src =
            makeRasterViewAssumeValidated!ubyte(
                srcDesc[],
                Region2D(0,0,3,3)
            );

        scope auto dst =
            makeWritable!ubyte(
                dstRes[],
                dstDesc[],
                Region2D(0,0,1,1)
            );

        assert(
            !tryCandidateNeighbourhood3x3!weighted3x3(
                src,
                0,
                Region2D(0,0,1,1),
                dst,
                0,
                error
            )
        );

        assert(
            error
            == Neighbourhood3x3Error.unsatisfiedNeighbourhood
        );

        assert(dstStorage[0] == 91);
    }


    /*
     * Exact and shifted overlap are rejected before writing.
     */
    {
        ubyte[25] storage;

        foreach(i;0..storage.length)
            storage[i]=cast(ubyte)i;

        const auto original = storage;

        const PlaneDescriptor[1] srcDesc =
        [
            PlaneDescriptor(storage.ptr,5,1)
        ];

        const PlaneDescriptor[1] dstDesc =
        [
            PlaneDescriptor(storage.ptr + 6,3,1)
        ];

        const ResourceEntry[1] dstRes =
        [
            ResourceEntry(
                storage.ptr,
                storage.sizeof,
                null,
                null,
                ResourceAccess.readWrite
            )
        ];

        scope auto src =
            makeRasterViewAssumeValidated!ubyte(
                srcDesc[],
                Region2D(0,0,5,5)
            );

        scope auto dst =
            makeWritable!ubyte(
                dstRes[],
                dstDesc[],
                Region2D(0,0,3,3)
            );

        assert(
            !tryCandidateNeighbourhood3x3!weighted3x3(
                src,
                0,
                Region2D(1,1,3,3),
                dst,
                0,
                error
            )
        );

        assert(
            error
            == Neighbourhood3x3Error.sourceDestinationOverlap
        );

        assert(storage == original);
    }


    /*
     * Invalid source/destination planes and destination shape mismatch are
     * explicit and leave destination unchanged.
     */
    {
        ubyte[25] srcStorage;
        ubyte[4] dstStorage = [7,7,7,7];

        const PlaneDescriptor[1] srcDesc =
        [
            PlaneDescriptor(srcStorage.ptr,5,1)
        ];

        const PlaneDescriptor[1] dstDesc =
        [
            PlaneDescriptor(dstStorage.ptr,2,1)
        ];

        const ResourceEntry[1] dstRes =
        [
            ResourceEntry(
                dstStorage.ptr,
                dstStorage.sizeof,
                null,
                null,
                ResourceAccess.readWrite
            )
        ];

        scope auto src =
            makeRasterViewAssumeValidated!ubyte(
                srcDesc[],
                Region2D(0,0,5,5)
            );

        scope auto dst =
            makeWritable!ubyte(
                dstRes[],
                dstDesc[],
                Region2D(0,0,2,2)
            );

        assert(
            !tryCandidateNeighbourhood3x3!weighted3x3(
                src,
                1,
                Region2D(1,1,2,2),
                dst,
                0,
                error
            )
        );

        assert(
            error
            == Neighbourhood3x3Error.invalidSourcePlane
        );

        assert(
            !tryCandidateNeighbourhood3x3!weighted3x3(
                src,
                0,
                Region2D(1,1,2,2),
                dst,
                1,
                error
            )
        );

        assert(
            error
            == Neighbourhood3x3Error.invalidDestinationPlane
        );

        assert(
            !tryCandidateNeighbourhood3x3!weighted3x3(
                src,
                0,
                Region2D(1,1,1,2),
                dst,
                0,
                error
            )
        );

        assert(
            error
            == Neighbourhood3x3Error.destinationShapeMismatch
        );

        assert(dstStorage == [7,7,7,7]);
    }


    /*
     * A non-injective destination is rejected before the first write.
     */
    {
        ubyte[25] srcStorage;
        ubyte[1] dstStorage = [55];

        const PlaneDescriptor[1] srcDesc =
        [
            PlaneDescriptor(srcStorage.ptr,5,1)
        ];

        const PlaneDescriptor[1] dstDesc =
        [
            PlaneDescriptor(dstStorage.ptr,0,0)
        ];

        const ResourceEntry[1] dstRes =
        [
            ResourceEntry(
                dstStorage.ptr,
                dstStorage.sizeof,
                null,
                null,
                ResourceAccess.readWrite
            )
        ];

        scope auto src =
            makeRasterViewAssumeValidated!ubyte(
                srcDesc[],
                Region2D(0,0,5,5)
            );

        scope auto dst =
            makeWritable!ubyte(
                dstRes[],
                dstDesc[],
                Region2D(0,0,3,3)
            );

        assert(
            !tryCandidateNeighbourhood3x3!weighted3x3(
                src,
                0,
                Region2D(1,1,3,3),
                dst,
                0,
                error
            )
        );

        assert(
            error
            == Neighbourhood3x3Error.nonInjectiveDestination
        );

        assert(dstStorage[0] == 55);
    }


    /*
     * Matching empty output succeeds without context.
     */
    {
        ubyte[1] srcStorage;
        ubyte[1] dstStorage = [77];

        const PlaneDescriptor[1] srcDesc =
        [
            PlaneDescriptor(srcStorage.ptr,1,1)
        ];

        const PlaneDescriptor[1] dstDesc =
        [
            PlaneDescriptor(dstStorage.ptr,1,1)
        ];

        const ResourceEntry[1] dstRes =
        [
            ResourceEntry(
                dstStorage.ptr,
                dstStorage.sizeof,
                null,
                null,
                ResourceAccess.readWrite
            )
        ];

        scope auto src =
            makeRasterViewAssumeValidated!ubyte(
                srcDesc[],
                Region2D(0,0,1,1)
            );

        scope auto dst =
            makeWritable!ubyte(
                dstRes[],
                dstDesc[],
                Region2D(0,0,0,0)
            );

        assert(
            tryCandidateNeighbourhood3x3!weighted3x3(
                src,
                0,
                Region2D(0,0,0,0),
                dst,
                0,
                error
            )
        );

        assert(dstStorage[0] == 77);
    }


    return true;
}
