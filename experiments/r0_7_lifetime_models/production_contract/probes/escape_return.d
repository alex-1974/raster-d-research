module escape_return;
import raster : RasterLease, RasterView;
@safe RasterView!ubyte escape(ref RasterLease!ubyte lease) {
    return lease.view();
}
