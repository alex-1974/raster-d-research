import core.stdc.stdlib : malloc;
import core.time : MonoTime;
import std.stdio : writeln;
import raster;

enum size_t width = 256, height = 128, stride = 320;
enum size_t trials = 7, operations = 4_000;
private __gshared ulong observed;

@system RasterLease!ubyte createLease() {
    void* raw = malloc(stride * height);
    assert(raw !is null);
    auto bytes = (cast(ubyte*) raw)[0 .. stride * height];
    foreach (i; 0 .. bytes.length) bytes[i] = cast(ubyte)((i * 37 + 11) & 255);
    OwnedByteResource resource;
    assert(tryAdoptMallocResource(raw, bytes.length, resource));
    const PlaneByteLayout[1] planes = [PlaneByteLayout(0, stride, 1)];
    RasterLease!ubyte lease;
    const result = tryImportOwnedRaster!ubyte(
        resource, planes[], Region2D(0, 0, width, height), lease);
    assert(result.ok);
    return lease;
}

@system ulong sampleRoi(ref RasterLease!ubyte lease, size_t offset) {
    scope auto view = lease.view();
    bool ok;
    scope auto roi = view.tryRoi(Region2D(offset, 7, 32, 24), ok);
    assert(ok);
    ulong result;
    foreach (y; 0 .. 24)
        foreach (x; 0 .. 32) {
            ubyte value;
            assert(roi.trySample(0, x, y, value));
            result += value;
        }
    return result;
}

@system void main() {
    auto lease = createLease();
    assert(sampleRoi(lease, 5) != 0);
    writeln("trial,case,ns_per_operation,checksum");
    foreach (trial; 0 .. trials) {
        foreach (slot; 0 .. 3) {
            const kind = (trial + slot) % 3;
            ulong checksum;
            auto start = MonoTime.currTime;
            foreach (i; 0 .. operations) {
                const offset = 1 + (i % 13);
                if (kind == 0) {
                    scope auto borrowed = lease.view();
                    bool ok;
                    scope auto roi = borrowed.tryRoi(Region2D(offset, 7, 32, 24), ok);
                    assert(ok);
                    ubyte sample;
                    assert(roi.trySample(0, i % 32, i % 24, sample));
                    checksum += sample;
                } else if (kind == 1) {
                    auto retained = lease;
                    checksum += sampleRoi(retained, offset);
                } else {
                    checksum += sampleRoi(lease, offset);
                }
            }
            observed = checksum;
            const elapsed = MonoTime.currTime - start;
            const label = kind == 0 ? "borrow_roi_sample" :
                kind == 1 ? "retained_copy_roi_sum" : "borrow_roi_sum";
            writeln(trial, ",", label, ",",
                cast(double) elapsed.total!"nsecs" / operations, ",", checksum);
        }
    }
}
