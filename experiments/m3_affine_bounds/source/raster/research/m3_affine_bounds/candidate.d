module raster.research.m3_affine_bounds.candidate;

import core.time : MonoTime;

import std.algorithm : sort;
import std.stdio : writeln, writefln;

import raster.internal.affine_relation :
    AffineByteOverlapRelation,
    classifySameTypeAffine2DRectanglesByteOverlap;

import raster.internal.physical_range :
    PhysicalByteRangeRelation,
    classifyByteAddressRanges;

private
struct Rect
{
    size_t width;
    size_t height;
    size_t base;
    ptrdiff_t rowStride;
    ptrdiff_t sampleStride;
}

private
struct Bound
{
    size_t start;
    size_t length;
    bool valid;
}

private
Bound smallDomainBound(Rect rect, size_t sampleSize)
@safe pure nothrow @nogc
{
    if (rect.width == 0 || rect.height == 0 || sampleSize == 0)
        return Bound.init;

    const long xLast =
        cast(long)(rect.width - 1) * cast(long)rect.sampleStride;
    const long yLast =
        cast(long)(rect.height - 1) * cast(long)rect.rowStride;

    const long minOffset =
        (xLast < 0 ? xLast : 0)
        + (yLast < 0 ? yLast : 0);

    const long maxOffset =
        (xLast > 0 ? xLast : 0)
        + (yLast > 0 ? yLast : 0);

    const long lower =
        cast(long)rect.base + minOffset * cast(long)sampleSize;
    const long upperSample =
        cast(long)rect.base + maxOffset * cast(long)sampleSize;

    if (lower < 0 || upperSample < lower)
        return Bound.init;

    const ulong span =
        cast(ulong)(upperSample - lower);

    if (span > size_t.max - sampleSize)
        return Bound.init;

    return Bound(
        cast(size_t)lower,
        cast(size_t)(span + sampleSize),
        true
    );
}

private
bool boundsDisjoint(Bound a, Bound b)
@safe pure nothrow @nogc
{
    assert(a.valid);
    assert(b.valid);

    if (a.length > size_t.max - a.start)
        return false;
    if (b.length > size_t.max - b.start)
        return false;

    const aEnd = a.start + a.length;
    const bEnd = b.start + b.length;

    return aEnd <= b.start || bEnd <= a.start;
}

private
bool fastRejectDisjoint(Rect a, Rect b, size_t sampleSize)
@safe pure nothrow @nogc
{
    if (
        a.width == 0 || a.height == 0
        || b.width == 0 || b.height == 0
    )
        return true;

    const ab = smallDomainBound(a, sampleSize);
    const bb = smallDomainBound(b, sampleSize);

    return ab.valid && bb.valid && boundsDisjoint(ab, bb);
}


private
bool checkedCoordinateStride(
    size_t coordinate,
    ptrdiff_t stride,
    out ptrdiff_t result
)
@safe pure nothrow @nogc
{
    result = 0;

    if (coordinate == 0 || stride == 0)
        return true;

    if (stride > 0)
    {
        const magnitude = cast(size_t)stride;
        const limit = cast(size_t)ptrdiff_t.max;

        if (coordinate > limit / magnitude)
            return false;

        result =
            cast(ptrdiff_t)(coordinate * magnitude);

        return true;
    }

    const negativeLimit =
        cast(size_t)ptrdiff_t.max + 1;

    const magnitude =
        stride == ptrdiff_t.min
        ? negativeLimit
        : cast(size_t)(-stride);

    if (coordinate > negativeLimit / magnitude)
        return false;

    const product = coordinate * magnitude;

    if (product == negativeLimit)
        result = ptrdiff_t.min;
    else
        result = -cast(ptrdiff_t)product;

    return true;
}


private
bool checkedAddPtrdiff(
    ptrdiff_t left,
    ptrdiff_t right,
    out ptrdiff_t result
)
@safe pure nothrow @nogc
{
    result = 0;

    if (
        right > 0
        && left > ptrdiff_t.max - right
    )
        return false;

    if (
        right < 0
        && left < ptrdiff_t.min - right
    )
        return false;

    result = left + right;
    return true;
}


