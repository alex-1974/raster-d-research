module negative_has_backing;
import raster;

bool forbidden(ref RasterLease!ubyte lease) @safe
{
    return lease.hasBacking;
}
