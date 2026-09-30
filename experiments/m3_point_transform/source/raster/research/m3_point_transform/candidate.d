module raster.research.m3_point_transform.candidate;

import core.time : MonoTime;

import raster :
    RasterTransformError,
    Region2D,
    tryTransformRasterPlane;

import raster.descriptor : PlaneDescriptor;
import raster.internal.affine_relation :
    AffineByteOverlapRelation,
    affine2DMappingIsInjective,
    classifySameTypeAffine2DByteOverlap;
import raster.internal.physical_range :
    PhysicalByteRangeRelation,
    classifyByteAddressRanges;
import raster.resource : ResourceAccess, ResourceEntry;
import raster.validation :
    BackingValidationResult,
    WritableBackingCertificationResult;
import raster.view :
    RasterView,
    makeRasterViewAssumeValidated;
import raster.writable_view :
    WritableRasterView,
    tryMakeWritableRasterView;

import std.algorithm : sort;
import std.stdio : writefln;


private enum size_t warmups = 2;
private enum size_t repetitions = 9;
private __gshared ulong sink;


@safe
pure
nothrow
@nogc
float productionTransform(float value)
{
    return value * 1.25f + 0.375f;
}


private
T invokeTransform(alias transform, T)(T value)
@safe
pure
nothrow
@nogc
{
    return transform(value);
}


private
void executeCanonical(alias transform, T)(
    scope const(T)* sourceBase,
    ptrdiff_t sourceRowStride,
    size_t width,
    size_t height,
    scope T* destinationBase,
    ptrdiff_t destinationRowStride
)
@trusted
pure
nothrow
@nogc
{
    assert(sourceBase !is null);
    assert(destinationBase !is null);

    foreach (y; 0 .. height)
    {
        const sourceRow =
            sourceBase
            + cast(ptrdiff_t)y * sourceRowStride;

        auto destinationRow =
            destinationBase
            + cast(ptrdiff_t)y * destinationRowStride;

        foreach (x; 0 .. width)
        {
            destinationRow[x] =
                invokeTransform!transform(sourceRow[x]);
        }
    }
}


/++
    Computes one conservative half-open byte interval containing every
    physically reachable sample byte of an already-validated non-empty affine
    plane.

    This research helper relies only on invariants already established by the
    RasterView/WritableRasterView backing validator: endpoint coordinate
    products and their combined minimum/maximum offsets are representable and
    point into validated retained resources.
+/
private
bool validatedAffineBoundingRange(T, P)(
    scope P base,
    ptrdiff_t rowStride,
    ptrdiff_t sampleStride,
    size_t width,
    size_t height,
    out size_t start,
    out size_t byteLength
)
@trusted
nothrow
@nogc
{
    start = 0;
    byteLength = 0;

    assert(base !is null);
    assert(width != 0);
    assert(height != 0);

    const xLast =
        cast(ptrdiff_t)(width - 1) * sampleStride;

    const yLast =
        cast(ptrdiff_t)(height - 1) * rowStride;

    const xMin = xLast < 0 ? xLast : 0;
    const xMax = xLast > 0 ? xLast : 0;

    const yMin = yLast < 0 ? yLast : 0;
    const yMax = yLast > 0 ? yLast : 0;

    const minimumOffset = xMin + yMin;
    const maximumOffset = xMax + yMax;

    const lower =
        base + minimumOffset;

    const upperSample =
        base + maximumOffset;

    const lowerAddress =
        cast(size_t) lower;

    const upperAddress =
        cast(size_t) upperSample;

    if (upperAddress < lowerAddress)
        return false;

    const spanToLastSample =
        upperAddress - lowerAddress;

    if (spanToLastSample > size_t.max - T.sizeof)
        return false;

    start = lowerAddress;
    byteLength = spanToLastSample + T.sizeof;

    return true;
}