private
size_t ptrdiffMagnitude(ptrdiff_t value)
@safe pure nothrow @nogc
{
    if (value >= 0)
        return cast(size_t)value;

    if (value == ptrdiff_t.min)
        return cast(size_t)ptrdiff_t.max + 1;

    return cast(size_t)(-value);
}


private
bool checkedOffsetBytes(
    ptrdiff_t elementOffset,
    size_t sampleSize,
    out size_t byteMagnitude
)
@safe pure nothrow @nogc
{
    byteMagnitude = 0;

    if (sampleSize == 0)
        return false;

    const magnitude =
        ptrdiffMagnitude(elementOffset);

    if (magnitude > size_t.max / sampleSize)
        return false;

    byteMagnitude = magnitude * sampleSize;
    return true;
}


private
bool checkedAxisOffsetsZeroOrigin(
    size_t extent,
    ptrdiff_t stride,
    out ptrdiff_t minimum,
    out ptrdiff_t maximum
)
@safe pure nothrow @nogc
{
    minimum = 0;
    maximum = 0;

    if (extent == 0)
        return false;

    ptrdiff_t lastOffset;

    if (
        !checkedCoordinateStride(
            extent - 1,
            stride,
            lastOffset
        )
    )
        return false;

    if (lastOffset < 0)
        minimum = lastOffset;
    else
        maximum = lastOffset;

    return true;
}


private
bool checkedAddressFromElementOffset(
    size_t base,
    ptrdiff_t elementOffset,
    size_t sampleSize,
    out size_t address
)
@safe pure nothrow @nogc
{
    address = 0;

    size_t byteMagnitude;

    if (
        !checkedOffsetBytes(
            elementOffset,
            sampleSize,
            byteMagnitude
        )
    )
        return false;

    if (elementOffset < 0)
    {
        if (byteMagnitude > base)
            return false;

        address = base - byteMagnitude;
        return true;
    }

    if (byteMagnitude > size_t.max - base)
        return false;

    address = base + byteMagnitude;
    return true;
}


private
Bound checkedAffineBound(Rect rect, size_t sampleSize)
@safe pure nothrow @nogc
{
    if (
        rect.width == 0
        || rect.height == 0
        || sampleSize == 0
    )
        return Bound.init;

    ptrdiff_t xMinimum;
    ptrdiff_t xMaximum;

    if (
        !checkedAxisOffsetsZeroOrigin(
            rect.width,
            rect.sampleStride,
            xMinimum,
            xMaximum
        )
    )
        return Bound.init;

    ptrdiff_t yMinimum;
    ptrdiff_t yMaximum;

    if (
        !checkedAxisOffsetsZeroOrigin(
            rect.height,
            rect.rowStride,
            yMinimum,
            yMaximum
        )
    )
        return Bound.init;

    ptrdiff_t minimumOffset;
    ptrdiff_t maximumOffset;

    if (
        !checkedAddPtrdiff(
            xMinimum,
            yMinimum,
            minimumOffset
        )
        ||
        !checkedAddPtrdiff(
            xMaximum,
            yMaximum,
            maximumOffset
        )
    )
        return Bound.init;

    size_t lower;
    size_t upperSample;

    if (
        !checkedAddressFromElementOffset(
            rect.base,
            minimumOffset,
            sampleSize,
            lower
        )
        ||
        !checkedAddressFromElementOffset(
            rect.base,
            maximumOffset,
            sampleSize,
            upperSample
        )
    )
        return Bound.init;

    if (upperSample < lower)
        return Bound.init;

    if (sampleSize > size_t.max - upperSample)
        return Bound.init;

    const upperEnd =
        upperSample + sampleSize;

    return Bound(
        lower,
        upperEnd - lower,
        true
    );
}


private
bool checkedFastRejectDisjoint(
    Rect a,
    Rect b,
    size_t sampleSize
)
@safe pure nothrow @nogc
{
    if (
        a.width == 0 || a.height == 0
        || b.width == 0 || b.height == 0
    )
        return true;

    const ab = checkedAffineBound(a, sampleSize);
    const bb = checkedAffineBound(b, sampleSize);

    return ab.valid && bb.valid && boundsDisjoint(ab, bb);
}


