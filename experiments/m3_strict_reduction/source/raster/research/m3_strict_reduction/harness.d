module raster.research.m3_strict_reduction.harness;
import core.time : MonoTime;
import std.algorithm : sort;
import std.math : isNaN;
import std.stdio : writeln, writefln;
import raster : Region2D, trySumFloatToDouble;
import raster.descriptor : PlaneDescriptor;
import raster.view : RasterView, makeRasterViewAssumeValidated;
import raster.research.m3_strict_reduction.generated.pointer : pointerSum = tryCandidate;
import raster.research.m3_strict_reduction.generated.slice : sliceSum = tryCandidate;

extern(C) bool cppStrict(scope const(float)*,ptrdiff_t,ptrdiff_t,size_t,size_t,
    size_t,size_t,scope double*) @system nothrow @nogc;

// Actual C++ source is separately compiled without LTO/reassociation. Caller
// supplies retained validated geometry; C++ only reads it, writes this local
// output, handles invalid/empty before access and retains no pointer.
private bool cppSum(scope const(float)* base,ptrdiff_t sr,ptrdiff_t sx,size_t w,
    size_t h,size_t plane,out double value) @trusted nothrow @nogc
{ return cppStrict(base,sr,sx,w,h,1,plane,&value); }

private enum rounds=12;
private __gshared ulong sink;
private ulong bits(double value) @safe nothrow @nogc
{ union U { double d; ulong u; } U v; v.d=value; return v.u; }
private uint floatBits(float value) @safe nothrow @nogc
{ union U { float f; uint u; } U v; v.f=value; return v.u; }
private float fromBits(uint value) @safe nothrow @nogc
{ union U { float f; uint u; } U v; v.u=value; return v.f; }
private ulong fingerprint(scope const(float)[] data)
{
    ulong hash=0xcbf29ce484222325;
    foreach (v; data) { hash ^= floatBits(v); hash *= 0x100000001b3; }
    return hash;
}
private bool same(double a,double b)
{ return isNaN(a) ? isNaN(b) : bits(a)==bits(b); }
private float sample(size_t index,string corpus)
{
    switch(corpus)
    {
        case "positive": return cast(float)((index*37)%4093)*0.00025f;
        case "cancellation": return [1.0e20f,1.0f,-1.0e20f,1.0f][index%4];
        case "exponents": return fromBits(cast(uint)((index*1664525+1013904223)&0x807fffff)
            | cast(uint)((index*73)%254+1)<<23);
        case "negative-zero": return -0.0f;
        case "infinity": return index%5==0 ? float.infinity : 1.0f;
        case "opposite-infinities": return index%2 ? -float.infinity : float.infinity;
        case "nan": return index%7==0 ? fromBits(0x7fc12345) : 1.0f;
        case "subnormals": return fromBits(cast(uint)(index%2 ? 0x80000001 : 1));
        default: throw new Exception("unknown corpus");
    }
}
private bool operation(uint path,scope RasterView!float view,scope const(float)* base,
    ptrdiff_t sr,ptrdiff_t sx,size_t plane,out double value)
{
    switch(path)
    {
        case 0: return trySumFloatToDouble(view,plane,value);
        case 1: return pointerSum(view,plane,value);
        case 2: return sliceSum(view,plane,value);
        case 3: return cppSum(base,sr,sx,view.width,view.height,plane,value);
        default: assert(0);
    }
}
private long median(long[rounds] raw)
{ sort(raw[]); return (raw[rounds/2-1]+raw[rounds/2])/2; }
private void runCase(size_t w,size_t h,string layout,string corpus,bool timed)
{
    ptrdiff_t sr=cast(ptrdiff_t)(w+32),sx=1;
    switch(layout)
    {
        case "contiguous": sr=cast(ptrdiff_t)w; break;
        case "padded": break;
        case "negative-row": sr=-sr; break;
        case "universal": sx=2; sr=cast(ptrdiff_t)(w*2+32); break;
        case "universal-negative": sx=-2; sr=-cast(ptrdiff_t)(w*2+32); break;
        case "repeated-row": sr=0; break;
        case "zero-both": sr=0; sx=0; break;
        default: throw new Exception("unknown layout");
    }
    const rowExtent=cast(size_t)(sr<0 ? -sr : sr)*(h-1);
    const sampleExtent=cast(size_t)(sx<0 ? -sx : sx)*(w-1);
    const offset=19+(sr<0 ? rowExtent : 0)+(sx<0 ? sampleExtent : 0);
    auto input=new float[19+rowExtent+sampleExtent+1+19]; input[]=-77.5f;
    size_t index(size_t x,size_t y)
    { return cast(size_t)(cast(ptrdiff_t)offset+cast(ptrdiff_t)y*sr+cast(ptrdiff_t)x*sx); }
    foreach(y; 0..h) foreach(x; 0..w) input[index(x,y)]=sample(y*w+x,corpus);
    // Repeated mappings take the final populated physical value; reference
    // traverses the resulting logical plane with one sequential accumulator.
    double expected=0.0;
    foreach(y; 0..h) foreach(x; 0..w) expected += cast(double)input[index(x,y)];
    const sourceHash=fingerprint(input);
    const PlaneDescriptor[1] ds=[PlaneDescriptor(input.ptr+offset,sr,sx)];
    scope auto view=makeRasterViewAssumeValidated!float(ds[],Region2D(0,0,w,h));
    void invoke(uint path)
    {
        double result=-17;
        if(!operation(path,view,input.ptr+offset,sr,sx,0,result)) throw new Exception("operation failure");
        if(!same(expected,result)) throw new Exception("strict-order result mismatch");
        sink ^= isNaN(result) ? 0x7ff8000000000000UL : bits(result);
    }
    if(!timed)
    {
        foreach(path; 0..4) invoke(path);
        if(fingerprint(input)!=sourceHash) throw new Exception("source changed");
        return;
    }
    foreach(warmup; 0..2) foreach(path; 0..4) invoke(path);
    long[rounds][4] raw;
    foreach(round; 0..rounds) foreach(turn; 0..4)
    {
        const path=cast(uint)((round+turn)%4);
        double result;
        const start=MonoTime.currTime;
        const ok=operation(path,view,input.ptr+offset,sr,sx,0,result);
        raw[path][round]=(MonoTime.currTime-start).total!"nsecs";
        if(!ok || !same(expected,result)) throw new Exception("timed strict result mismatch");
        if(fingerprint(input)!=sourceHash) throw new Exception("source/padding changed");
        sink ^= bits(result);
    }
    writefln("case w=%s h=%s layout=%s corpus=%s public_raw=%s pointer_raw=%s slice_raw=%s cpp_raw=%s public_ns=%s pointer_ns=%s slice_ns=%s cpp_ns=%s result=%x hash=%x",
        w,h,layout,corpus,raw[0],raw[1],raw[2],raw[3],median(raw[0]),median(raw[1]),median(raw[2]),median(raw[3]),bits(expected),sourceHash);
}
private void contracts()
{
    float[4] data=[1e20f,1.0f,-1e20f,1.0f];
    const PlaneDescriptor[1] ds=[PlaneDescriptor(data.ptr,4,1)];
    scope auto view=makeRasterViewAssumeValidated!float(ds[],Region2D(0,0,4,1));
    const PlaneDescriptor[1] es=[PlaneDescriptor(null,ptrdiff_t.min,ptrdiff_t.min)];
    scope auto empty=makeRasterViewAssumeValidated!float(es[],Region2D(size_t.max,size_t.max,0,7));
    foreach(path; 0..4)
    {
        double value=123;
        if(operation(path,view,data.ptr,4,1,1,value) || bits(value)!=bits(0.0)) throw new Exception("invalid/out-zero contract");
        if(!operation(path,empty,null,ptrdiff_t.min,ptrdiff_t.min,0,value) || bits(value)!=bits(0.0)) throw new Exception("empty contract");
        if(operation(path,empty,null,ptrdiff_t.min,ptrdiff_t.min,1,value) || bits(value)!=bits(0.0)) throw new Exception("invalid empty contract");
        if(!operation(path,view,data.ptr,4,1,0,value) || bits(value)!=bits(1.0)) throw new Exception("cancellation graph changed");
    }
    writeln("contracts PASS invalid/empty/out-zero/cancellation");
}
void run()
{
    contracts();
    enum layouts=["contiguous","padded","negative-row","universal","universal-negative","repeated-row","zero-both"];
    foreach(corpus; ["positive","cancellation","exponents","negative-zero","infinity","opposite-infinities","nan","subnormals"])
    foreach(layout; layouts) runCase(31,17,layout,corpus,false);
    writeln("semantic PASS cases=56 finite-bitwise NaN-class source-preserved");
    foreach(dimensions; [[31UL,17UL],[256UL,128UL],[2048UL,512UL]])
    foreach(layout; layouts)
    foreach(corpus; ["positive","cancellation"]) runCase(dimensions[0],dimensions[1],layout,corpus,true);
    writefln("m3_strict_reduction PASS cases=42 sink=%s",sink);
}
