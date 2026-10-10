#include <chrono>
#include <cstdint>
#include <cstdio>
#include <vector>
int main(){constexpr int stride=320, rows=128, repeat=4000;
std::vector<unsigned char> p(stride*rows);
for(int i=0;i<stride*rows;++i)p[i]=(i*37+11)&255;
for(int t=0;t<7;++t){unsigned long long sum=0;
auto start=std::chrono::steady_clock::now();
for(int i=0;i<repeat;++i){int x0=1+i%13;
for(int y=0;y<24;++y)for(int x=0;x<32;++x)sum+=p[(7+y)*stride+x0+x];}
auto ns=std::chrono::duration_cast<std::chrono::nanoseconds>(std::chrono::steady_clock::now()-start).count();
std::printf("%d,cpp_roi_sum,%.6f,%llu\n",t,double(ns)/repeat,sum);}
}
