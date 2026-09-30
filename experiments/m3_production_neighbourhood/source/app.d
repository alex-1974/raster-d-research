module app;

import raster.research.m3_production_neighbourhood.candidate :
    runBenchmarkMatrix;

void main()
{
    assert(runBenchmarkMatrix() == 0);
}
