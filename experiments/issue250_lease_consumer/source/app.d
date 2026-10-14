module app;

// Independent DUB consumer; uses only raster-d v0.2.0 public exports.
import raster;
import core.stdc.stdlib : malloc;
import std.algorithm.mutation : move;
import std.stdio : writeln;

private void check(bool ok, string why) @safe
{
    if (!ok)
        throw new Exception(why);
}

private void checkSample(
    ref RasterLease!ubyte lease, size_t x, size_t y, ubyte expected
) @safe
{
    scope auto borrowed = lease.view();
    check(borrowed.planeCount == 1, "missing plane");
    ubyte observed = 0;
    check(borrowed.trySample(0, x, y, observed), "sample failed");
    check(observed == expected, "sample mismatch");
}

void main() @system
{
    RasterLease!ubyte empty;
    {
        scope auto emptyView = empty.view();
        check(emptyView.planeCount == 0, ".init view was nonempty");
    }

    void* allocation = malloc(4);
    check(allocation !is null, "malloc failed");
    auto bytes = (cast(ubyte*) allocation)[0 .. 4];
    bytes[] = [11, 22, 33, 44];

    OwnedByteResource resource;
    check(tryAdoptMallocResource(allocation, 4, resource), "adoption failed");
    check(resource.ownsResource, "adoption did not arm resource");

    const PlaneByteLayout[1] planes = [PlaneByteLayout(0, 2, 1)];
    RasterLease!ubyte cache;
    auto imported = tryImportOwnedRaster!ubyte(
        resource, planes[], Region2D(0, 0, 2, 2), cache
    );
    check(imported.ok, "owned raster import failed");
    check(
        imported.resourceDisposition ==
            OwnedRasterResourceDisposition.transferredToLease,
        "wrong import resource disposition"
    );
    check(!resource.ownsResource, "ownership did not move into lease");
    checkSample(cache, 1, 1, 44);

    RasterLease!ubyte subscriber = cache;
    checkSample(subscriber, 0, 0, 11);
    cache = RasterLease!ubyte.init;
    {
        scope auto noCacheView = cache.view();
        check(noCacheView.planeCount == 0, "evicted cache remains live");
    }
    checkSample(subscriber, 1, 0, 22);

    RasterLease!ubyte second = subscriber;
    subscriber = RasterLease!ubyte.init;
    checkSample(second, 0, 1, 33);

    auto survivor = move(second);
    {
        scope auto movedFromView = second.view();
        check(movedFromView.planeCount == 0, "moved-from lease remains live");
    }
    checkSample(survivor, 1, 1, 44);

    // Last known handle disappears here. The public API cannot observe
    // the physical final-release event. Do not claim that this tests one.
    survivor = RasterLease!ubyte.init;
    writeln("PASS: public lease copy, move, borrow and eviction semantics");
    writeln("LIMITATION: no last-physical-release observation");
}
