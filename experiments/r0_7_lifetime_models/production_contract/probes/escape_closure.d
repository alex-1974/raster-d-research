module escape_closure;
import raster.backing : RasterLease;
import raster.view : RasterView;
import raster.region : Region2D;
RasterView!ubyte delegate() leaked;
@safe void escape(ref RasterLease!ubyte lease) {
    scope auto v = lease.view();
    leaked = () @safe { return v; };
}
