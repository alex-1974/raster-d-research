module negative_physical_bytes;
import raster;

bool forbidden(ref RasterLease!ubyte lease) @safe
{
    size_t bytes;
    return lease.tryPhysicalResourceBytes(bytes);
}