private
bool checkedSampleStart(
    Rect rect,
    size_t x,
    size_t y,
    size_t sampleSize,
    out size_t start
)
@safe pure nothrow @nogc
{
    start = 0;

    ptrdiff_t xOffset;
    ptrdiff_t yOffset;
    ptrdiff_t elementOffset;

    if (
        !checkedCoordinateStride(
            x,
            rect.sampleStride,
            xOffset
        )
        ||
        !checkedCoordinateStride(
            y,
            rect.rowStride,
            yOffset
        )
        ||
        !checkedAddPtrdiff(
            xOffset,
            yOffset,
            elementOffset
        )
        ||
        !checkedAddressFromElementOffset(
            rect.base,
            elementOffset,
            sampleSize,
            start
        )
    )
        return false;

    return sampleSize <= size_t.max - start;
}


private
bool checkedDirectOverlap(
    Rect a,
    Rect b,
    size_t sampleSize,
    out bool overlap
)
@safe pure nothrow @nogc
{
    overlap = false;

    if (sampleSize == 0)
        return false;

    if (
        a.width == 0 || a.height == 0
        || b.width == 0 || b.height == 0
    )
        return true;

    foreach (ay; 0 .. a.height)
    foreach (ax; 0 .. a.width)
    {
        size_t aStart;

        if (
            !checkedSampleStart(
                a,
                ax,
                ay,
                sampleSize,
                aStart
            )
        )
            return false;

        foreach (by; 0 .. b.height)
        foreach (bx; 0 .. b.width)
        {
            size_t bStart;

            if (
                !checkedSampleStart(
                    b,
                    bx,
                    by,
                    sampleSize,
                    bStart
                )
            )
                return false;

            final switch (
                classifyByteAddressRanges(
                    aStart,
                    sampleSize,
                    bStart,
                    sampleSize
                )
            )
            {
                case PhysicalByteRangeRelation.overlapping:
                    overlap = true;
                    return true;

                case PhysicalByteRangeRelation.nonOverlapping:
                    break;

                case PhysicalByteRangeRelation.unrepresentable:
                    return false;
            }
        }
    }

    return true;
}

private
bool directOverlap(Rect a, Rect b, size_t sampleSize)
@safe pure nothrow @nogc
{
    if (
        a.width == 0 || a.height == 0
        || b.width == 0 || b.height == 0
    )
        return false;

    foreach (ay; 0 .. a.height)
    foreach (ax; 0 .. a.width)
    {
        const long ao =
            cast(long)ay * cast(long)a.rowStride
            + cast(long)ax * cast(long)a.sampleStride;

        const long as =
            cast(long)a.base + ao * cast(long)sampleSize;

        if (as < 0)
            continue;

        foreach (by; 0 .. b.height)
        foreach (bx; 0 .. b.width)
        {
            const long bo =
                cast(long)by * cast(long)b.rowStride
                + cast(long)bx * cast(long)b.sampleStride;

            const long bs =
                cast(long)b.base + bo * cast(long)sampleSize;

            if (bs < 0)
                continue;

            const long distance =
                as <= bs ? bs - as : as - bs;

            if (cast(ulong)distance < sampleSize)
                return true;
        }
    }

    return false;
}

private
uint nextWord(ref uint state)
@safe pure nothrow @nogc
{
    state = state * 1664525U + 1013904223U;
    return state;
}

private
ptrdiff_t generatedStride(ref uint state)
@safe pure nothrow @nogc
{
    immutable ptrdiff_t[11] values =
        [-8,-5,-3,-2,-1,0,1,2,3,5,8];

    return values[nextWord(state) % values.length];
}

