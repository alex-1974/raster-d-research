module raster.research.m3_transform_executor.harness;

import core.time : MonoTime;
import std.algorithm : sort;
import std.stdio : writeln, writefln;
import raster : Region2D, RasterTransformError, tryTransformRasterPlane;
import raster.descriptor : PlaneDescriptor;
import raster.resource : ResourceEntry, ResourceAccess;
import raster.validation : BackingValidationResult, WritableBackingCertificationResult;
import raster.view : makeRasterViewAssumeValidated;
import raster.writable_view : WritableRasterView, tryMakeWritableRasterView;
import raster.research.m3_transform_executor.generated.pointer : tryPointer = tryCandidate;
import raster.research.m3_transform_executor.generated.slice : trySlice = tryCandidate;

private enum rounds = 9;
private __gshared ulong sink;
struct Pod { uint a; ushort b; ubyte c; ubyte d; }
static assert(Pod.sizeof == 8);
float identity(float value) @safe pure nothrow @nogc { return value; }
float transform(float value) @safe pure nothrow @nogc { return value * 1.25f + 0.375f; }
ubyte transform(ubyte value) @safe pure nothrow @nogc { return cast(ubyte)((value*37+11)%251); }
Pod transform(Pod value) @safe pure nothrow @nogc
{ return Pod(value.a ^ 0xa5a55a5a, cast(ushort)(value.b+17), value.d, value.c); }

private T valueAt(T)(size_t x, size_t y) @safe pure nothrow @nogc
{
    static if (is(T == float)) return cast(float)((x*37+y*53)%4093)*0.00025f;
    else static if (is(T == ubyte)) return cast(ubyte)((x*37+y*53)%251);
    else return Pod(cast(uint)(x*37+y*53),cast(ushort)(x+y),cast(ubyte)x,cast(ubyte)y);
}
private uint bits(float value) @safe pure nothrow @nogc
{
    // Same-size union reinterpretation; neither member contains pointers.
    union U { float f; uint u; } U v; v.f=value; return v.u;
}
private bool identical(T)(T a, T b) @safe pure nothrow @nogc
{
    static if (is(T == float)) return bits(a)==bits(b);
    else return a==b;
}
private ulong fingerprint(T)(scope const(T)[] data) @safe pure nothrow @nogc
{
    ulong hash=0xcbf29ce484222325;
    foreach (value; data)
    {
        static if (is(T == float)) { hash ^= bits(value); hash *= 0x100000001b3; }
        else static if (is(T == ubyte)) { hash ^= value; hash *= 0x100000001b3; }
        else foreach (v; [ulong(value.a),ulong(value.b),ulong(value.c),ulong(value.d)])
        { hash ^= v; hash *= 0x100000001b3; }
    }
    return hash;
}
private size_t index(size_t x,size_t y,size_t w,size_t h,size_t pitch,
    size_t step,bool negativeRows,bool negativeSamples) @safe pure nothrow @nogc
{ return (negativeRows ? h-1-y : y)*pitch + (negativeSamples ? w-1-x : x)*step; }
private WritableRasterView!T writable(T)(return scope const(ResourceEntry)[] resources,
    return scope const(PlaneDescriptor)[] descriptors,Region2D region) @safe nothrow @nogc
{
    BackingValidationResult validation;
    WritableBackingCertificationResult certification;
    auto view=tryMakeWritableRasterView!T(resources,descriptors,region,validation,certification);
    assert(validation.ok && certification.ok);
    return view;
}
private long median(long[rounds] values) { sort(values[]); return values[rounds/2]; }

