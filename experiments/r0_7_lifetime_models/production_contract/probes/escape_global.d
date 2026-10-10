module escape_global;
import raster : RasterLease, RasterView;
RasterView!ubyte leaked;
@safe void escape(ref RasterLease!ubyte lease) {
    leaked = lease.view();
}
