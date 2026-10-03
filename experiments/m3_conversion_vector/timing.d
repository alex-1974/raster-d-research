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
    const sourceHash=fingerprint!ubyte(input), expectedHash=fingerprint!float(expected);
    const PlaneDescriptor[1] sd=[PlaneDescriptor(input.ptr+sg.offset,sr,sx)];
    const PlaneDescriptor[1] dd=[PlaneDescriptor(output.ptr+dg.offset,dr,dx)];
    const ResourceEntry[1] rs=[ResourceEntry(output.ptr,output.length*float.sizeof,null,null,ResourceAccess.readWrite)];
    scope auto source=makeRasterViewAssumeValidated!ubyte(sd[],Region2D(0,0,w,h));
    scope auto target=writable!float(rs[],dd[],Region2D(0,0,w,h));
    const iterations=max(8UL,min(4096UL,8_388_608UL/(w*h)));
    foreach(path;0..3)foreach(warmup;0..8)
        if(publicCall(path,source,0,target,0)!=0)throw new Exception("warmup failure");
    foreach(round;0..9)foreach(position;0..3){
        const path=(position+round+process)%3;
        output[]=sample!float(17);
        StopWatch clock;clock.start();
        foreach(iteration;0..iterations)
            if(publicCall(path,source,0,target,0)!=0)throw new Exception("timing public failure");
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
    foreach(size;[[31UL,17UL],[256UL,128UL],[2048UL,512UL]])foreach(layout;layouts)
        timedCase(size[0],size[1],layout,process);
}