private void runCase(T)(size_t w,size_t h,bool sn,bool dn,size_t padding,
    size_t step=1,bool negativeSamples=false)
{
    const sp=w*step+padding;
    const dp=w*step+padding;
    auto input=new T[sp*h];
    auto a=new T[dp*h]; auto b=new T[dp*h]; auto c=new T[dp*h];
    auto expected=new T[dp*h];
    const sentinel=valueAt!T(99,997);
    input[]=a[]=b[]=c[]=expected[]=sentinel;
    foreach (y; 0..h) foreach (x; 0..w)
    {
        input[index(x,y,w,h,sp,step,sn,negativeSamples)]=valueAt!T(x,y);
        expected[index(x,y,w,h,dp,step,dn,negativeSamples)]=transform(valueAt!T(x,y));
    }
    const inputHash=fingerprint!T(input);
    const expectedHash=fingerprint!T(expected);
    const sr=sn ? -cast(ptrdiff_t)sp : cast(ptrdiff_t)sp;
    const dr=dn ? -cast(ptrdiff_t)dp : cast(ptrdiff_t)dp;
    const sx=negativeSamples ? -cast(ptrdiff_t)step : cast(ptrdiff_t)step;
    const offset=index(0,0,w,h,dp,step,dn,negativeSamples);
    const PlaneDescriptor[1] sd=[PlaneDescriptor(input.ptr+index(0,0,w,h,sp,step,sn,negativeSamples),sr,sx)];
    const PlaneDescriptor[1] ad=[PlaneDescriptor(a.ptr+offset,dr,sx)];
    const PlaneDescriptor[1] bd=[PlaneDescriptor(b.ptr+offset,dr,sx)];
    const PlaneDescriptor[1] cd=[PlaneDescriptor(c.ptr+offset,dr,sx)];
    const ResourceEntry[1] ar=[ResourceEntry(a.ptr,a.length*T.sizeof,null,null,ResourceAccess.readWrite)];
    const ResourceEntry[1] br=[ResourceEntry(b.ptr,b.length*T.sizeof,null,null,ResourceAccess.readWrite)];
    const ResourceEntry[1] cr=[ResourceEntry(c.ptr,c.length*T.sizeof,null,null,ResourceAccess.readWrite)];
    scope auto source=makeRasterViewAssumeValidated!T(sd[],Region2D(0,0,w,h));
    scope auto av=writable!T(ar[],ad[],Region2D(0,0,w,h));
    scope auto bv=writable!T(br[],bd[],Region2D(0,0,w,h));
    scope auto cv=writable!T(cr[],cd[],Region2D(0,0,w,h));
    void operation(uint path)
    {
        RasterTransformError error;
        bool ok;
        switch (path)
        {
            case 0: ok=tryTransformRasterPlane!transform(source,0,av,0,error); break;
            case 1: ok=tryPointer!transform(source,0,bv,0,error); break;
            case 2: ok=trySlice!transform(source,0,cv,0,error); break;
            default: assert(0);
        }
        if (!ok || error!=RasterTransformError.none) throw new Exception("operation failure");
    }
    void observe(uint path)
    {
        const output=path==0 ? a : path==1 ? b : c;
        foreach (i; 0..output.length)
            if (!identical(output[i],expected[i])) throw new Exception("sample or padding mismatch");
        const hash=fingerprint!T(output);
        if (hash!=expectedHash || fingerprint!T(input)!=inputHash)
            throw new Exception("output/source fingerprint mismatch");
        sink ^= hash;
    }
    foreach (warmup; 0..2) foreach (path; 0..3) { operation(path); observe(path); }
    long[rounds][3] raw;
    foreach (round; 0..rounds) foreach (turn; 0..3)
    {
        // Cyclic order gives each path exactly three runs in every position.
        const path=cast(uint)((round+turn)%3);
        const start=MonoTime.currTime;
        operation(path);
        raw[path][round]=(MonoTime.currTime-start).total!"nsecs";
        observe(path); // complete result and padding are read outside the timer
    }
    writefln("case type=%s w=%s h=%s sn=%s dn=%s padding=%s step=%s nx=%s public_raw=%s pointer_raw=%s slice_raw=%s public_ns=%s pointer_ns=%s slice_ns=%s hash=%x",
        T.stringof,w,h,sn,dn,padding,step,negativeSamples,raw[0],raw[1],raw[2],
        median(raw[0]),median(raw[1]),median(raw[2]),expectedHash);
}

// Exact floating value semantics, including special values, are checked against
// the public production path, not a presumed fused/unfused numeric expression.
private void specialFloatCase(alias kernel)()
{
    float[8] input=[0.0f,-0.0f,float.infinity,-float.infinity,float.nan,
        float.min_normal, -float.min_normal, 1.0f];
    float[8] a,b,c;
    const PlaneDescriptor[1] sd=[PlaneDescriptor(input.ptr,8,1)];
    const PlaneDescriptor[1] ad=[PlaneDescriptor(a.ptr,8,1)];
    const PlaneDescriptor[1] bd=[PlaneDescriptor(b.ptr,8,1)];
    const PlaneDescriptor[1] cd=[PlaneDescriptor(c.ptr,8,1)];
    const ResourceEntry[1] ar=[ResourceEntry(a.ptr,a.sizeof,null,null,ResourceAccess.readWrite)];
    const ResourceEntry[1] br=[ResourceEntry(b.ptr,b.sizeof,null,null,ResourceAccess.readWrite)];
    const ResourceEntry[1] cr=[ResourceEntry(c.ptr,c.sizeof,null,null,ResourceAccess.readWrite)];
    scope auto source=makeRasterViewAssumeValidated!float(sd[],Region2D(0,0,8,1));
    scope auto av=writable!float(ar[],ad[],Region2D(0,0,8,1));
    scope auto bv=writable!float(br[],bd[],Region2D(0,0,8,1));
    scope auto cv=writable!float(cr[],cd[],Region2D(0,0,8,1));
    RasterTransformError error;
    if (!tryTransformRasterPlane!kernel(source,0,av,0,error)
        || !tryPointer!kernel(source,0,bv,0,error)
        || !trySlice!kernel(source,0,cv,0,error))
        throw new Exception("special-float operation failure");
    foreach (i; 0..8)
        if (bits(a[i])!=bits(b[i]) || bits(a[i])!=bits(c[i]))
            throw new Exception("special-float bit mismatch");
    writeln("special-float PASS");
}

void run()
{
    specialFloatCase!transform();
    specialFloatCase!identity();
    foreach (T; AliasSeq!(float,ubyte))
    foreach (dimensions; [[31UL,17UL],[256UL,128UL],[2048UL,512UL]])
    {
        foreach (sn; [false,true]) foreach (dn; [false,true])
            runCase!T(dimensions[0],dimensions[1],sn,dn,32);
        runCase!T(dimensions[0],dimensions[1],false,false,0);
    }
    foreach (T; AliasSeq!(float,ubyte,Pod))
    {
        runCase!T(31,17,false,true,32,2);
        runCase!T(31,17,true,false,32,2,true);
    }
    foreach (sn; [false,true]) foreach (dn; [false,true]) runCase!Pod(31,17,sn,dn,32);
    runCase!Pod(31,17,false,false,0);
    writefln("m3_transform_executor PASS cases=41 sink=%s",sink);
}
import std.meta : AliasSeq;
