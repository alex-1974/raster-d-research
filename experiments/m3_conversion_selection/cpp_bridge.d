// Fixture-only bridge. All calls use separately allocated, disjoint live
// arrays. Geometry corners and complete indexed oracles are checked before
// timing. Matrix dimensions/strides are bounded, so ptrdiff_t math cannot
// overflow. The external reference accesses exactly these affine samples,
// preserves source, and stores/escapes no pointer. No Production trust added.
extern(C) void cppApprovedConversion(scope const(ubyte)* src, scope float* dst,
    ptrdiff_t sr, ptrdiff_t sx, ptrdiff_t dr, ptrdiff_t dx,
    size_t width, size_t height) @system nothrow @nogc;
private void cppFixture(scope const(ubyte)[] src, scope float[] dst,
    size_t so, size_t targetOffset, ptrdiff_t sr, ptrdiff_t sx,
    ptrdiff_t dr, ptrdiff_t dx, size_t width, size_t height)
    @trusted nothrow @nogc
{
    cppApprovedConversion(src.ptr+so,dst.ptr+targetOffset,sr,sx,dr,dx,width,height);
}
