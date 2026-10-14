module negative_borrow_escape;
import raster;

// Explicit -preview=dip1000 compile-only negative.
RasterView!ubyte forbidden() @safe
{
    RasterLease!ubyte local;
    return local.view();
}