private
int systematicCorrectness()
{
    enum size_t caseCount = 100_000;

    size_t fastRejects;
    size_t overlappingBoundsButDisjoint;
    size_t exactMismatches;

    immutable size_t[4] sampleSizes = [1,2,4,8];
    immutable long[11] deltas =
        [-31,-17,-9,-5,-1,0,1,3,7,15,33];

    uint state = 0x9e3779b9U;

    foreach (caseIndex; 0 .. caseCount)
    {
        const sampleSize =
            sampleSizes[nextWord(state) % sampleSizes.length];

        const aw = cast(size_t)(nextWord(state) % 6);
        const ah = cast(size_t)(nextWord(state) % 6);
        const bw = cast(size_t)(nextWord(state) % 6);
        const bh = cast(size_t)(nextWord(state) % 6);

        const ars = generatedStride(state);
        const ass = generatedStride(state);
        const brs = generatedStride(state);
        const bss = generatedStride(state);

        const delta =
            deltas[nextWord(state) % deltas.length];

        const long targetBaseLong = 4096L + delta;

        const a = Rect(aw,ah,4096,ars,ass);
        const b = Rect(
            bw,bh,cast(size_t)targetBaseLong,brs,bss
        );

        const overlap =
            directOverlap(a,b,sampleSize);

        const rejected =
            fastRejectDisjoint(a,b,sampleSize);

        if (rejected)
        {
            ++fastRejects;

            if (overlap)
            {
                writeln(
                    "FALSE_DISJOINT case=", caseIndex,
                    " ", a, " ", b,
                    " sampleSize=", sampleSize
                );
                return 1;
            }
        }
        else
        {
            const ab = smallDomainBound(a,sampleSize);
            const bb = smallDomainBound(b,sampleSize);

            if (
                !overlap
                && ab.valid
                && bb.valid
                && !boundsDisjoint(ab,bb)
            )
                ++overlappingBoundsButDisjoint;
        }

        const exact =
            classifySameTypeAffine2DRectanglesByteOverlap(
                a.width,a.height,
                a.base,a.rowStride,a.sampleStride,
                b.width,b.height,
                b.base,b.rowStride,b.sampleStride,
                sampleSize
            );

        if (
            exact != AffineByteOverlapRelation.arithmeticFailure
            && (
                (exact == AffineByteOverlapRelation.overlap)
                != overlap
            )
        )
        {
            ++exactMismatches;
            writeln(
                "EXACT_MISMATCH case=", caseIndex,
                " ", a, " ", b,
                " sampleSize=", sampleSize,
                " exact=", exact,
                " direct=", overlap
            );
            return 1;
        }
    }

    writeln(
        "m3_affine_bounds_correctness PASS cases=", caseCount,
        " fast_rejects=", fastRejects,
        " overlapping_bounds_but_disjoint=",
        overlappingBoundsButDisjoint,
        " exact_mismatches=", exactMismatches
    );

    if (fastRejects == 0 || overlappingBoundsButDisjoint == 0)
        return 1;

    return 0;
}

private
void explicitSparseCounterexample()
{
    /*
     * Same physical bounding interval family, but even/odd sample starts.
     * Bounds overlap; exact sample-byte sets do not.
     */
    const a = Rect(4,1,4096,0,2);
    const b = Rect(4,1,4097,0,2);

    assert(!directOverlap(a,b,1));
    assert(!fastRejectDisjoint(a,b,1));

    const exact =
        classifySameTypeAffine2DRectanglesByteOverlap(
            a.width,a.height,
            a.base,a.rowStride,a.sampleStride,
            b.width,b.height,
            b.base,b.rowStride,b.sampleStride,
            1
        );

    assert(exact == AffineByteOverlapRelation.disjoint);

    writeln("m3_affine_bounds_sparse_counterexample PASS");
}