bool tryCanonicalCandidate(alias transform, T)(
    scope RasterView!T source,
    size_t sourcePlaneIndex,
    scope ref WritableRasterView!T destination,
    size_t destinationPlaneIndex,
    out RasterTransformError error
)
@safe
nothrow
@nogc
{
    error = RasterTransformError.none;

    ptrdiff_t sourceRowStride;
    ptrdiff_t sourceSampleStride;

    if (!source.tryExecutionPlaneStrides(
        sourcePlaneIndex,
        sourceRowStride,
        sourceSampleStride
    ))
    {
        error = RasterTransformError.invalidSourcePlane;
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
        error = RasterTransformError.invalidDestinationPlane;
        return false;
    }

    if (
        source.width != destination.width
        || source.height != destination.height
    )
    {
        error = RasterTransformError.shapeMismatch;
        return false;
    }

    if (source.empty)
        return true;

    if (sourceSampleStride != 1 || destinationSampleStride != 1)
        return false;

    if (!affine2DMappingIsInjective(
        destination.width,
        destination.height,
        destinationRowStride,
        destinationSampleStride
    ))
    {
        error = RasterTransformError.nonInjectiveDestination;
        return false;
    }

    const sourceBase =
        source.executionRegionBase(sourcePlaneIndex);

    auto destinationBase =
        destination.executionRegionBase(destinationPlaneIndex);

    assert(sourceBase !is null);
    assert(destinationBase !is null);

    final switch (classifySameTypeAffine2DByteOverlap(
        source.width,
        source.height,
        cast(size_t) sourceBase,
        sourceRowStride,
        sourceSampleStride,
        cast(size_t) destinationBase,
        destinationRowStride,
        destinationSampleStride,
        T.sizeof
    ))
    {
        case AffineByteOverlapRelation.overlap:
            error = RasterTransformError.sourceDestinationOverlap;
            return false;

        case AffineByteOverlapRelation.arithmeticFailure:
            return false;

        case AffineByteOverlapRelation.disjoint:
            break;
    }

    executeCanonical!transform(
        sourceBase,
        sourceRowStride,
        source.width,
        source.height,
        destinationBase,
        destinationRowStride
    );

    return true;
}


bool tryBoundingCandidate(alias transform, T)(
    scope RasterView!T source,
    size_t sourcePlaneIndex,
    scope ref WritableRasterView!T destination,
    size_t destinationPlaneIndex,
    out RasterTransformError error
)
@safe
nothrow
@nogc
{
    error = RasterTransformError.none;

    ptrdiff_t sourceRowStride;
    ptrdiff_t sourceSampleStride;

    if (!source.tryExecutionPlaneStrides(
        sourcePlaneIndex,
        sourceRowStride,
        sourceSampleStride
    ))
    {
        error = RasterTransformError.invalidSourcePlane;
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
        error = RasterTransformError.invalidDestinationPlane;
        return false;
    }

    if (
        source.width != destination.width
        || source.height != destination.height
    )
    {
        error = RasterTransformError.shapeMismatch;
        return false;
    }

    if (source.empty)
        return true;

    if (sourceSampleStride != 1 || destinationSampleStride != 1)
        return false;

    if (!affine2DMappingIsInjective(
        destination.width,
        destination.height,
        destinationRowStride,
        destinationSampleStride
    ))
    {
        error = RasterTransformError.nonInjectiveDestination;
        return false;
    }

    const sourceBase =
        source.executionRegionBase(sourcePlaneIndex);

    auto destinationBase =
        destination.executionRegionBase(destinationPlaneIndex);

    assert(sourceBase !is null);
    assert(destinationBase !is null);

    size_t sourceRangeStart;
    size_t sourceRangeLength;
    size_t destinationRangeStart;
    size_t destinationRangeLength;

    const sourceRangeOk =
        validatedAffineBoundingRange!T(
            sourceBase,
            sourceRowStride,
            sourceSampleStride,
            source.width,
            source.height,
            sourceRangeStart,
            sourceRangeLength
        );

    const destinationRangeOk =
        validatedAffineBoundingRange!T(
            destinationBase,
            destinationRowStride,
            destinationSampleStride,
            destination.width,
            destination.height,
            destinationRangeStart,
            destinationRangeLength
        );

    bool needExactRelation = true;

    if (sourceRangeOk && destinationRangeOk)
    {
        final switch (classifyByteAddressRanges(
            sourceRangeStart,
            sourceRangeLength,
            destinationRangeStart,
            destinationRangeLength
        ))
        {
            case PhysicalByteRangeRelation.nonOverlapping:
                needExactRelation = false;
                break;

            case PhysicalByteRangeRelation.overlapping:
            case PhysicalByteRangeRelation.unrepresentable:
                break;
        }
    }

    if (needExactRelation)
    {
        final switch (classifySameTypeAffine2DByteOverlap(
            source.width,
            source.height,
            cast(size_t) sourceBase,
            sourceRowStride,
            sourceSampleStride,
            cast(size_t) destinationBase,
            destinationRowStride,
            destinationSampleStride,
            T.sizeof
        ))
        {
            case AffineByteOverlapRelation.overlap:
                error = RasterTransformError.sourceDestinationOverlap;
                return false;

            case AffineByteOverlapRelation.arithmeticFailure:
                return false;

            case AffineByteOverlapRelation.disjoint:
                break;
        }
    }

    executeCanonical!transform(
        sourceBase,
        sourceRowStride,
        source.width,
        source.height,
        destinationBase,
        destinationRowStride
    );

    return true;
}


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


