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
