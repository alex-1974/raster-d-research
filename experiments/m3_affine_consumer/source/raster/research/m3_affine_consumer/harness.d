module raster.research.m3_affine_consumer.harness;

import core.time : MonoTime;
import std.algorithm : sort;
import std.stdio : writefln, writeln;
import raster : Region2D, RasterTransformError, RasterNeighbourhood3x3Error,
    tryTransformRasterPlane, tryApplyRasterNeighbourhood3x3;
import raster.descriptor : PlaneDescriptor;
import raster.resource : ResourceEntry, ResourceAccess;
import raster.validation : BackingValidationResult, WritableBackingCertificationResult;
import raster.view : makeRasterViewAssumeValidated;
import raster.writable_view : WritableRasterView, tryMakeWritableRasterView;
import raster.research.m3_affine_consumer.generated.transform : tryBoundedTransform;
import raster.research.m3_affine_consumer.generated.neighbourhood : tryBoundedNeighbourhood;
import raster.research.m3_affine_bounds.candidate : Rect, checkedFastRejectDisjoint;

private enum repetitions = 9;
private __gshared ulong sink;

float transform(float v) @safe pure nothrow @nogc { return v * 1.25f + 0.375f; }
float kernel(ref const(float)[9] n) @safe pure nothrow @nogc
{ return n[0] + n[4] * 2.0f + n[8]; }

private uint bits(float v) @trusted pure nothrow @nogc
{
    union U { float f; uint u; }
    U u; u.f = v; return u.u;
}

private ulong fingerprint(scope const(float)[] values) @safe nothrow @nogc
{
    ulong h = 0xcbf29ce484222325UL;
    foreach (v; values) { h ^= bits(v); h *= 0x100000001b3UL; }
    return h;
}

private WritableRasterView!T writable(T)(
    return scope const(ResourceEntry)[] r,
    return scope const(PlaneDescriptor)[] d, Region2D region)
@safe nothrow @nogc
{
    BackingValidationResult validation;
    WritableBackingCertificationResult certification;
    auto v = tryMakeWritableRasterView!T(r,d,region,validation,certification);
    assert(validation.ok && certification.ok);
    return v;
}

private size_t index(size_t x, size_t y, size_t w, size_t h, size_t pitch,
    size_t step, bool nr, bool nx) @safe pure nothrow @nogc
{ return (nr ? h-1-y : y)*pitch + (nx ? w-1-x : x)*step; }

private long median(long[repetitions] raw)
{ sort(raw[]); return raw[repetitions/2]; }

// Both paths use exactly the same production execution. The only candidate
// edit is its relation import, mechanically generated from pinned source.
private void runCase(bool neighbourhood, size_t w, size_t h,
    bool sourceNegative, bool destinationNegative, size_t step, bool negativeSamples)
{
    const sw = w + (neighbourhood ? 2 : 0);
    const sh = h + (neighbourhood ? 2 : 0);
    const sp = sw*step + 32;
    const dp = w*step + 48;
    auto sourceStorage = new float[sp*sh];
    auto publicStorage = new float[dp*h];
    auto boundedStorage = new float[dp*h];
    auto expected = new float[dp*h];
    publicStorage[] = boundedStorage[] = expected[] = -991.0f;
    float value(size_t x, size_t y) { return cast(float)((x*37+y*53)%4093)*0.00025f; }
    foreach (y; 0..sh) foreach (x; 0..sw)
        sourceStorage[index(x,y,sw,sh,sp,step,sourceNegative,negativeSamples)] = value(x,y);
    foreach (y; 0..h) foreach (x; 0..w)
        expected[index(x,y,w,h,dp,step,destinationNegative,negativeSamples)] =
            neighbourhood ? value(x,y)+value(x+1,y+1)*2.0f+value(x+2,y+2)
                          : transform(value(x,y));
    const sr = sourceNegative ? -cast(ptrdiff_t)sp : cast(ptrdiff_t)sp;
    const dr = destinationNegative ? -cast(ptrdiff_t)dp : cast(ptrdiff_t)dp;
    const sx = negativeSamples ? -cast(ptrdiff_t)step : cast(ptrdiff_t)step;
    const PlaneDescriptor[1] sd = [PlaneDescriptor(
        sourceStorage.ptr+index(0,0,sw,sh,sp,step,sourceNegative,negativeSamples),sr,sx)];
    const PlaneDescriptor[1] pd = [PlaneDescriptor(
        publicStorage.ptr+index(0,0,w,h,dp,step,destinationNegative,negativeSamples),dr,sx)];
    const PlaneDescriptor[1] bd = [PlaneDescriptor(
        boundedStorage.ptr+index(0,0,w,h,dp,step,destinationNegative,negativeSamples),dr,sx)];
    const ResourceEntry[1] pr = [ResourceEntry(publicStorage.ptr,publicStorage.length*4,
        null,null,ResourceAccess.readWrite)];
    const ResourceEntry[1] br = [ResourceEntry(boundedStorage.ptr,boundedStorage.length*4,
        null,null,ResourceAccess.readWrite)];
    scope auto source = makeRasterViewAssumeValidated!float(sd[],Region2D(0,0,sw,sh));
    scope auto pub = writable!float(pr[],pd[],Region2D(0,0,w,h));
    scope auto bounded = writable!float(br[],bd[],Region2D(0,0,w,h));
    // Explicitly establish that this timing measures the fast-reject branch.
    if (!checkedFastRejectDisjoint(
        Rect(sw,sh,cast(size_t)sd[0].base,sr,sx),
        Rect(w,h,cast(size_t)bd[0].base,dr,sx),4))
        throw new Exception("disjoint allocation fast reject not established");
    const expectedHash = fingerprint(expected);
    void operation(bool candidate)
    {
        bool ok;
        if (neighbourhood)
        {
            RasterNeighbourhood3x3Error error;
            ok = candidate ? tryBoundedNeighbourhood!kernel(source,0,Region2D(1,1,w,h),bounded,0,error)
                           : tryApplyRasterNeighbourhood3x3!kernel(source,0,Region2D(1,1,w,h),pub,0,error);
            if (!ok || error != RasterNeighbourhood3x3Error.none)
                throw new Exception("neighbourhood failed");
        }
        else
        {
            RasterTransformError error;
            ok = candidate ? tryBoundedTransform!transform(source,0,bounded,0,error)
                           : tryTransformRasterPlane!transform(source,0,pub,0,error);
            if (!ok || error != RasterTransformError.none)
                throw new Exception("transform failed");
        }
    }
    void observe(bool candidate)
    {
        const hash = fingerprint(candidate ? boundedStorage : publicStorage);
        if (hash != expectedHash) throw new Exception("output/padding fingerprint mismatch");
        sink = sink * 0x100000001b3UL + hash;
    }
    foreach (_; 0..2) foreach (candidate; [false,true])
    { operation(candidate); observe(candidate); }
    long[repetitions] a,b;
    foreach (rep; 0..repetitions) foreach (turn; 0..2)
    {
        const candidate = ((rep+turn)%2) != 0;
        const start = MonoTime.currTime;
        operation(candidate);
        const elapsed = (MonoTime.currTime-start).total!"nsecs";
        observe(candidate); // full output and padding outside timer, every call
        if (candidate) b[rep] = elapsed; else a[rep] = elapsed;
    }
    writefln("consumer=%s source=%sx%s output=%sx%s source_pitch=%s destination_pitch=%s source_negative=%s destination_negative=%s sample_stride=%s public_raw_ns=%s bounded_raw_ns=%s public_median_ns=%s bounded_median_ns=%s speedup=%.3f fingerprint=%016x bytes=%s sink=%s",
        neighbourhood ? "neighbourhood" : "transform",sw,sh,w,h,sp,dp,
        sourceNegative,destinationNegative,sx,a,b,median(a),median(b),
        cast(double)median(a)/median(b),expectedHash,
        (sourceStorage.length+publicStorage.length+boundedStorage.length+expected.length)*4,sink);
}

