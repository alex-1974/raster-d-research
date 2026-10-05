module app;

import core.time : MonoTime;
import std.algorithm.sorting : sort;
import std.stdio : writeln, writefln;

private enum size_t warmups = 4;
private enum size_t repetitions = 17;
private enum size_t height = 256;
private __gshared ulong sink;

private void scalarLoop(scope const(ubyte)[] row, scope float[] destination)
    @safe pure nothrow @nogc
{
    foreach (x, value; row)
        destination[x] = cast(float)value;
}

private void hybridBody(scope const(ubyte)[] row, scope float[] destination)
    @safe pure nothrow @nogc
{
    scope const(ubyte)[] remainingSource = row;
    scope auto remainingDestination = destination;
    while (remainingSource.length != 0 && remainingDestination.length != 0)
    {
        remainingDestination[0] = cast(float)remainingSource[0];
        remainingSource = remainingSource[1 .. $];
        remainingDestination = remainingDestination[1 .. $];
    }
}

private void pointerBody(scope const(ubyte)[] row, scope float[] destination)
    @trusted pure nothrow @nogc
{
    assert(row.length == destination.length);
    scope const(ubyte)* sourcePointer = row.ptr;
    scope float* destinationPointer = destination.ptr;
    foreach (i; 0 .. row.length)
        destinationPointer[i] = cast(float)sourcePointer[i];
}

/*
 * Replicated separate-entry controls.
 *
 * These intentionally preserve the first version of this experiment. Widths
 * below 64 run identical source in distinct functions and therefore expose how
 * much same-binary function placement alone can move the measurement.
 */
pragma(inline, false)
extern(C) void m3_hybrid_0(scope const(ubyte)[] row, scope float[] destination)
    @safe pure nothrow @nogc
{
    if (row.length < 64) scalarLoop(row, destination);
    else hybridBody(row, destination);
}

pragma(inline, false)
extern(C) void m3_pointer_0(scope const(ubyte)[] row, scope float[] destination)
    @safe pure nothrow @nogc
{
    if (row.length < 64) scalarLoop(row, destination);
    else pointerBody(row, destination);
}

pragma(inline, false)
extern(C) void m3_pointer_1(scope const(ubyte)[] row, scope float[] destination)
    @safe pure nothrow @nogc
{
    if (row.length < 64) scalarLoop(row, destination);
    else pointerBody(row, destination);
}

pragma(inline, false)
extern(C) void m3_hybrid_1(scope const(ubyte)[] row, scope float[] destination)
    @safe pure nothrow @nogc
{
    if (row.length < 64) scalarLoop(row, destination);
    else hybridBody(row, destination);
}

pragma(inline, false)
extern(C) void m3_hybrid_2(scope const(ubyte)[] row, scope float[] destination)
    @safe pure nothrow @nogc
{
    if (row.length < 64) scalarLoop(row, destination);
    else hybridBody(row, destination);
}

pragma(inline, false)
extern(C) void m3_pointer_2(scope const(ubyte)[] row, scope float[] destination)
    @safe pure nothrow @nogc
{
    if (row.length < 64) scalarLoop(row, destination);
    else pointerBody(row, destination);
}

pragma(inline, false)
extern(C) void m3_pointer_3(scope const(ubyte)[] row, scope float[] destination)
    @safe pure nothrow @nogc
{
    if (row.length < 64) scalarLoop(row, destination);
    else pointerBody(row, destination);
}

pragma(inline, false)
extern(C) void m3_hybrid_3(scope const(ubyte)[] row, scope float[] destination)
    @safe pure nothrow @nogc
{
    if (row.length < 64) scalarLoop(row, destination);
    else hybridBody(row, destination);
}

/*
 * Primary shared-entry diagnostic.
 *
 * Hybrid and Pointer enter the same function and share the same caller. Widths
 * below 64 return through exactly the same scalar body before the selector is
 * inspected. For wide rows shared_0 and shared_1 reverse which form occupies
 * the first selector branch, controlling for fallthrough/taken-branch layout.
 */
