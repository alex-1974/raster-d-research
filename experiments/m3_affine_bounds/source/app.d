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

int main()
{
    explicitSparseCounterexample();

    if (systematicCorrectness() != 0)
        return 1;

    return 0;
}
