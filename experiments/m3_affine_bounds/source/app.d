module app;

import std.stdio : writeln;

import raster.internal.affine_relation :
    AffineByteOverlapRelation,
    classifySameTypeAffine2DRectanglesByteOverlap;

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
int systematicCorrectness()
{
    size_t cases;
    size_t fastRejects;
    size_t overlappingBoundsButDisjoint;
    size_t exactMismatches;

    const ptrdiff_t[] strides =
        [-8,-5,-3,-2,-1,0,1,2,3,5,8];

    const size_t[] sampleSizes = [1,2,4,8];

    foreach (sampleSize; sampleSizes)
    foreach (aw; 0 .. 6)
    foreach (ah; 0 .. 6)
    foreach (bw; 0 .. 6)
    foreach (bh; 0 .. 6)
    foreach (ars; strides)
    foreach (ass; strides)
    foreach (brs; strides)
    foreach (bss; strides)
    {
        /*
         * Keep the systematic domain finite but vary relative base placement
         * across exact equality, nearby/interleaved and clearly separate
         * positions.
         */
        foreach (delta; [-31L,-17L,-9L,-5L,-1L,0L,1L,3L,7L,15L,33L])
        {
            const long targetBaseLong = 4096L + delta;
            if (targetBaseLong < 0)
                continue;

            const a = Rect(aw,ah,4096,ars,ass);
            const b = Rect(
                bw,bh,cast(size_t)targetBaseLong,brs,bss
            );

            const overlap =
                directOverlap(a,b,sampleSize);

            const rejected =
                fastRejectDisjoint(a,b,sampleSize);

            ++cases;

            if (rejected)
            {
                ++fastRejects;

                if (overlap)
                {
                    writeln(
                        "FALSE_DISJOINT ",
                        a, " ", b,
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
                    "EXACT_MISMATCH ",
                    a, " ", b,
                    " sampleSize=", sampleSize,
                    " exact=", exact,
                    " direct=", overlap
                );
                return 1;
            }
        }
    }

    writeln(
        "m3_affine_bounds_correctness PASS cases=", cases,
        " fast_rejects=", fastRejects,
        " overlapping_bounds_but_disjoint=",
        overlappingBoundsButDisjoint,
        " exact_mismatches=", exactMismatches
    );

    if (overlappingBoundsButDisjoint == 0)
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

int main()
{
    explicitSparseCounterexample();

    if (systematicCorrectness() != 0)
        return 1;

    return 0;
}
