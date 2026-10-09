module descriptor_benchmark;

import core.time : MonoTime;
import core.lifetime : move;
import std.stdio : writeln;
import retained_malloc : RetainedStorage, RetainedView;

// Research descriptor surrogate, NOT an import of raster-d's actual API.
// Ownership copy, ROI, row stride and tile loops are isolated from pixels.
enum size_t width = 256;
enum size_t height = 128;
enum size_t stride = 320;
enum size_t trials = 7;
enum size_t operations = 20_000;
private __gshared ulong sink;

struct Descriptor {
    const(ubyte)* data;
    size_t offset, width, height, rowStride;
    @system ubyte sample(size_t x, size_t y) const nothrow @nogc {
        return data[offset + y * rowStride + x];
    }
    @system Descriptor roi(size_t x, size_t y, size_t w, size_t h) const nothrow @nogc {
        assert(x <= width && w <= width - x);
        assert(y <= height && h <= height - y);
        return Descriptor(data, offset + y * rowStride + x, w, h, rowStride);
    }
}

struct OwnedDescriptor {
    RetainedStorage owner;
    size_t offset, width, height, rowStride;
    @system OwnedDescriptor roi(size_t x, size_t y, size_t w, size_t h) {
        assert(x <= width && w <= width - x);
        assert(y <= height && h <= height - y);
        OwnedDescriptor result;
        result.owner = owner;
        result.offset = offset + y * rowStride + x;
        result.width = w;
        result.height = h;
        result.rowStride = rowStride;
        return move(result);
    }
    @system Descriptor borrow() const nothrow @nogc {
        return Descriptor(owner.rawPointer(), offset, width, height, rowStride);
    }
}

@system ulong sumRegion(Descriptor d) nothrow @nogc {
    ulong result;
    foreach (y; 0 .. d.height)
        foreach (x; 0 .. d.width)
            result += d.sample(x, y);
    return result;
}

@system void main() {
    auto owner = RetainedStorage.allocate(stride * height);
    foreach (i; 0 .. stride * height)
        owner.write(i, cast(ubyte)((i * 37 + 11) & 255));
    OwnedDescriptor retained;
    retained.owner = owner;
    retained.width = width;
    retained.height = height;
    retained.rowStride = stride;
    auto borrowed = retained.borrow();
    const expected = sumRegion(borrowed);
    assert(expected == sumRegion(retained.borrow()));
    assert(sumRegion(borrowed.roi(5, 7, 32, 24)) ==
        sumRegion(retained.roi(5, 7, 32, 24).borrow()));
    writeln("trial,case,ns_per_operation,checksum");
    foreach (trial; 0 .. trials) {
        foreach (slot; 0 .. 6) {
            const kind = (trial + slot) % 6;
            auto start = MonoTime.currTime;
            ulong total;
            foreach (iteration; 0 .. operations) {
                switch (kind) {
                    case 0: { auto v = borrowed; total += v.width; break; }
                    case 1: { auto v = retained; total += v.width; break; }
                    case 2: { auto v = borrowed.roi(5, 7, 32, 24); total += v.offset; break; }
                    case 3: { auto v = retained.roi(5, 7, 32, 24); total += v.offset; break; }
                    case 4: { auto v = borrowed.roi(5, 7, 32, 24); total += sumRegion(v); break; }
                    case 5: { auto v = retained.roi(5, 7, 32, 24); total += sumRegion(v.borrow()); break; }
                    default: assert(0);
                }
            }
            sink = total;
            const elapsed = MonoTime.currTime - start;
            const label = kind == 0 ? "borrow_copy" :
                kind == 1 ? "owner_copy" :
                kind == 2 ? "borrow_roi" :
                kind == 3 ? "owner_roi" :
                kind == 4 ? "borrow_roi_samples" : "owner_roi_samples";
            writeln(trial, ",", label, ",",
                cast(double) elapsed.total!"nsecs" / operations, ",", total);
        }
    }
}