private
int extremeCheckedCorrectness()
{
    static assert(size_t.sizeof == 8);
    static assert(ptrdiff_t.sizeof == 8);

    struct Fixture
    {
        Rect a;
        Rect b;
        size_t sampleSize;
        bool expectCheckedOracle;
        bool expectFastReject;
        string name;
    }

    const size_t signBit =
        cast(size_t)ptrdiff_t.max + 1;

    const fixtures =
    [
        Fixture(
            Rect(1,1,0,ptrdiff_t.min,ptrdiff_t.max),
            Rect(1,1,size_t.max - 1,ptrdiff_t.max,ptrdiff_t.min),
            1,
            true,
            true,
            "max-valid-address-separation"
        ),
        Fixture(
            Rect(1,1,size_t.max - 8,ptrdiff_t.min,ptrdiff_t.min),
            Rect(1,1,0,ptrdiff_t.max,ptrdiff_t.max),
            8,
            true,
            true,
            "last-representable-eight-byte-sample"
        ),
        Fixture(
            Rect(1,1,size_t.max - 6,0,0),
            Rect(1,1,0,0,0),
            8,
            false,
            false,
            "sample-end-overflow"
        ),
        Fixture(
            Rect(2,1,signBit,0,ptrdiff_t.min),
            Rect(1,1,size_t.max - 1,0,0),
            1,
            true,
            true,
            "ptrdiff-min-negative-reach"
        ),
        Fixture(
            Rect(2,1,0,0,ptrdiff_t.max),
            Rect(1,1,size_t.max - 1,0,0),
            1,
            true,
            true,
            "ptrdiff-max-positive-reach"
        ),
        Fixture(
            Rect(2,2,signBit,ptrdiff_t.min,ptrdiff_t.min),
            Rect(1,1,size_t.max - 1,0,0),
            1,
            false,
            false,
            "combined-minimum-offset-overflow"
        ),
        Fixture(
            Rect(3,1,0,0,ptrdiff_t.max),
            Rect(1,1,size_t.max - 1,0,0),
            1,
            false,
            false,
            "coordinate-stride-overflow"
        ),
        Fixture(
            Rect(2,1,0,0,ptrdiff_t.max),
            Rect(1,1,size_t.max - 1,0,0),
            8,
            false,
            false,
            "offset-byte-overflow"
        ),
        Fixture(
            Rect(2,1,size_t.max - 1,0,-1),
            Rect(1,1,0,0,0),
            1,
            true,
            true,
            "negative-unit-stride-near-max"
        ),
        Fixture(
            Rect(2,1,1,0,-1),
            Rect(2,1,size_t.max - 2,0,1),
            1,
            true,
            true,
            "opposite-address-edges"
        ),
        Fixture(
            Rect(4,1,64,0,2),
            Rect(4,1,65,0,2),
            1,
            true,
            false,
            "overlapping-bounds-sparse-disjoint"
        ),
        Fixture(
            Rect(4,1,64,0,2),
            Rect(4,1,66,0,2),
            1,
            true,
            false,
            "overlapping-bounds-real-overlap"
        )
    ];

    size_t checkedOracleCases;
    size_t conservativeUnknownCases;
    size_t fastRejects;
    size_t exactArithmeticFailures;

    foreach (fixture; fixtures)
    {
        const rejected =
            checkedFastRejectDisjoint(
                fixture.a,
                fixture.b,
                fixture.sampleSize
            );

        if (rejected)
            ++fastRejects;

        if (rejected != fixture.expectFastReject)
        {
            writeln(
                "EXTREME_FAST_REJECT_EXPECTATION_FAIL name=",
                fixture.name,
                " rejected=",
                rejected
            );
            return 1;
        }

        bool directOverlapResult;
        const directKnown =
            checkedDirectOverlap(
                fixture.a,
                fixture.b,
                fixture.sampleSize,
                directOverlapResult
            );

        if (directKnown)
            ++checkedOracleCases;
        else
            ++conservativeUnknownCases;

        if (directKnown != fixture.expectCheckedOracle)
        {
            writeln(
                "EXTREME_ORACLE_EXPECTATION_FAIL name=",
                fixture.name,
                " directKnown=",
                directKnown
            );
            return 1;
        }

        if (rejected && (!directKnown || directOverlapResult))
        {
            writeln(
                "EXTREME_FALSE_DISJOINT name=",
                fixture.name,
                " directKnown=",
                directKnown,
                " directOverlap=",
                directOverlapResult
            );
            return 1;
        }

        const exact =
            classifySameTypeAffine2DRectanglesByteOverlap(
                fixture.a.width,
                fixture.a.height,
                fixture.a.base,
                fixture.a.rowStride,
                fixture.a.sampleStride,
                fixture.b.width,
                fixture.b.height,
                fixture.b.base,
                fixture.b.rowStride,
                fixture.b.sampleStride,
                fixture.sampleSize
            );

        if (exact == AffineByteOverlapRelation.arithmeticFailure)
        {
            ++exactArithmeticFailures;
        }
        else if (
            directKnown
            &&
            (
                (exact == AffineByteOverlapRelation.overlap)
                != directOverlapResult
            )
        )
        {
            writeln(
                "EXTREME_EXACT_MISMATCH name=",
                fixture.name,
                " exact=",
                exact,
                " directOverlap=",
                directOverlapResult
            );
            return 1;
        }

        /*
         * A fast reject is independently sufficient. If the exact classifier
         * can classify the same case, it must agree on disjointness.
         */
        if (
            rejected
            && exact == AffineByteOverlapRelation.overlap
        )
        {
            writeln(
                "EXTREME_FAST_VS_EXACT_MISMATCH name=",
                fixture.name
            );
            return 1;
        }
    }

    writeln(
        "m3_affine_bounds_extreme PASS fixtures=",
        fixtures.length,
        " checked_oracle_cases=",
        checkedOracleCases,
        " conservative_unknown_cases=",
        conservativeUnknownCases,
        " fast_rejects=",
        fastRejects,
        " exact_arithmetic_failures=",
        exactArithmeticFailures
    );

    return 0;
}



