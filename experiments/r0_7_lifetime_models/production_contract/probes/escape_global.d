module escape_global;
import raster.backing : RasterLease;
import raster.view : RasterView;
import raster.region : Region2D;
RasterView!ubyte leaked;
@safe void escape(ref RasterLease!ubyte lease) {
    leaked = lease.view();
}
