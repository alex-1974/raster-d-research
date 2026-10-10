module positive;
import raster.backing : RasterLease;
import raster.view : RasterView;
import raster.region : Region2D;
@safe void check(ref RasterLease!ubyte lease) {
    scope auto v = lease.view();
    bool ok;
    scope auto child = v.tryRoi(Region2D(0, 0, 0, 0), ok);
    ubyte value;
    child.trySample(0, 0, 0, value);
    auto retained = lease;
    scope auto second = retained.view();
    assert(second.planeCount == v.planeCount);
}
