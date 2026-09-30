module raster.research.m3_affine_consumer.relation;

import raster.internal.affine_relation : AffineByteOverlapRelation;
import raster.research.m3_affine_bounds.candidate :
    Rect, checkedFastRejectDisjoint, classifyWithCheckedFastReject;

package(raster)
AffineByteOverlapRelation classifyRectangles(
    size_t aw, size_t ah, size_t abase, ptrdiff_t ar, ptrdiff_t ax,
    size_t bw, size_t bh, size_t bbase, ptrdiff_t br, ptrdiff_t bx,
    size_t sampleSize)
@safe pure nothrow @nogc
{
    return classifyWithCheckedFastReject(
        Rect(aw, ah, abase, ar, ax), Rect(bw, bh, bbase, br, bx), sampleSize);
}

package(raster)
AffineByteOverlapRelation classifyEqual(
    size_t w, size_t h, size_t abase, ptrdiff_t ar, ptrdiff_t ax,
    size_t bbase, ptrdiff_t br, ptrdiff_t bx, size_t sampleSize)
@safe pure nothrow @nogc
{
    return classifyRectangles(w, h, abase, ar, ax, w, h, bbase, br, bx, sampleSize);
}

unittest
{
    import raster.internal.affine_relation : classifySameTypeAffine2DRectanglesByteOverlap;
    // Sparse overlapping envelopes MUST reach exact disjointness.
    auto a = Rect(3, 2, 100, 12, 2);
    auto b = Rect(3, 2, 104, 12, 2);
    assert(!checkedFastRejectDisjoint(a, b, 4));
    assert(classifyWithCheckedFastReject(a, b, 4) == AffineByteOverlapRelation.disjoint);
    b.base = a.base;
    assert(!checkedFastRejectDisjoint(a, b, 4));
    assert(classifyWithCheckedFastReject(a, b, 4) == AffineByteOverlapRelation.overlap);
    // Unrepresentable half-open endpoint: preserve exact algebraic relation.
    a = Rect(1, 1, size_t.max, 0, 0);
    b = Rect(1, 1, 0, 0, 0);
    assert(!checkedFastRejectDisjoint(a, b, 1));
    assert(classifyWithCheckedFastReject(a, b, 1) ==
        classifySameTypeAffine2DRectanglesByteOverlap(
            a.width,a.height,a.base,a.rowStride,a.sampleStride,
            b.width,b.height,b.base,b.rowStride,b.sampleStride,1));
    // Invalid algebraic sample size preserves arithmeticFailure. This is a
    // relation-only fixture, not fabricated backing for a raster consumer.
    assert(!checkedFastRejectDisjoint(a, b, 0));
    assert(classifyWithCheckedFastReject(a, b, 0) == AffineByteOverlapRelation.arithmeticFailure);
}