private enum size_t perfRepetitions = 7;
private enum size_t fastBatchIterations = 100_000;
private __gshared ulong relationSink;


private
AffineByteOverlapRelation classifyWithCheckedFastReject(
    Rect a,
    Rect b,
    size_t sampleSize
)
@safe pure nothrow @nogc
{
    if (
        checkedFastRejectDisjoint(
            a,
            b,
            sampleSize
        )
    )
    {
        return AffineByteOverlapRelation.disjoint;
    }

    return classifySameTypeAffine2DRectanglesByteOverlap(
        a.width,
        a.height,
        a.base,
        a.rowStride,
        a.sampleStride,
        b.width,
        b.height,
        b.base,
        b.rowStride,
        b.sampleStride,
        sampleSize
    );
}


private
long relationMedian(ref long[perfRepetitions] values)
{
    auto copy = values;
    sort(copy[]);
    return copy[copy.length / 2];
}


private
long measureRelation(scope void delegate() operation)
{
    const start = MonoTime.currTime;
    operation();
    return (MonoTime.currTime - start).total!"nsecs";
}


private
void consumeRelation(AffineByteOverlapRelation relation)
@trusted nothrow @nogc
{
    relationSink =
        relationSink * 0x100000001b3UL
        ^ cast(ulong)relation
        ^ 0x9e3779b97f4a7c15UL;
}


