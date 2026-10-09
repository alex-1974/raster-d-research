module benchmark;
import core.time : MonoTime;
import std.stdio : writeln;
import retained_malloc : RetainedStorage;

// Microbenchmark only: identical read-only in-memory byte workload.
// It does not model raster-d descriptor validation or physical layout.
enum size_t width = 4096;
enum size_t repetitions = 4096;
enum size_t trials = 7;
private __gshared ulong checksumSink;

@system ulong borrowedSum(const(ubyte)* data, size_t n) {
    ulong sum = 0;
    foreach (i; 0 .. n) sum += data[i];
    return sum;
}

@system ulong retainedSum(ref const RetainedStorage storage, size_t n) {
    ulong sum = 0;
    foreach (i; 0 .. n) sum += storage.read(i);
    return sum;
}

@system ulong callbackSum(const(ubyte)* data, size_t n) {
    ulong result = 0;
    // Plain loop-control duplicate, not a callback performance measurement.
    foreach (i; 0 .. n) result += data[i];
    return result;
}

@system void main() {
    auto owner = RetainedStorage.allocate(width);
    auto data = new ubyte[width]; // benchmark initialization only
    foreach (i; 0 .. width) {
        ubyte value = cast(ubyte) (i * 37 + 11);
        data[i] = value;
        owner.write(i, value);
    }
    ulong expected = borrowedSum(data.ptr, width);
    assert(retainedSum(owner, width) == expected);
    assert(callbackSum(data.ptr, width) == expected);
    writeln("trial,case,ns_per_sample,checksum");
    // Rotate order across trials so case order is not fixed.
    foreach (trial; 0 .. trials) {
        foreach (slot; 0 .. 3) {
            const kind = (trial + slot) % 3;
            auto start = MonoTime.currTime;
            ulong sum = 0;
            foreach (_; 0 .. repetitions) {
                switch (kind) {
                    case 0: sum += borrowedSum(data.ptr, width); break;
                    case 1: sum += retainedSum(owner, width); break;
                    case 2: sum += callbackSum(data.ptr, width); break;
                    default: assert(0);
                }
            }
            auto duration = MonoTime.currTime - start;
            checksumSink = sum;
            const double nsPerSample = cast(double) duration.total!"nsecs" /
                cast(double) (width * repetitions);
            string label = kind == 0 ? "borrowed" :
                (kind == 1 ? "retained" : "loop_control");
            writeln(trial, ",", label, ",", nsPerSample, ",", sum);
            assert(sum == expected * repetitions);
        }
    }
}
