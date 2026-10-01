#include <cstddef>
#include <cstring>
// Execution-only: caller proves validated reachable geometry, matching shape,
// injective destination and disjoint sample bytes. No validation/retention,
// restrict, allocation or LTO. Copy preserves every representation byte.
extern "C" void cppCopy(const unsigned char* s,std::ptrdiff_t sr,
    std::ptrdiff_t sx,unsigned char* d,std::ptrdiff_t dr,std::ptrdiff_t dx,
    std::size_t w,std::size_t h,std::size_t bytes) noexcept {
    for(std::size_t y=0;y<h;++y){
        const auto* row=s+static_cast<std::ptrdiff_t>(y)*sr;
        auto* dst=d+static_cast<std::ptrdiff_t>(y)*dr;
        if(sx==static_cast<std::ptrdiff_t>(bytes) && dx==sx)
            std::memcpy(dst,row,w*bytes);
        else for(std::size_t x=0;x<w;++x)
            std::memcpy(dst+static_cast<std::ptrdiff_t>(x)*dx,
                row+static_cast<std::ptrdiff_t>(x)*sx,bytes);
    }
}
extern "C" void cppConvert(const unsigned char* s,std::ptrdiff_t sr,
    std::ptrdiff_t sx,float* d,std::ptrdiff_t dr,std::ptrdiff_t dx,
    std::size_t w,std::size_t h) noexcept {
    for(std::size_t y=0;y<h;++y){
        const auto* row=s+static_cast<std::ptrdiff_t>(y)*sr;
        auto* dst=d+static_cast<std::ptrdiff_t>(y)*dr;
        for(std::size_t x=0;x<w;++x)
            dst[static_cast<std::ptrdiff_t>(x)*dx]=static_cast<float>(row[static_cast<std::ptrdiff_t>(x)*sx]);
    }
}
