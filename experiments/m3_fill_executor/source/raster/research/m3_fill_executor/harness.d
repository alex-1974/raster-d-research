module raster.research.m3_fill_executor.harness;

import core.time : MonoTime;
import std.algorithm : sort;
import std.meta : AliasSeq;
import std.stdio : writeln, writefln;
import raster : Region2D, tryFillRasterPlane;
import raster.descriptor : PlaneDescriptor;
import raster.resource : ResourceEntry, ResourceAccess;
import raster.validation : BackingValidationResult, WritableBackingCertificationResult;
import raster.writable_view : WritableRasterView, tryMakeWritableRasterView;
import raster.research.m3_fill_executor.generated.pointer : pointerFill = tryCandidate;
import raster.research.m3_fill_executor.generated.slice : sliceFill = tryCandidate;

struct Pod { uint a; ushort b; ubyte c; ubyte d; }
static assert(Pod.sizeof == 8);
private enum rounds = 9;
private __gshared ulong sink;

private uint bits(float value) @safe nothrow @nogc
{
    union U { float f; uint u; } U v; v.f=value; return v.u;
}
private bool identical(T)(T a,T b) @safe nothrow @nogc
{
    static if (is(T == float)) return bits(a)==bits(b);
    else return a==b;
}
private T sample(T)(bool sentinel) @safe nothrow @nogc
{
    static if (is(T == float)) return sentinel ? -0.875f : 1.375f;
    else static if (is(T == ubyte)) return sentinel ? 13 : 179;
    else return sentinel ? Pod(7,11,13,17) : Pod(0xa5a55a5a,1234,91,137);
}
private ulong fingerprint(T)(scope const(T)[] data) @safe nothrow @nogc
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
private WritableRasterView!T writable(T)(return scope const(ResourceEntry)[] resources,
    return scope const(PlaneDescriptor)[] descriptors,Region2D region) @safe nothrow @nogc
{
    BackingValidationResult validation;
    WritableBackingCertificationResult certification;
    auto view=tryMakeWritableRasterView!T(resources,descriptors,region,validation,certification);
    if (!validation.ok || !certification.ok) assert(0,"fixture validation");
    return view;
}
private bool operation(T)(uint path,scope ref WritableRasterView!T view,
    size_t plane,T value) @safe nothrow @nogc
{
    final switch (path)
    {
        case 0: return tryFillRasterPlane(view,plane,value);
        case 1: return pointerFill(view,plane,value);
        case 2: return sliceFill(view,plane,value);
    }
}
private long median(long[rounds] values) { sort(values[]); return values[rounds/2]; }

private void runCase(T)(size_t w,size_t h,string layout)
{
    ptrdiff_t sr=cast(ptrdiff_t)(w+32),sx=1;
    switch (layout)
    {
        case "contiguous": sr=cast(ptrdiff_t)w; break;
        case "padded": break;
        case "negative-row": sr=-sr; break;
        case "repeated-row": sr=0; break;
        case "overlap-row": sr=cast(ptrdiff_t)(w/2); break;
        case "overlap-negative": sr=-cast(ptrdiff_t)(w/2); break;
        case "universal": sx=2; sr=cast(ptrdiff_t)(w*2+32); break;
        case "universal-negative": sx=-2; sr=-cast(ptrdiff_t)(w*2+32); break;
        case "zero-sample": sx=0; sr=3; break;
        case "zero-both": sx=0; sr=0; break;
        default: throw new Exception("unknown layout");
    }
    const rowExtent=cast(size_t)(sr<0 ? -sr : sr)*(h-1);
    const sampleExtent=cast(size_t)(sx<0 ? -sx : sx)*(w-1);
    enum guard=19;
    const length=guard+rowExtent+sampleExtent+1+guard;
    const offset=guard+(sr<0 ? rowExtent : 0)+(sx<0 ? sampleExtent : 0);
    auto a=new T[length]; auto b=new T[length]; auto c=new T[length];
    auto expected=new T[length];
    a[]=sample!T(true); b[]=sample!T(true); c[]=sample!T(true); expected[]=sample!T(true);
    const value=sample!T(false);
    // Independent coordinate-to-storage oracle, including duplicate writes.
    foreach (y; 0..h) foreach (x; 0..w)
        expected[cast(size_t)(cast(ptrdiff_t)offset+cast(ptrdiff_t)y*sr+cast(ptrdiff_t)x*sx)]=value;
    const expectedHash=fingerprint!T(expected);
    const PlaneDescriptor[1] ad=[PlaneDescriptor(a.ptr+offset,sr,sx)];
    const PlaneDescriptor[1] bd=[PlaneDescriptor(b.ptr+offset,sr,sx)];
    const PlaneDescriptor[1] cd=[PlaneDescriptor(c.ptr+offset,sr,sx)];
    const ResourceEntry[1] ar=[ResourceEntry(a.ptr,a.length*T.sizeof,null,null,ResourceAccess.readWrite)];
    const ResourceEntry[1] br=[ResourceEntry(b.ptr,b.length*T.sizeof,null,null,ResourceAccess.readWrite)];
    const ResourceEntry[1] cr=[ResourceEntry(c.ptr,c.length*T.sizeof,null,null,ResourceAccess.readWrite)];
    scope auto av=writable!T(ar[],ad[],Region2D(0,0,w,h));
    scope auto bv=writable!T(br[],bd[],Region2D(0,0,w,h));
    scope auto cv=writable!T(cr[],cd[],Region2D(0,0,w,h));
    void invoke(uint path)
    {
        bool ok;
        switch(path)
        {
            case 0: ok=operation(path,av,0,value); break;
            case 1: ok=operation(path,bv,0,value); break;
            case 2: ok=operation(path,cv,0,value); break;
            default: assert(0);
        }
        if (!ok) throw new Exception("fill failure");
    }
    void observe(uint path)
    {
        const output=path==0 ? a : path==1 ? b : c;
        foreach (i; 0..length)
            if (!identical(output[i],expected[i])) throw new Exception("sample/padding mismatch");
        const hash=fingerprint!T(output);
        if (hash!=expectedHash) throw new Exception("hash mismatch");
        sink ^= hash;
    }
    foreach (warmup; 0..2) foreach (path; 0..3) { invoke(path); observe(path); }
    long[rounds][3] raw;
    foreach (round; 0..rounds) foreach (turn; 0..3)
    {
        const path=cast(uint)((round+turn)%3);
        const start=MonoTime.currTime;
        invoke(path);
        raw[path][round]=(MonoTime.currTime-start).total!"nsecs";
        observe(path);
    }
    writefln("case type=%s w=%s h=%s layout=%s public_raw=%s pointer_raw=%s slice_raw=%s public_ns=%s pointer_ns=%s slice_ns=%s hash=%x",
        T.stringof,w,h,layout,raw[0],raw[1],raw[2],median(raw[0]),median(raw[1]),median(raw[2]),expectedHash);
}

