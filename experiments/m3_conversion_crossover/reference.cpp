// Already-approved execution reference, not a public validation API.
#include <cstddef>
#include <cstdint>
extern "C" void cppApprovedConversion(const std::uint8_t* __restrict src,
    float* __restrict dst, std::ptrdiff_t sr, std::ptrdiff_t sx,
    std::ptrdiff_t dr, std::ptrdiff_t dx, std::size_t width, std::size_t height) noexcept
{
    if (!width || !height) return;
    if (sx == 1 && dx == 1 && sr == static_cast<std::ptrdiff_t>(width)
        && dr == static_cast<std::ptrdiff_t>(width)) {
        for (std::size_t i=0; i<width*height; ++i) dst[i]=static_cast<float>(src[i]);
        return;
    }
    for (std::size_t y=0; y<height; ++y) {
        const auto* s=src+static_cast<std::ptrdiff_t>(y)*sr;
        auto* d=dst+static_cast<std::ptrdiff_t>(y)*dr;
        if (sx == 1 && dx == 1) {
            for (std::size_t x=0; x<width; ++x) d[x]=static_cast<float>(s[x]);
        } else {
            for (std::size_t x=0; x<width; ++x)
                d[static_cast<std::ptrdiff_t>(x)*dx]=
                    static_cast<float>(s[static_cast<std::ptrdiff_t>(x)*sx]);
        }
    }
}