private
float logicalValue(size_t x, size_t y)
@safe
pure
nothrow
@nogc
{
    return
        cast(float)(
            ((x * 37 + y * 53 + (x ^ y) * 7) % 4093)
        ) * 0.00025f;
}


private
uint bits(float value)
@trusted
pure
nothrow
@nogc
{
    union U
    {
        float f;
        uint u;
    }

    U u;
    u.f = value;
    return u.u;
}


private
ulong logicalFingerprint(
    scope const(float)[] storage,
    size_t width,
    size_t height,
    size_t pitch,
    bool negativeRows
)
@safe
nothrow
@nogc
{
    ulong hash = 0xcbf29ce484222325UL;

    foreach (y; 0 .. height)
    {
        const physicalY =
            negativeRows
            ? height - 1 - y
            : y;

        foreach (x; 0 .. width)
        {
            hash ^= bits(storage[physicalY * pitch + x]);
            hash *= 0x100000001b3UL;
        }
    }

    return hash;
}


private
long median(ref long[repetitions] samples)
{
    auto copy = samples;
    sort(copy[]);
    return copy[copy.length / 2];
}


private
void consume(ulong hash)
@trusted
nothrow
@nogc
{
    sink ^= hash + 0x9e3779b97f4a7c15UL;
}


private
long measure(scope void delegate() operation)
{
    const start = MonoTime.currTime;
    operation();
    return (MonoTime.currTime - start).total!"nsecs";
}


