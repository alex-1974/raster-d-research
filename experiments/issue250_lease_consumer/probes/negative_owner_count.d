module negative_owner_count;
import raster;

size_t forbidden(ref RasterLease!ubyte lease) @safe
{
    return lease.owner_.control_.referenceCount;
}
