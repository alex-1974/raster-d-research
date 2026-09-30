module raster.research.m3_production_neighbourhood.candidate;

import core.time : MonoTime;

import raster :
    RasterNeighbourhood3x3Error,
    Region2D,
    tryApplyRasterNeighbourhood3x3;

import raster.descriptor : PlaneDescriptor;
import raster.internal.affine_relation :
    AffineByteOverlapRelation,
    affine2DMappingIsInjective,
    classifySameTypeAffine2DRectanglesByteOverlap;
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
float productionKernel(ref const(float)[9] n)
{
    return
          n[0]
        + n[1] * 2.0f
        + n[2] * 3.0f
        + n[3] * 5.0f
        + n[4] * 7.0f
        + n[5] * 11.0f
        + n[6] * 13.0f
        + n[7] * 17.0f
        + n[8] * 19.0f;
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
bool executeCanonicalApproved(alias kernel, T)(
    scope const(T)* sourceBase,
    ptrdiff_t sourceRowStride,
    size_t outputX,
    size_t outputY,
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

    const sourceStart =
        sourceBase
        + cast(ptrdiff_t) outputY * sourceRowStride
        + cast(ptrdiff_t) outputX;

    foreach (y; 0 .. height)
    {
        const centerRow =
            sourceStart
            + cast(ptrdiff_t) y * sourceRowStride;

        const row0 = centerRow - sourceRowStride - 1;
        const row1 = centerRow - 1;
        const row2 = centerRow + sourceRowStride - 1;

        auto destinationRow =
            destinationBase
            + cast(ptrdiff_t) y * destinationRowStride;

        foreach (x; 0 .. width)
        {
            T[9] n =
            [
                row0[x], row0[x + 1], row0[x + 2],
                row1[x], row1[x + 1], row1[x + 2],
                row2[x], row2[x + 1], row2[x + 2]
            ];

            destinationRow[x] =
                invokeKernel!kernel(n);
        }
    }

    return true;
}



pragma(inline, false)
private
void executeCanonicalRowNoInline(alias kernel, T)(
    scope const(T)* row0,
    scope const(T)* row1,
    scope const(T)* row2,
    scope T* destinationRow,
    size_t width
)
@trusted
pure
nothrow
@nogc
{
    foreach (x; 0 .. width)
    {
        T[9] n =
        [
            row0[x], row0[x + 1], row0[x + 2],
            row1[x], row1[x + 1], row1[x + 2],
            row2[x], row2[x + 1], row2[x + 2]
        ];

        destinationRow[x] =
            invokeKernel!kernel(n);
    }
}


private
bool executeCanonicalNoInline(alias kernel, T)(
    scope const(T)* sourceBase,
    ptrdiff_t sourceRowStride,
    size_t outputX,
    size_t outputY,
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

    const sourceStart =
        sourceBase
        + cast(ptrdiff_t) outputY * sourceRowStride
        + cast(ptrdiff_t) outputX;

    foreach (y; 0 .. height)
    {
        const centerRow =
            sourceStart
            + cast(ptrdiff_t) y * sourceRowStride;

        const row0 = centerRow - sourceRowStride - 1;
        const row1 = centerRow - 1;
        const row2 = centerRow + sourceRowStride - 1;

        auto destinationRow =
            destinationBase
            + cast(ptrdiff_t) y * destinationRowStride;

        executeCanonicalRowNoInline!kernel(
            row0,
            row1,
            row2,
            destinationRow,
            width
        );
    }

    return true;
}


private
bool tryCanonicalCandidateImpl(alias kernel, bool noInline, T)(
    scope RasterView!T source,
    size_t sourcePlaneIndex,
    Region2D sourceOutputRegion,
    scope ref WritableRasterView!T destination,
    size_t destinationPlaneIndex,
    out RasterNeighbourhood3x3Error error
)
@safe
nothrow
@nogc
{
    error = RasterNeighbourhood3x3Error.none;

    ptrdiff_t sourceRowStride;
    ptrdiff_t sourceSampleStride;

    if (!source.tryExecutionPlaneStrides(
        sourcePlaneIndex,
        sourceRowStride,
        sourceSampleStride
    ))
    {
        error = RasterNeighbourhood3x3Error.invalidSourcePlane;
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
        error = RasterNeighbourhood3x3Error.invalidDestinationPlane;
        return false;
    }

    if (
        destination.width != sourceOutputRegion.width
        || destination.height != sourceOutputRegion.height
    )
    {
        error = RasterNeighbourhood3x3Error.destinationShapeMismatch;
        return false;
    }

    if (!source.region.containsRelative(sourceOutputRegion))
    {
        error = RasterNeighbourhood3x3Error.unsatisfiedNeighbourhood;
        return false;
    }

    if (sourceOutputRegion.empty())
        return true;

    if (
        sourceOutputRegion.x == 0
        || sourceOutputRegion.y == 0
        || sourceOutputRegion.width >= source.width - sourceOutputRegion.x
        || sourceOutputRegion.height >= source.height - sourceOutputRegion.y
    )
    {
        error = RasterNeighbourhood3x3Error.unsatisfiedNeighbourhood;
        return false;
    }

    if (sourceSampleStride != 1 || destinationSampleStride != 1)
        return false;

    if (!affine2DMappingIsInjective(
        destination.width,
        destination.height,
        destinationRowStride,
        destinationSampleStride
    ))
    {
        error = RasterNeighbourhood3x3Error.nonInjectiveDestination;
        return false;
    }

    const required =
        Region2D(
            sourceOutputRegion.x - 1,
            sourceOutputRegion.y - 1,
            sourceOutputRegion.width + 2,
            sourceOutputRegion.height + 2
        );

    bool roiOk;
    scope auto requiredSource = source.tryRoi(required, roiOk);
    assert(roiOk);

    ptrdiff_t requiredRowStride;
    ptrdiff_t requiredSampleStride;

    assert(requiredSource.tryExecutionPlaneStrides(
        sourcePlaneIndex,
        requiredRowStride,
        requiredSampleStride
    ));

    const sourceBase =
        requiredSource.executionRegionBase(sourcePlaneIndex);

    auto destinationBase =
        destination.executionRegionBase(destinationPlaneIndex);

    assert(sourceBase !is null);
    assert(destinationBase !is null);

    final switch (classifySameTypeAffine2DRectanglesByteOverlap(
        requiredSource.width,
        requiredSource.height,
        cast(size_t) sourceBase,
        requiredRowStride,
        requiredSampleStride,

        destination.width,
        destination.height,
        cast(size_t) destinationBase,
        destinationRowStride,
        destinationSampleStride,

        T.sizeof
    ))
    {
        case AffineByteOverlapRelation.overlap:
            error = RasterNeighbourhood3x3Error.sourceDestinationOverlap;
            return false;

        case AffineByteOverlapRelation.arithmeticFailure:
            return false;

        case AffineByteOverlapRelation.disjoint:
            break;
    }

    const fullSourceBase =
        source.executionRegionBase(sourcePlaneIndex);

    assert(fullSourceBase !is null);

    static if (noInline)
    {
        return executeCanonicalNoInline!kernel(
            fullSourceBase,
            sourceRowStride,
            sourceOutputRegion.x,
            sourceOutputRegion.y,
            destination.width,
            destination.height,
            destinationBase,
            destinationRowStride
        );
    }
    else
    {
        return executeCanonicalApproved!kernel(
            fullSourceBase,
            sourceRowStride,
            sourceOutputRegion.x,
            sourceOutputRegion.y,
            destination.width,
            destination.height,
            destinationBase,
            destinationRowStride
        );
    }
}


bool tryCanonicalCandidate(alias kernel, T)(
    scope RasterView!T source,
    size_t sourcePlaneIndex,
    Region2D sourceOutputRegion,
    scope ref WritableRasterView!T destination,
    size_t destinationPlaneIndex,
    out RasterNeighbourhood3x3Error error
)
@safe
nothrow
@nogc
{
    return tryCanonicalCandidateImpl!(kernel, false)(
        source,
        sourcePlaneIndex,
        sourceOutputRegion,
        destination,
        destinationPlaneIndex,
        error
    );
}


bool tryCanonicalNoInlineCandidate(alias kernel, T)(
    scope RasterView!T source,
    size_t sourcePlaneIndex,
    Region2D sourceOutputRegion,
    scope ref WritableRasterView!T destination,
    size_t destinationPlaneIndex,
    out RasterNeighbourhood3x3Error error
)
@safe
nothrow
@nogc
{
    return tryCanonicalCandidateImpl!(kernel, true)(
        source,
        sourcePlaneIndex,
        sourceOutputRegion,
        destination,
        destinationPlaneIndex,
        error
    );
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
ulong fingerprint(scope const(float)[] values)
@safe
nothrow
@nogc
{
    ulong hash = 0xcbf29ce484222325UL;

    foreach (value; values)
    {
        hash ^= bits(value);
        hash *= 0x100000001b3UL;
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
void consume(scope const(float)[] values)
@trusted
nothrow
@nogc
{
    const hash = fingerprint(values);
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
    bool negativeRows
)
{
    const residentWidth = width + 2;
    const residentHeight = height + 2;

    if (pitch < residentWidth)
        return 1;

    auto sourceStorage =
        new float[pitch * residentHeight];

    foreach (y; 0 .. residentHeight)
    {
        const physicalY =
            negativeRows
            ? residentHeight - 1 - y
            : y;

        foreach (x; 0 .. residentWidth)
        {
            sourceStorage[physicalY * pitch + x] =
                logicalValue(x, y);
        }
    }

    auto publicOutput = new float[width * height];
    auto candidateOutput = new float[width * height];
    auto noInlineOutput = new float[width * height];

    const sourceBase =
        negativeRows
        ? sourceStorage.ptr + (residentHeight - 1) * pitch
        : sourceStorage.ptr;

    const PlaneDescriptor[1] sourceDescriptors =
    [
        PlaneDescriptor(
            sourceBase,
            negativeRows
                ? -cast(ptrdiff_t) pitch
                : cast(ptrdiff_t) pitch,
            1
        )
    ];

    const PlaneDescriptor[1] publicDescriptors =
        [PlaneDescriptor(publicOutput.ptr, width, 1)];

    const PlaneDescriptor[1] candidateDescriptors =
        [PlaneDescriptor(candidateOutput.ptr, width, 1)];

    const PlaneDescriptor[1] noInlineDescriptors =
        [PlaneDescriptor(noInlineOutput.ptr, width, 1)];

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

    const ResourceEntry[1] noInlineResources =
    [
        ResourceEntry(
            noInlineOutput.ptr,
            noInlineOutput.length * float.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!float(
            sourceDescriptors[],
            Region2D(0,0,residentWidth,residentHeight)
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

    scope auto noInlineDestination =
        makeWritable!float(
            noInlineResources[],
            noInlineDescriptors[],
            Region2D(0,0,width,height)
        );

    RasterNeighbourhood3x3Error error;

    if (!tryApplyRasterNeighbourhood3x3!productionKernel(
        source,
        0,
        Region2D(1,1,width,height),
        publicDestination,
        0,
        error
    ))
        return 1;

    if (!tryCanonicalCandidate!productionKernel(
        source,
        0,
        Region2D(1,1,width,height),
        candidateDestination,
        0,
        error
    ))
        return 1;

    if (!tryCanonicalNoInlineCandidate!productionKernel(
        source,
        0,
        Region2D(1,1,width,height),
        noInlineDestination,
        0,
        error
    ))
        return 1;

    if (
        publicOutput != candidateOutput
        || publicOutput != noInlineOutput
    )
        return 1;

    const expectedFingerprint =
        fingerprint(publicOutput);

    foreach (_; 0 .. warmups)
    {
        if (!tryApplyRasterNeighbourhood3x3!productionKernel(
            source,0,Region2D(1,1,width,height),publicDestination,0,error))
            return 1;
        consume(publicOutput);

        if (!tryCanonicalCandidate!productionKernel(
            source,0,Region2D(1,1,width,height),candidateDestination,0,error))
            return 1;
        consume(candidateOutput);

        if (!tryCanonicalNoInlineCandidate!productionKernel(
            source,0,Region2D(1,1,width,height),noInlineDestination,0,error))
            return 1;
        consume(noInlineOutput);
    }

    long[repetitions] publicSamples;
    long[repetitions] candidateSamples;
    long[repetitions] noInlineSamples;

    bool publicExecutionOk = true;
    bool candidateExecutionOk = true;
    bool noInlineExecutionOk = true;

    foreach (r; 0 .. repetitions)
    {
        final switch (r % 3)
        {
            case 0:
                publicSamples[r] = measure({
                    const ok =
                        tryApplyRasterNeighbourhood3x3!productionKernel(
                            source,0,Region2D(1,1,width,height),
                            publicDestination,0,error
                        );

                    publicExecutionOk = publicExecutionOk && ok;
                    consume(publicOutput);
                });

                candidateSamples[r] = measure({
                    const ok =
                        tryCanonicalCandidate!productionKernel(
                            source,0,Region2D(1,1,width,height),
                            candidateDestination,0,error
                        );

                    candidateExecutionOk = candidateExecutionOk && ok;
                    consume(candidateOutput);
                });

                noInlineSamples[r] = measure({
                    const ok =
                        tryCanonicalNoInlineCandidate!productionKernel(
                            source,0,Region2D(1,1,width,height),
                            noInlineDestination,0,error
                        );

                    noInlineExecutionOk = noInlineExecutionOk && ok;
                    consume(noInlineOutput);
                });
                break;

            case 1:
                candidateSamples[r] = measure({
                    const ok =
                        tryCanonicalCandidate!productionKernel(
                            source,0,Region2D(1,1,width,height),
                            candidateDestination,0,error
                        );

                    candidateExecutionOk = candidateExecutionOk && ok;
                    consume(candidateOutput);
                });

                noInlineSamples[r] = measure({
                    const ok =
                        tryCanonicalNoInlineCandidate!productionKernel(
                            source,0,Region2D(1,1,width,height),
                            noInlineDestination,0,error
                        );

                    noInlineExecutionOk = noInlineExecutionOk && ok;
                    consume(noInlineOutput);
                });

                publicSamples[r] = measure({
                    const ok =
                        tryApplyRasterNeighbourhood3x3!productionKernel(
                            source,0,Region2D(1,1,width,height),
                            publicDestination,0,error
                        );

                    publicExecutionOk = publicExecutionOk && ok;
                    consume(publicOutput);
                });
                break;

            case 2:
                noInlineSamples[r] = measure({
                    const ok =
                        tryCanonicalNoInlineCandidate!productionKernel(
                            source,0,Region2D(1,1,width,height),
                            noInlineDestination,0,error
                        );

                    noInlineExecutionOk = noInlineExecutionOk && ok;
                    consume(noInlineOutput);
                });

                publicSamples[r] = measure({
                    const ok =
                        tryApplyRasterNeighbourhood3x3!productionKernel(
                            source,0,Region2D(1,1,width,height),
                            publicDestination,0,error
                        );

                    publicExecutionOk = publicExecutionOk && ok;
                    consume(publicOutput);
                });

                candidateSamples[r] = measure({
                    const ok =
                        tryCanonicalCandidate!productionKernel(
                            source,0,Region2D(1,1,width,height),
                            candidateDestination,0,error
                        );

                    candidateExecutionOk = candidateExecutionOk && ok;
                    consume(candidateOutput);
                });
                break;
        }
    }

    if (
        !publicExecutionOk
        || !candidateExecutionOk
        || !noInlineExecutionOk
        || fingerprint(publicOutput) != expectedFingerprint
        || fingerprint(candidateOutput) != expectedFingerprint
        || fingerprint(noInlineOutput) != expectedFingerprint
    )
        return 1;

    const publicMedian = median(publicSamples);
    const candidateMedian = median(candidateSamples);
    const noInlineMedian = median(noInlineSamples);

    writefln(
        "m3_neighbourhood width=%s height=%s pitch=%s rows=%s public_ns=%s candidate_ns=%s noinline_ns=%s candidate_over_public=%.6f noinline_over_candidate=%.6f mpix_public=%.3f mpix_candidate=%.3f mpix_noinline=%.3f fingerprint=%016x sink=%s",
        width,
        height,
        pitch,
        negativeRows ? "negative" : "positive",
        publicMedian,
        candidateMedian,
        noInlineMedian,
        cast(double) candidateMedian / cast(double) publicMedian,
        cast(double) noInlineMedian / cast(double) candidateMedian,
        cast(double)(width * height) * 1000.0 / cast(double) publicMedian,
        cast(double)(width * height) * 1000.0 / cast(double) candidateMedian,
        cast(double)(width * height) * 1000.0 / cast(double) noInlineMedian,
        expectedFingerprint,
        sink
    );

    writefln(
        "m3_neighbourhood_raw width=%s height=%s pitch=%s rows=%s public=%(%s,%) candidate=%(%s,%) noinline=%(%s,%)",
        width,
        height,
        pitch,
        negativeRows ? "negative" : "positive",
        publicSamples,
        candidateSamples,
        noInlineSamples
    );

    return 0;
}



private
int runUniversalFallbackProbe()
{
    enum size_t width = 31;
    enum size_t height = 17;
    enum size_t residentWidth = width + 2;
    enum size_t residentHeight = height + 2;
    enum size_t sampleStride = 2;
    enum size_t sourcePitch = 80;
    enum size_t destinationPitch = 40;

    auto sourceStorage =
        new float[sourcePitch * residentHeight];

    foreach (y; 0 .. residentHeight)
    {
        foreach (x; 0 .. residentWidth)
        {
            sourceStorage[
                y * sourcePitch
                + x * sampleStride
            ] =
                logicalValue(x, y);
        }
    }

    auto output =
        new float[destinationPitch * height];

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
            output.ptr + (height - 1) * destinationPitch,
            -cast(ptrdiff_t) destinationPitch,
            1
        )
    ];

    const ResourceEntry[1] destinationResources =
    [
        ResourceEntry(
            output.ptr,
            output.length * float.sizeof,
            null,
            null,
            ResourceAccess.readWrite
        )
    ];

    scope auto source =
        makeRasterViewAssumeValidated!float(
            sourceDescriptors[],
            Region2D(
                0,
                0,
                residentWidth,
                residentHeight
            )
        );

    scope auto destination =
        makeWritable!float(
            destinationResources[],
            destinationDescriptors[],
            Region2D(
                0,
                0,
                width,
                height
            )
        );

    RasterNeighbourhood3x3Error error;

    if (!tryApplyRasterNeighbourhood3x3!productionKernel(
        source,
        0,
        Region2D(1,1,width,height),
        destination,
        0,
        error
    ))
        return 1;

    /*
     * The Canonical candidate must decline this source because sample stride
     * is two. A production dispatcher would keep the existing generic path.
     */
    if (tryCanonicalCandidate!productionKernel(
        source,
        0,
        Region2D(1,1,width,height),
        destination,
        0,
        error
    ))
        return 1;

    foreach (y; 0 .. height)
    {
        foreach (x; 0 .. width)
        {
            float[9] n;
            size_t index;

            foreach (dy; 0 .. 3)
            {
                foreach (dx; 0 .. 3)
                {
                    n[index++] =
                        logicalValue(
                            x + dx,
                            y + dy
                        );
                }
            }

            const expected =
                productionKernel(n);

            const actual =
                output[
                    (height - 1 - y)
                        * destinationPitch
                        + x
                ];

            if (bits(actual) != bits(expected))
                return 1;
        }
    }

    writefln(
        "m3_neighbourhood_fallback source_sample_stride=%s destination_rows=negative result=PASS",
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
        Case(127, 64, 192),
        Case(128, 64, 192),
        Case(129, 64, 192),
        Case(511, 256, 640),
        Case(512, 256, 640),
        Case(513, 256, 640),
        Case(2047, 512, 2304),
        Case(2048, 512, 2304),
        Case(2049, 512, 2304),
        Case(2048, 512, 4096)
    ];

    foreach (entry; cases)
    {
        foreach (negativeRows; [false, true])
        {
            if (runCase(
                entry.width,
                entry.height,
                entry.pitch,
                negativeRows
            ) != 0)
                return 1;
        }
    }

    return 0;
}


/*
 * Stable code-generation qualification entry points.
 *
 * These wrappers intentionally expose fixed C symbols so the local reference
 * toolchain can emit and inspect the exact hot-loop source forms without
 * relying on D template mangling.
 *
 * They are research-only and do not define Production API.
 */

extern(C)
void m3_codegen_integrated(
    scope const(float)* sourceBase,
    ptrdiff_t sourceRowStride,
    size_t width,
    size_t height,
    scope float* destinationBase,
    ptrdiff_t destinationRowStride
)
@trusted
pure
nothrow
@nogc
{
    cast(void)
        executeCanonicalApproved!productionKernel(
            sourceBase,
            sourceRowStride,
            1,
            1,
            width,
            height,
            destinationBase,
            destinationRowStride
        );
}


extern(C)
void m3_codegen_noinline(
    scope const(float)* sourceBase,
    ptrdiff_t sourceRowStride,
    size_t width,
    size_t height,
    scope float* destinationBase,
    ptrdiff_t destinationRowStride
)
@trusted
pure
nothrow
@nogc
{
    cast(void)
        executeCanonicalNoInline!productionKernel(
            sourceBase,
            sourceRowStride,
            1,
            1,
            width,
            height,
            destinationBase,
            destinationRowStride
        );
}
