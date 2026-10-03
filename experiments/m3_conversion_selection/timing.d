// Fixture-only bridge. All calls use separately allocated, disjoint live
// arrays. Geometry corners and complete indexed oracles are checked before
// timing. Matrix dimensions/strides are bounded, so ptrdiff_t math cannot
// overflow. The external reference accesses exactly these affine samples,
// preserves source, and stores/escapes no pointer. No Production trust added.
extern(C) void cppApprovedConversion(scope const(ubyte)* src, scope float* dst,
    ptrdiff_t sr, ptrdiff_t sx, ptrdiff_t dr, ptrdiff_t dx,
    size_t width, size_t height) @system nothrow @nogc;
private void cppFixture(scope const(ubyte)[] src, scope float[] dst,
    size_t so, size_t targetOffset, ptrdiff_t sr, ptrdiff_t sx,
    ptrdiff_t dr, ptrdiff_t dx, size_t width, size_t height)
    @trusted nothrow @nogc
{
    cppApprovedConversion(src.ptr+so,dst.ptr+targetOffset,sr,sx,dr,dx,width,height);
}
private bool cppTimed(scope const(ubyte)[] src,scope float[] dst,
    size_t so,size_t targetOffset,ptrdiff_t sr,ptrdiff_t sx,ptrdiff_t dr,ptrdiff_t dx,
    size_t width,size_t height) @safe nothrow @nogc
{cppFixture(src,dst,so,targetOffset,sr,sx,dr,dx,width,height);return true;}
// Appended to the mechanically adapted, pinned public backing fixture.
import std.datetime.stopwatch : StopWatch;
import std.stdio : writefln;
import std.conv : to;
import std.algorithm.comparison : min,max;

private void timedCase(size_t w,size_t h,string layout,uint process)
{
    ptrdiff_t sr=cast(ptrdiff_t)(w+32),sx=1,dr=sr,dx=1;
    switch(layout){
        case "contiguous":sr=dr=cast(ptrdiff_t)w;break;
        case "padded":break;
        case "negative-source":sr=-sr;break;
        case "negative-both":sr=-sr;dr=-dr;break;
        case "universal":sx=dx=2;sr=dr=cast(ptrdiff_t)(2*w+32);break;
        case "repeated-source":sr=0;break;
        default:throw new Exception("timing layout");
    }
    const sg=geometry(w,h,sr,sx),dg=geometry(w,h,dr,dx);
    auto input=new ubyte[sg.length];auto output=new float[dg.length];
    auto expected=new float[dg.length];
    input[]=sample!ubyte(29);output[]=sample!float(17);expected[]=sample!float(17);
    foreach(y;0..h)foreach(x;0..w)input[index(sg,x,y)]=sample!ubyte(y*w+x);
    foreach(y;0..h)foreach(x;0..w)expected[index(dg,x,y)]=cast(float)input[index(sg,x,y)];
    // Explicit corner proof outside timing; extrema of each bounded affine
    // map occur at these corners. Indexed expected writes add a full oracle.
    foreach(g;[sg,dg])foreach(y;[0UL,h-1])foreach(x;[0UL,w-1]) {
        const signedIndex=cast(ptrdiff_t)g.offset+cast(ptrdiff_t)y*g.row+cast(ptrdiff_t)x*g.sample;
        if(signedIndex<0 || cast(size_t)signedIndex>=g.length)throw new Exception("geometry bounds");
    }
    const sourceHash=fingerprint!ubyte(input), expectedHash=fingerprint!float(expected);
    const PlaneDescriptor[1] sd=[PlaneDescriptor(input.ptr+sg.offset,sr,sx)];
    const PlaneDescriptor[1] dd=[PlaneDescriptor(output.ptr+dg.offset,dr,dx)];
    const ResourceEntry[1] rs=[ResourceEntry(output.ptr,output.length*float.sizeof,null,null,ResourceAccess.readWrite)];
    scope auto source=makeRasterViewAssumeValidated!ubyte(sd[],Region2D(0,0,w,h));
    scope auto target=writable!float(rs[],dd[],Region2D(0,0,w,h));
    const iterations=max(8UL,min(4096UL,262_144UL/(w*h)));
    foreach(path;0..4)foreach(warmup;0..8)
        if(path==3 ? !cppTimed(input,output,sg.offset,dg.offset,sr,sx,dr,dx,w,h) : publicCall(path,source,0,target,0)!=0)throw new Exception("warmup failure");
    foreach(round;0..9)foreach(position;0..4){
        const path=(position+round+process)%4;
        output[]=sample!float(17);
        StopWatch clock;clock.start();
        foreach(iteration;0..iterations)
            if(path==3 ? !cppTimed(input,output,sg.offset,dg.offset,sr,sx,dr,dx,w,h) : publicCall(path,source,0,target,0)!=0)throw new Exception("timing public failure");
        clock.stop();
        const elapsed=clock.peek.total!"nsecs";
        // Independent complete backing/source oracle, excluded from timing.
        if(fingerprint!ubyte(input)!=sourceHash)throw new Exception("timed source changed");
        foreach(i;0..output.length)
            if(bits(output[i])!=bits(expected[i]))throw new Exception("timed destination/guard mismatch");
        const actualHash=fingerprint!float(output);
        if(actualHash!=expectedHash)throw new Exception("timed hash mismatch");
        writefln("TIME\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s",
            process,w,h,layout,round,position,path,iterations,elapsed,actualHash);
    }
}
void main(string[] args)
{
    import std.algorithm.comparison : min,max;
    const process=args.length>1 ? to!uint(args[1]) : 0;
    enum layouts=["contiguous","padded","negative-source","negative-both","universal","repeated-source"];
    foreach(width;[1UL,7UL,15UL,16UL,17UL,23UL,31UL,32UL,33UL,47UL,63UL,64UL,65UL,95UL,127UL,128UL,129UL,255UL,256UL,257UL,511UL,512UL,513UL,2048UL])foreach(height;[1UL,17UL,128UL])foreach(layout;layouts)
        timedCase(width,height,layout,process);
    foreach(layout;layouts)timedCase(2048,512,layout,process);
}
