#include <chrono>
#include <cstdint>
#include <cstdio>
#include <limits>
#include <vector>

// Matches raster-d sum!ulong's per-sample checked unsigned accumulation.
// Reuses the same 256x128 padded bytes and varying 32x24 ROI.
int main() {
    constexpr int stride=320, rows=128, repeat=4000;
    std::vector<unsigned char> pixels(stride*rows);
    for (int i=0;i<stride*rows;++i) pixels[i]=(i*37+11)&255;
    for(int t=0;t<7;++t) {
        unsigned long long checksum=0;
        bool overflow=false;
        const auto start=std::chrono::steady_clock::now();
        for(int i=0;i<repeat;++i) {
            const int x0=1+i%13;
            std::uint64_t value=0;
            for(int y=0;y<24&&!overflow;++y) {
                for(int x=0;x<32;++x) {
                    const std::uint64_t sample=pixels[(7+y)*stride+x0+x];
                    if(sample>std::numeric_limits<std::uint64_t>::max()-value) {
                        overflow=true; break;
                    }
                    value+=sample;
                }
            }
            if(overflow) break;
            checksum+=value;
        }
        const auto ns=std::chrono::duration_cast<std::chrono::nanoseconds>(
            std::chrono::steady_clock::now()-start).count();
        std::printf("%d,cpp_checked_roi_sum,%.6f,%llu,%d\n",
            t,double(ns)/repeat,checksum,int(overflow));
    }
}