pragma(inline, false)
extern(C) void m3_shared_0(
    ubyte form,
    scope const(ubyte)[] row,
    scope float[] destination)
    @safe pure nothrow @nogc
{
    if (row.length < 64)
    {
        scalarLoop(row, destination);
        return;
    }

    if (form == 0)
        hybridBody(row, destination);
    else
        pointerBody(row, destination);
}

pragma(inline, false)
extern(C) void m3_shared_1(
    ubyte form,
    scope const(ubyte)[] row,
    scope float[] destination)
    @safe pure nothrow @nogc
{
    if (row.length < 64)
    {
        scalarLoop(row, destination);
        return;
    }

    if (form == 0)
        pointerBody(row, destination);
    else
        hybridBody(row, destination);
}

private ulong fingerprint(scope const(float)[] values)
{
    ulong hash = 0xcbf29ce484222325UL;
    foreach (value; values)
    {
        union Bits { float f; uint u; }
        Bits bits;
        bits.f = value;
        hash ^= bits.u;
        hash *= 0x100000001b3UL;
    }
    return hash;
}

private long elapsed(alias kernel)(
    scope const(ubyte)[] source,
    scope float[] destination,
    size_t width)
{
    const rows = source.length / width;
    const start = MonoTime.currTime;
    foreach (y; 0 .. rows)
    {
        const offset = y * width;
        kernel(source[offset .. offset + width],
               destination[offset .. offset + width]);
    }
    return (MonoTime.currTime - start).total!"nsecs";
}

private long elapsedShared(alias kernel)(
    ubyte form,
    scope const(ubyte)[] source,
    scope float[] destination,
    size_t width)
{
    const rows = source.length / width;
    const start = MonoTime.currTime;
    foreach (y; 0 .. rows)
    {
        const offset = y * width;
        kernel(
            form,
            source[offset .. offset + width],
            destination[offset .. offset + width]);
    }
    return (MonoTime.currTime - start).total!"nsecs";
}

private long median(long[repetitions] values)
{
    sort(values[]);
    return values[repetitions / 2];
}

private void verify(alias kernel)(
    scope const(ubyte)[] source,
    scope float[] destination,
    size_t width)
{
    destination[] = float.nan;
    const rows = source.length / width;
    foreach (y; 0 .. rows)
    {
        const offset = y * width;
        kernel(source[offset .. offset + width],
               destination[offset .. offset + width]);
    }

    foreach (i, value; source)
        assert(destination[i] == cast(float)value);
}

private void verifyShared(alias kernel)(
    ubyte form,
    scope const(ubyte)[] source,
    scope float[] destination,
    size_t width)
{
    destination[] = float.nan;
    const rows = source.length / width;
    foreach (y; 0 .. rows)
    {
        const offset = y * width;
        kernel(
            form,
            source[offset .. offset + width],
            destination[offset .. offset + width]);
    }

    foreach (i, value; source)
        assert(destination[i] == cast(float)value);
}

private void consume(scope const(float)[] values)
{
    sink ^= fingerprint(values);
}

private void runPair(
    alias hybridKernel,
    alias pointerKernel)(
    size_t pair,
    scope const(ubyte)[] source,
    scope float[] hybridOutput,
    scope float[] pointerOutput,
    size_t width)
{
    verify!hybridKernel(source, hybridOutput, width);
    verify!pointerKernel(source, pointerOutput, width);
    assert(hybridOutput == pointerOutput);

    foreach (_; 0 .. warmups)
    {
        elapsed!hybridKernel(source, hybridOutput, width);
        elapsed!pointerKernel(source, pointerOutput, width);
    }

    long[repetitions] hybridSamples;
    long[repetitions] pointerSamples;

    foreach (r; 0 .. repetitions)
    {
        if ((r & 1) == 0)
        {
            hybridSamples[r] = elapsed!hybridKernel(source, hybridOutput, width);
            pointerSamples[r] = elapsed!pointerKernel(source, pointerOutput, width);
        }
        else
        {
            pointerSamples[r] = elapsed!pointerKernel(source, pointerOutput, width);
            hybridSamples[r] = elapsed!hybridKernel(source, hybridOutput, width);
        }
        consume(hybridOutput);
        consume(pointerOutput);
    }

    const hybridMedian = median(hybridSamples);
    const pointerMedian = median(pointerSamples);

    writefln(
        "m3_same_binary pair=%s width=%s height=%s hybrid_ns=%s pointer_ns=%s hybrid_over_pointer=%.6f fingerprint=%016x",
        pair,
        width,
        height,
        hybridMedian,
        pointerMedian,
        cast(double)hybridMedian / cast(double)pointerMedian,
        fingerprint(hybridOutput));
}