private void contracts(T)()
{
    T[8] data; data[]=sample!T(true);
    const PlaneDescriptor[1] descriptors=[PlaneDescriptor(data.ptr,4,1)];
    const ResourceEntry[1] resources=[ResourceEntry(data.ptr,data.sizeof,null,null,ResourceAccess.readWrite)];
    scope auto view=writable!T(resources[],descriptors[],Region2D(0,0,4,2));
    scope auto empty=writable!T(resources[],descriptors[],Region2D(0,0,0,2));
    const original=data;
    foreach (path; 0..3)
    {
        if (operation(path,view,1,sample!T(false))) throw new Exception("invalid plane accepted");
        if (!operation(path,empty,0,sample!T(false))) throw new Exception("empty plane rejected");
        if (operation(path,empty,1,sample!T(false))) throw new Exception("invalid empty plane accepted");
        if (data!=original) throw new Exception("contract probe wrote storage");
    }
    writefln("contracts PASS type=%s",T.stringof);
}
private void specialFloat()
{
    union U { uint u; float f; }
    foreach (representation; [0u,0x80000000u,0x7fc12345u,0x7f800000u,0xff800000u])
    foreach (stride; [ptrdiff_t(4),ptrdiff_t(0),ptrdiff_t(-2)])
    {
        U value; value.u=representation;
        float[16] data;
        const size_t offset=stride<0 ? 2 : 0;
        const PlaneDescriptor[1] ds=[PlaneDescriptor(data.ptr+offset,stride,1)];
        const ResourceEntry[1] rs=[ResourceEntry(data.ptr,data.sizeof,null,null,ResourceAccess.readWrite)];
        scope auto view=writable!float(rs[],ds[],Region2D(0,0,4,2));
        foreach (path; 0..3)
        {
            data[]=-1.0f;
            if (!operation(path,view,0,value.f)) throw new Exception("special float failure");
            foreach (y; 0..2) foreach (x; 0..4)
                if (bits(data[cast(size_t)(cast(ptrdiff_t)offset+y*stride+x)])!=representation)
                    throw new Exception("special float bits changed");
        }
    }
    writeln("special-float PASS");
}
void run()
{
    specialFloat();
    foreach (T; AliasSeq!(float,ubyte,Pod)) contracts!T();
    enum layouts=["contiguous","padded","negative-row","repeated-row","overlap-row",
        "overlap-negative","universal","universal-negative","zero-sample","zero-both"];
    foreach (T; AliasSeq!(float,ubyte))
    foreach (dimensions; [[31UL,17UL],[256UL,128UL],[2048UL,512UL]])
    foreach (layout; layouts) runCase!T(dimensions[0],dimensions[1],layout);
    foreach (layout; layouts) runCase!Pod(31,17,layout);
    writefln("m3_fill_executor PASS cases=70 sink=%s",sink);
}
