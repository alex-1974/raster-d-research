#include <cstddef>
// Already-validated resident descriptor, matching plane failure/out-zero and
// empty semantics. No restrict, fast-math, reassociation or independent lanes.
extern "C" bool cppStrict(const float* base, std::ptrdiff_t sr, std::ptrdiff_t sx,
    std::size_t width, std::size_t height, std::size_t planes,
    std::size_t planeIndex, double* output) noexcept
{
    *output=0.0;
    if (planeIndex>=planes) return false;
    if (width==0 || height==0) return true;
    double total=0.0;
    for (std::size_t y=0;y<height;++y) {
        const float* row=base+static_cast<std::ptrdiff_t>(y)*sr;
        for (std::size_t x=0;x<width;++x)
            total += static_cast<double>(row[static_cast<std::ptrdiff_t>(x)*sx]);
    }
    *output=total;
    return true;
}