private void runShared(
    alias kernel)(
    size_t pair,
    ubyte hybridForm,
    ubyte pointerForm,
    scope const(ubyte)[] source,
    scope float[] hybridOutput,
    scope float[] pointerOutput,
    size_t width)
{
    verifyShared!kernel(hybridForm, source, hybridOutput, width);
    verifyShared!kernel(pointerForm, source, pointerOutput, width);
    assert(hybridOutput == pointerOutput);

    foreach (_; 0 .. warmups)
    {
        elapsedShared!kernel(hybridForm, source, hybridOutput, width);
        elapsedShared!kernel(pointerForm, source, pointerOutput, width);
    }

    long[repetitions] hybridSamples;
    long[repetitions] pointerSamples;

    foreach (r; 0 .. repetitions)
    {
        if ((r & 1) == 0)
        {
            hybridSamples[r] =
                elapsedShared!kernel(hybridForm, source, hybridOutput, width);
            pointerSamples[r] =
                elapsedShared!kernel(pointerForm, source, pointerOutput, width);
        }
        else
        {
            pointerSamples[r] =
                elapsedShared!kernel(pointerForm, source, pointerOutput, width);
            hybridSamples[r] =
                elapsedShared!kernel(hybridForm, source, hybridOutput, width);
        }
        consume(hybridOutput);
        consume(pointerOutput);
    }

    const hybridMedian = median(hybridSamples);
    const pointerMedian = median(pointerSamples);

    writefln(
        "m3_shared_boundary pair=%s width=%s height=%s hybrid_ns=%s pointer_ns=%s hybrid_over_pointer=%.6f fingerprint=%016x",
        pair,
        width,
        height,
        hybridMedian,
        pointerMedian,
        cast(double)hybridMedian / cast(double)pointerMedian,
        fingerprint(hybridOutput));
}

private void runWidth(size_t width)
{
    auto source = new ubyte[width * height];
    auto hybridOutput = new float[source.length];
    auto pointerOutput = new float[source.length];

    foreach (i; 0 .. source.length)
        source[i] = cast(ubyte)((i * 37 + 11) & 0xff);

    runPair!(m3_hybrid_0, m3_pointer_0)(
        0, source, hybridOutput, pointerOutput, width);
    runPair!(m3_hybrid_1, m3_pointer_1)(
        1, source, hybridOutput, pointerOutput, width);
    runPair!(m3_hybrid_2, m3_pointer_2)(
        2, source, hybridOutput, pointerOutput, width);
    runPair!(m3_hybrid_3, m3_pointer_3)(
        3, source, hybridOutput, pointerOutput, width);

    runShared!m3_shared_0(
        0, 0, 1, source, hybridOutput, pointerOutput, width);
    runShared!m3_shared_1(
        1, 1, 0, source, hybridOutput, pointerOutput, width);
}

int main()
{
    version (LDC)
        writeln("compiler=ldc");
    else
        writeln("compiler=dmd");

    foreach (width; [31UL, 63UL, 64UL, 96UL, 128UL, 256UL, 512UL, 2048UL])
        runWidth(width);

    writefln("sink=%s", sink);
    return 0;
}
