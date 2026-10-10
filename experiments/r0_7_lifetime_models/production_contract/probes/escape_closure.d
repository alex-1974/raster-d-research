module escape_closure;
import raster : RasterLease, RasterView;
RasterView!ubyte delegate() leaked;
@safe void escape(ref RasterLease!ubyte lease) {
    scope auto v = lease.view();
    leaked = () @safe { return v; };
}
