module positive_import;
import raster;

void inspect(ref RasterLease!ubyte lease) @safe
{
    scope auto view = lease.view();
    auto n = view.planeCount;
    assert(n <= size_t.max);
}