private
int runCase(
    size_t width,
    size_t height,
    size_t pitch,
    bool negativeSourceRows,
    bool negativeDestinationRows
)
{
    if (pitch < width)
        return 1;

    auto sourceStorage = new float[pitch * height];
    auto publicOutput = new float[pitch * height];
    auto candidateOutput = new float[pitch * height];
    auto boundingOutput = new float[pitch * height];

    foreach (y; 0 .. height)
    {
        const physicalY =
            negativeSourceRows
            ? height - 1 - y
            : y;

        foreach (x; 0 .. width)
        {
            sourceStorage[physicalY * pitch + x] =
                logicalValue(x, y);
        }
    }

    const sourceBase =
        negativeSourceRows
        ? sourceStorage.ptr + (height - 1) * pitch
        : sourceStorage.ptr;

    const publicBase =
        negativeDestinationRows
        ? publicOutput.ptr + (height - 1) * pitch
        : publicOutput.ptr;

    const candidateBase =
        negativeDestinationRows
        ? candidateOutput.ptr + (height - 1) * pitch
        : candidateOutput.ptr;

    const boundingBase =
        negativeDestinationRows
        ? boundingOutput.ptr + (height - 1) * pitch
        : boundingOutput.ptr;

    const sourceRowStride =
        negativeSourceRows
        ? -cast(ptrdiff_t)pitch
        : cast(ptrdiff_t)pitch;

    const destinationRowStride =
        negativeDestinationRows
        ? -cast(ptrdiff_t)pitch
        : cast(ptrdiff_t)pitch;

    const PlaneDescriptor[1] sourceDescriptors =
        [PlaneDescriptor(sourceBase, sourceRowStride, 1)];

    const PlaneDescriptor[1] publicDescriptors =
        [PlaneDescriptor(publicBase, destinationRowStride, 1)];

    const PlaneDescriptor[1] candidateDescriptors =
        [PlaneDescriptor(candidateBase, destinationRowStride, 1)];

    const PlaneDescriptor[1] boundingDescriptors =
        [PlaneDescriptor(boundingBase, destinationRowStride, 1)];

    const ResourceEntry[1] publicResources =
    [
        ResourceEntry(
            publicOutput.ptr,
            publicOutput.length * float.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    const ResourceEntry[1] candidateResources =
    [
        ResourceEntry(
            candidateOutput.ptr,
            candidateOutput.length * float.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    const ResourceEntry[1] boundingResources =
    [
        ResourceEntry(
            boundingOutput.ptr,
            boundingOutput.length * float.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!float(
            sourceDescriptors[],
            Region2D(0,0,width,height)
        );

    scope auto publicDestination =
        makeWritable!float(
            publicResources[],
            publicDescriptors[],
            Region2D(0,0,width,height)
        );

    scope auto candidateDestination =
        makeWritable!float(
            candidateResources[],
            candidateDescriptors[],
            Region2D(0,0,width,height)
        );

    scope auto boundingDestination =
        makeWritable!float(
            boundingResources[],
            boundingDescriptors[],
            Region2D(0,0,width,height)
        );

    RasterTransformError error;

    if (!tryTransformRasterPlane!productionTransform(
        source,
        0,
        publicDestination,
        0,
        error
    ))
        return 1;

    if (!tryCanonicalCandidate!productionTransform(
        source,
        0,
        candidateDestination,
        0,
        error
    ))
        return 1;

    if (!tryBoundingCandidate!productionTransform(
        source,
        0,
        boundingDestination,
        0,
        error
    ))
        return 1;

    const publicFingerprint =
        logicalFingerprint(
            publicOutput,
            width,
            height,
            pitch,
            negativeDestinationRows
        );

    const candidateFingerprint =
        logicalFingerprint(
            candidateOutput,
            width,
            height,
            pitch,
            negativeDestinationRows
        );

    const boundingFingerprint =
        logicalFingerprint(
            boundingOutput,
            width,
            height,
            pitch,
            negativeDestinationRows
        );

    if (
        publicFingerprint != candidateFingerprint
        || publicFingerprint != boundingFingerprint
    )
        return 1;

    foreach (_; 0 .. warmups)
    {
        if (!tryTransformRasterPlane!productionTransform(
            source,0,publicDestination,0,error))
            return 1;

        consume(logicalFingerprint(
            publicOutput,width,height,pitch,negativeDestinationRows));

        if (!tryCanonicalCandidate!productionTransform(
            source,0,candidateDestination,0,error))
            return 1;

        consume(logicalFingerprint(
            candidateOutput,width,height,pitch,negativeDestinationRows));

        if (!tryBoundingCandidate!productionTransform(
            source,0,boundingDestination,0,error))
            return 1;

        consume(logicalFingerprint(
            boundingOutput,width,height,pitch,negativeDestinationRows));
    }

    long[repetitions] publicSamples;
    long[repetitions] candidateSamples;
    long[repetitions] boundingSamples;

    bool publicOk = true;
    bool candidateOk = true;
    bool boundingOk = true;

    foreach (r; 0 .. repetitions)
    {
        final switch (r % 3)
        {
            case 0:
                publicSamples[r] = measure({
                    const ok =
                        tryTransformRasterPlane!productionTransform(
                            source,0,publicDestination,0,error
                        );
                    publicOk = publicOk && ok;
                });
                consume(logicalFingerprint(
                    publicOutput,
                    width,
                    height,
                    pitch,
                    negativeDestinationRows
                ));

                candidateSamples[r] = measure({
                    const ok =
                        tryCanonicalCandidate!productionTransform(
                            source,0,candidateDestination,0,error
                        );
                    candidateOk = candidateOk && ok;
                });
                consume(logicalFingerprint(
                    candidateOutput,
                    width,
                    height,
                    pitch,
                    negativeDestinationRows
                ));

                boundingSamples[r] = measure({
                    const ok =
                        tryBoundingCandidate!productionTransform(
                            source,0,boundingDestination,0,error
                        );
                    boundingOk = boundingOk && ok;
                });
                consume(logicalFingerprint(
                    boundingOutput,
                    width,
                    height,
                    pitch,
                    negativeDestinationRows
                ));
                break;

            case 1:
                candidateSamples[r] = measure({
                    const ok =
                        tryCanonicalCandidate!productionTransform(
                            source,0,candidateDestination,0,error
                        );
                    candidateOk = candidateOk && ok;
                });
                consume(logicalFingerprint(
                    candidateOutput,
                    width,
                    height,
                    pitch,
                    negativeDestinationRows
                ));

                boundingSamples[r] = measure({
                    const ok =
                        tryBoundingCandidate!productionTransform(
                            source,0,boundingDestination,0,error
                        );
                    boundingOk = boundingOk && ok;
                });
                consume(logicalFingerprint(
                    boundingOutput,
                    width,
                    height,
                    pitch,
                    negativeDestinationRows
                ));

                publicSamples[r] = measure({
                    const ok =
                        tryTransformRasterPlane!productionTransform(
                            source,0,publicDestination,0,error
                        );
                    publicOk = publicOk && ok;
                });
                consume(logicalFingerprint(
                    publicOutput,
                    width,
                    height,
                    pitch,
                    negativeDestinationRows
                ));
                break;

            case 2:
                boundingSamples[r] = measure({
                    const ok =
                        tryBoundingCandidate!productionTransform(
                            source,0,boundingDestination,0,error
                        );
                    boundingOk = boundingOk && ok;
                });
                consume(logicalFingerprint(
                    boundingOutput,
                    width,
                    height,
                    pitch,
                    negativeDestinationRows
                ));

                publicSamples[r] = measure({
                    const ok =
                        tryTransformRasterPlane!productionTransform(
                            source,0,publicDestination,0,error
                        );
                    publicOk = publicOk && ok;
                });
                consume(logicalFingerprint(
                    publicOutput,
                    width,
                    height,
                    pitch,
                    negativeDestinationRows
                ));

                candidateSamples[r] = measure({
                    const ok =
                        tryCanonicalCandidate!productionTransform(
                            source,0,candidateDestination,0,error
                        );
                    candidateOk = candidateOk && ok;
                });
                consume(logicalFingerprint(
                    candidateOutput,
                    width,
                    height,
                    pitch,
                    negativeDestinationRows
                ));
                break;
        }
    }

    if (!publicOk || !candidateOk || !boundingOk)
        return 1;

    const expectedFingerprint =
        logicalFingerprint(
            publicOutput,
            width,
            height,
            pitch,
            negativeDestinationRows
        );

    if (
        logicalFingerprint(
            candidateOutput,
            width,
            height,
            pitch,
            negativeDestinationRows
        )
        != expectedFingerprint
        ||
        logicalFingerprint(
            boundingOutput,
            width,
            height,
            pitch,
            negativeDestinationRows
        )
        != expectedFingerprint
    )
        return 1;

    const publicMedian = median(publicSamples);
    const candidateMedian = median(candidateSamples);
    const boundingMedian = median(boundingSamples);

    writefln(
        "m3_transform width=%s height=%s pitch=%s source_rows=%s destination_rows=%s public_ns=%s candidate_ns=%s bounding_ns=%s candidate_speedup=%.3f bounding_speedup=%.3f bounding_over_candidate=%.6f mpix_public=%.3f mpix_candidate=%.3f mpix_bounding=%.3f fingerprint=%016x sink=%s",
        width,
        height,
        pitch,
        negativeSourceRows ? "negative" : "positive",
        negativeDestinationRows ? "negative" : "positive",
        publicMedian,
        candidateMedian,
        boundingMedian,
        cast(double)publicMedian / cast(double)candidateMedian,
        cast(double)publicMedian / cast(double)boundingMedian,
        cast(double)boundingMedian / cast(double)candidateMedian,
        cast(double)(width * height) * 1000.0 / cast(double)publicMedian,
        cast(double)(width * height) * 1000.0 / cast(double)candidateMedian,
        cast(double)(width * height) * 1000.0 / cast(double)boundingMedian,
        expectedFingerprint,
        sink
    );

    writefln(
        "m3_transform_raw width=%s height=%s pitch=%s source_rows=%s destination_rows=%s public=%(%s,%) candidate=%(%s,%) bounding=%(%s,%)",
        width,
        height,
        pitch,
        negativeSourceRows ? "negative" : "positive",
        negativeDestinationRows ? "negative" : "positive",
        publicSamples,
        candidateSamples,
        boundingSamples
    );

    return 0;
}


private
int runUniversalFallbackProbe()
{
    enum size_t width = 31;
    enum size_t height = 17;
    enum size_t sampleStride = 2;
    enum size_t sourcePitch = 80;
    enum size_t destinationPitch = 40;

    auto sourceStorage = new float[sourcePitch * height];
    auto destinationStorage = new float[destinationPitch * height];

    foreach (y; 0 .. height)
    {
        foreach (x; 0 .. width)
        {
            sourceStorage[
                y * sourcePitch + x * sampleStride
            ] =
                logicalValue(x, y);
        }
    }

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            sourceStorage.ptr,
            sourcePitch,
            sampleStride
        )
    ];

    const PlaneDescriptor[1] destinationDescriptors =
    [
        PlaneDescriptor(
            destinationStorage.ptr
                + (height - 1) * destinationPitch,
            -cast(ptrdiff_t)destinationPitch,
            1
        )
    ];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            destinationStorage.ptr,
            destinationStorage.length * float.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!float(
            sourceDescriptors[],
            Region2D(0,0,width,height)
        );

    scope auto destination =
        makeWritable!float(
            destinationResources[],
            destinationDescriptors[],
            Region2D(0,0,width,height)
        );

    RasterTransformError error;

    if (!tryTransformRasterPlane!productionTransform(
        source,
        0,
        destination,
        0,
        error
    ))
        return 1;

    if (tryCanonicalCandidate!productionTransform(
        source,
        0,
        destination,
        0,
        error
    ))
        return 1;

    foreach (y; 0 .. height)
    {
        foreach (x; 0 .. width)
        {
            const expected =
                productionTransform(logicalValue(x, y));

            const actual =
                destinationStorage[
                    (height - 1 - y)
                        * destinationPitch
                        + x
                ];

            if (bits(actual) != bits(expected))
                return 1;
        }
    }

    writefln(
        "m3_transform_fallback source_sample_stride=%s destination_rows=negative result=PASS",
        sampleStride
    );

    return 0;
}


int runBenchmarkMatrix()
{
    if (runUniversalFallbackProbe() != 0)
        return 1;

    struct Case
    {
        size_t width;
        size_t height;
        size_t pitch;
    }

    const cases =
    [
        Case(128, 64, 192),
        Case(512, 256, 640),
        Case(2048, 512, 2304)
    ];

    foreach (entry; cases)
    {
        foreach (negativeSourceRows; [false, true])
        {
            foreach (negativeDestinationRows; [false, true])
            {
                if (runCase(
                    entry.width,
                    entry.height,
                    entry.pitch,
                    negativeSourceRows,
                    negativeDestinationRows
                ) != 0)
                    return 1;
            }
        }
    }

    return 0;
}
