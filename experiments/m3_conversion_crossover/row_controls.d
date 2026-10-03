// Appended to each actual generated kernel, preserving its private scope.
import core.stdc.fenv : fegetround,fesetround,FE_TONEAREST,FE_DOWNWARD,FE_UPWARD,FE_TOWARDZERO;
import std.stdio : writeln;
private uint bits(float value) @safe nothrow @nogc
{union U{float f;uint u;}U v;v.f=value;return v.u;}
void main()
{
    const saved=fegetround();scope(exit)assert(fesetround(saved)==0);
    size_t cases;
    foreach(mode;[FE_TONEAREST,FE_DOWNWARD,FE_UPWARD,FE_TOWARDZERO]){
        assert(fesetround(mode)==0);
        foreach(width;0..34)foreach(sourceOffset;0..16)foreach(targetOffset;0..4){
            ubyte[320] source;float[320] target;
            foreach(i;0..source.length)source[i]=cast(ubyte)(i*37+11);
            target[]=-17.0f;const before=source;
            convertApprovedRow(source[sourceOffset..sourceOffset+width],target[targetOffset..targetOffset+width]);
            assert(source==before);
            foreach(i;0..target.length)
                assert(bits(target[i])==bits(i>=targetOffset && i<targetOffset+width ? cast(float)source[sourceOffset+i-targetOffset] : -17.0f));
            ++cases;
        }
        foreach(width;[63UL,64UL,65UL,255UL,256UL,257UL])foreach(sourceOffset;0..16)foreach(targetOffset;0..4){
            ubyte[320] source;float[320] target;
            foreach(i;0..source.length)source[i]=cast(ubyte)(i*37+11);
            target[]=-17.0f;const before=source;
            convertApprovedRow(source[sourceOffset..sourceOffset+width],target[targetOffset..targetOffset+width]);
            assert(source==before);
            foreach(i;0..target.length)
                assert(bits(target[i])==bits(i>=targetOffset && i<targetOffset+width ? cast(float)source[sourceOffset+i-targetOffset] : -17.0f));
            ++cases;
        }
    }
    assert(cases==10240);
    guardPages();
    writeln("PASS vector row: ",cases," widths/offsets/rounding cases; enabled=",vectorEnabled);
}

// Fixture-only raw mapping. Guard pages turn any tail overread/overwrite
// into an immediate process failure; the operation itself retains attributes.
private void guardPages()
{
    import core.sys.posix.sys.mman : mmap,munmap,mprotect,PROT_READ,PROT_WRITE,PROT_NONE,MAP_PRIVATE,MAP_ANON,MAP_FAILED;
    import core.sys.posix.unistd : sysconf,_SC_PAGESIZE;
    const page=cast(size_t)sysconf(_SC_PAGESIZE);assert(page>=4096);
    auto input=mmap(null,2*page,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANON,-1,0);
    assert(input!=MAP_FAILED);scope(exit)assert(munmap(input,2*page)==0);
    auto output=mmap(null,2*page,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANON,-1,0);
    assert(output!=MAP_FAILED);scope(exit)assert(munmap(output,2*page)==0);
    assert(mprotect(cast(ubyte*)input+page,page,PROT_NONE)==0);
    assert(mprotect(cast(ubyte*)output+page,page,PROT_NONE)==0);
    auto source=(cast(ubyte*)input)[0..page];
    auto target=(cast(float*)output)[0..page/float.sizeof];
    foreach(i;0..source.length)source[i]=cast(ubyte)(i*37+11);
    size_t cases;
    foreach(width;0..34){
        target[]=-17.0f;
        convertApprovedRow(source[$-width..$],target[$-width..$]);
        foreach(i;0..target.length)
            assert(bits(target[i])==bits(i>=target.length-width ? cast(float)source[source.length-target.length+i] : -17.0f));
        ++cases;
    }
    foreach(width;[63UL,64UL,65UL,255UL,256UL,257UL]){
        target[]=-17.0f;
        convertApprovedRow(source[$-width..$],target[$-width..$]);
        foreach(i;0..target.length)
            assert(bits(target[i])==bits(i>=target.length-width ? cast(float)source[source.length-target.length+i] : -17.0f));
        ++cases;
    }
    foreach(i;0..source.length)assert(source[i]==cast(ubyte)(i*37+11));
    assert(cases==40);writeln("PASS guard pages: 40 widths end at inaccessible pages");
}
