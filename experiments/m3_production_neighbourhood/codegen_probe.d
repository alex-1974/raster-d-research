module m3_neighbourhood_codegen_probe;

@safe
pure
nothrow
@nogc
float m3Kernel(ref const(float)[9] n)
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

pragma(inline, false)
private
void m3RowNoInline(
    scope const(float)* row0,
    scope const(float)* row1,
    scope const(float)* row2,
    scope float* destinationRow,
    size_t width
)
@trusted
pure
nothrow
@nogc
{
    foreach (x; 0 .. width)
    {
        float[9] n =
        [
            row0[x], row0[x + 1], row0[x + 2],
            row1[x], row1[x + 1], row1[x + 2],
            row2[x], row2[x + 1], row2[x + 2]
        ];

        destinationRow[x] = m3Kernel(n);
    }
}

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
    foreach (y; 0 .. height)
    {
        const centerRow =
            sourceBase
            + cast(ptrdiff_t)(y + 1) * sourceRowStride
            + 1;

        const row0 = centerRow - sourceRowStride - 1;
        const row1 = centerRow - 1;
        const row2 = centerRow + sourceRowStride - 1;

        auto destinationRow =
            destinationBase
            + cast(ptrdiff_t)y * destinationRowStride;

        foreach (x; 0 .. width)
        {
            float[9] n =
            [
                row0[x], row0[x + 1], row0[x + 2],
                row1[x], row1[x + 1], row1[x + 2],
                row2[x], row2[x + 1], row2[x + 2]
            ];

            destinationRow[x] = m3Kernel(n);
        }
    }
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
    foreach (y; 0 .. height)
    {
        const centerRow =
            sourceBase
            + cast(ptrdiff_t)(y + 1) * sourceRowStride
            + 1;

        const row0 = centerRow - sourceRowStride - 1;
        const row1 = centerRow - 1;
        const row2 = centerRow + sourceRowStride - 1;

        auto destinationRow =
            destinationBase
            + cast(ptrdiff_t)y * destinationRowStride;

        m3RowNoInline(
            row0,
            row1,
            row2,
            destinationRow,
            width
        );
    }
}