private
int runRelationPerfCase(
    size_t sourceWidth,
    size_t sourceHeight,
    size_t targetWidth,
    size_t targetHeight,
    size_t pitch
)
{
    const sourceElements =
        pitch * sourceHeight;

    const targetElements =
        pitch * targetHeight;

    auto sourceStorage =
        new float[sourceElements];

    auto targetStorage =
        new float[targetElements + 1];

    const source =
        Rect(
            sourceWidth,
            sourceHeight,
            cast(size_t)sourceStorage.ptr,
            cast(ptrdiff_t)pitch,
            1
        );

    const target =
        Rect(
            targetWidth,
            targetHeight,
            cast(size_t)targetStorage.ptr,
            cast(ptrdiff_t)pitch,
            1
        );

    const checkedSource =
        checkedAffineBound(
            source,
            float.sizeof
        );

    const checkedTarget =
        checkedAffineBound(
            target,
            float.sizeof
        );

    if (
        !checkedSource.valid
        || !checkedTarget.valid
        || !boundsDisjoint(
            checkedSource,
            checkedTarget
        )
    )
    {
        writeln(
            "RELATION_PERF_SETUP_FAIL ",
            source,
            " ",
            target
        );
        return 1;
    }

    foreach (_; 0 .. 2)
    {
        const exact =
            classifySameTypeAffine2DRectanglesByteOverlap(
                source.width,
                source.height,
                source.base,
                source.rowStride,
                source.sampleStride,
                target.width,
                target.height,
                target.base,
                target.rowStride,
                target.sampleStride,
                float.sizeof
            );

        const fast =
            classifyWithCheckedFastReject(
                source,
                target,
                float.sizeof
            );

        if (
            exact != AffineByteOverlapRelation.disjoint
            || fast != exact
        )
            return 1;

        consumeRelation(exact);
        consumeRelation(fast);
    }

    long[perfRepetitions] exactTimes;
    long[perfRepetitions] fastTimes;

    bool ok = true;

    foreach (r; 0 .. perfRepetitions)
    {
        if ((r & 1) == 0)
        {
            exactTimes[r] = measureRelation({
                const relation =
                    classifySameTypeAffine2DRectanglesByteOverlap(
                        source.width,
                        source.height,
                        source.base,
                        source.rowStride,
                        source.sampleStride,
                        target.width,
                        target.height,
                        target.base,
                        target.rowStride,
                        target.sampleStride,
                        float.sizeof
                    );

                ok =
                    ok
                    && relation
                        == AffineByteOverlapRelation.disjoint;

                consumeRelation(relation);
            });

            fastTimes[r] = measureRelation({
                const relation =
                    classifyWithCheckedFastReject(
                        source,
                        target,
                        float.sizeof
                    );

                ok =
                    ok
                    && relation
                        == AffineByteOverlapRelation.disjoint;

                consumeRelation(relation);
            });
        }
        else
        {
            fastTimes[r] = measureRelation({
                const relation =
                    classifyWithCheckedFastReject(
                        source,
                        target,
                        float.sizeof
                    );

                ok =
                    ok
                    && relation
                        == AffineByteOverlapRelation.disjoint;

                consumeRelation(relation);
            });

            exactTimes[r] = measureRelation({
                const relation =
                    classifySameTypeAffine2DRectanglesByteOverlap(
                        source.width,
                        source.height,
                        source.base,
                        source.rowStride,
                        source.sampleStride,
                        target.width,
                        target.height,
                        target.base,
                        target.rowStride,
                        target.sampleStride,
                        float.sizeof
                    );

                ok =
                    ok
                    && relation
                        == AffineByteOverlapRelation.disjoint;

                consumeRelation(relation);
            });
        }
    }

    if (!ok)
        return 1;

    const exactMedian =
        relationMedian(exactTimes);

    const fastMedian =
        relationMedian(fastTimes);

    long[perfRepetitions] fastBatchTimes;
    bool batchOk = true;

    foreach (r; 0 .. perfRepetitions)
    {
        fastBatchTimes[r] = measureRelation({
            foreach (i; 0 .. fastBatchIterations)
            {
                Rect variedTarget = target;

                variedTarget.base +=
                    cast(size_t)(i & 1)
                    * float.sizeof;

                const relation =
                    classifyWithCheckedFastReject(
                        source,
                        variedTarget,
                        float.sizeof
                    );

                batchOk =
                    batchOk
                    && relation
                        == AffineByteOverlapRelation.disjoint;

                consumeRelation(relation);
            }
        });
    }

    if (!batchOk)
        return 1;

    const fastBatchMedian =
        relationMedian(fastBatchTimes);

    const fastBatchPerCall =
        cast(double)fastBatchMedian
        / cast(double)fastBatchIterations;

    writefln(
        "m3_affine_bounds_perf source=%sx%s target=%sx%s pitch=%s exact_ns=%s fast_single_ns=%s fast_batch_ns=%s fast_batch_per_call_ns=%.3f exact_over_batch_per_call=%.3f sink=%s",
        sourceWidth,
        sourceHeight,
        targetWidth,
        targetHeight,
        pitch,
        exactMedian,
        fastMedian,
        fastBatchMedian,
        fastBatchPerCall,
        cast(double)exactMedian
            / fastBatchPerCall,
        relationSink
    );

    writefln(
        "m3_affine_bounds_perf_raw source=%sx%s target=%sx%s exact=%(%s,%) fast_single=%(%s,%) fast_batch=%(%s,%)",
        sourceWidth,
        sourceHeight,
        targetWidth,
        targetHeight,
        exactTimes,
        fastTimes,
        fastBatchTimes
    );

    return 0;
}


private
int relationPerformance()
{
    if (
        runRelationPerfCase(
            128,
            64,
            128,
            64,
            192
        ) != 0
    )
        return 1;

    if (
        runRelationPerfCase(
            512,
            256,
            512,
            256,
            640
        ) != 0
    )
        return 1;

    if (
        runRelationPerfCase(
            2048,
            512,
            2048,
            512,
            2304
        ) != 0
    )
        return 1;

    /*
     * Neighbourhood-shaped relation:
     *
     * source dependency has a one-sample halo around the target shape.
     */
    if (
        runRelationPerfCase(
            2050,
            514,
            2048,
            512,
            2304
        ) != 0
    )
        return 1;

    return 0;
}


int runAffineBoundsProbe()
{
    explicitSparseCounterexample();

    if (systematicCorrectness() != 0)
        return 1;

    if (extremeCheckedCorrectness() != 0)
        return 1;

    if (relationPerformance() != 0)
        return 1;

    return 0;
}