// Genuine same-allocation consumers prove that overlapping envelopes do not
// reject sparse disjoint samples, and real overlap fails before writing.
private void sharedBacking(bool neighbourhood, bool overlap)
{
    enum w=3, h=2;
    const sw=w+(neighbourhood?2:0), sh=h+(neighbourhood?2:0);
    auto storage = new float[16*sh];
    foreach (i; 0..storage.length) storage[i]=cast(float)i;
    auto initial=storage.dup;
    const PlaneDescriptor[1] sd=[PlaneDescriptor(storage.ptr,16,2)];
    const PlaneDescriptor[1] dd=[PlaneDescriptor(storage.ptr+(overlap?0:1),16,2)];
    const ResourceEntry[1] r=[ResourceEntry(storage.ptr,storage.length*4,null,null,ResourceAccess.readWrite)];
    scope auto source=makeRasterViewAssumeValidated!float(sd[],Region2D(0,0,sw,sh));
    scope auto destination=writable!float(r[],dd[],Region2D(0,0,w,h));
    if (checkedFastRejectDisjoint(Rect(sw,sh,cast(size_t)storage.ptr,16,2),
        Rect(w,h,cast(size_t)(storage.ptr+(overlap?0:1)),16,2),4))
        throw new Exception("shared envelope unexpectedly rejected");
    bool publicOk, boundedOk;
    if (neighbourhood)
    {
        RasterNeighbourhood3x3Error a,b;
        publicOk=tryApplyRasterNeighbourhood3x3!kernel(source,0,Region2D(1,1,w,h),destination,0,a);
        auto publicOutput=storage.dup;
        storage[]=initial[];
        boundedOk=tryBoundedNeighbourhood!kernel(source,0,Region2D(1,1,w,h),destination,0,b);
        if(a!=b || storage!=publicOutput) throw new Exception("shared neighbourhood mismatch");
    }
    else
    {
        RasterTransformError a,b;
        publicOk=tryTransformRasterPlane!transform(source,0,destination,0,a);
        auto publicOutput=storage.dup;
        storage[]=initial[];
        boundedOk=tryBoundedTransform!transform(source,0,destination,0,b);
        if(a!=b || storage!=publicOutput) throw new Exception("shared transform mismatch");
    }
    if(publicOk!=boundedOk || publicOk==overlap || (overlap && storage!=initial))
        throw new Exception("shared backing success/no-write mismatch");
    writefln("shared_backing neighbourhood=%s genuine_overlap=%s PASS",neighbourhood,overlap);
}

int runConsumerGate()
{
    foreach (n; [false,true]) foreach (overlap; [false,true]) sharedBacking(n,overlap);
    foreach (n; [false,true])
    {
        foreach (nr; [false,true]) foreach (dr; [false,true])
            runCase(n,2048,512,nr,dr,1,false);
        runCase(n,31,17,false,true,2,false);
        runCase(n,31,17,true,false,2,true);
    }
    writeln("m3_affine_consumer PASS");
    return 0;
}
