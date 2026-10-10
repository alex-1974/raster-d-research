module escape_return;
import raster.backing : RasterLease;
import raster.view : RasterView;
import raster.region : Region2D;
@safe RasterView!ubyte escape(ref RasterLease!ubyte lease) {
    return lease.view();
}
