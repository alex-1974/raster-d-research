/++ Vector kernel: SSE2 unpack/conversion with one bounded unaligned load. +/
version (RasterForcePortable) private enum vectorEnabled=false;
else version (DigitalMars) {
    version (X86_64) private enum vectorEnabled=true;
    else private enum vectorEnabled=false;
} else private enum vectorEnabled=false;
static if(vectorEnabled){
    import core.simd : ubyte16,float4,__simd,XMM,loadUnaligned;
    /++ Safety: sole caller supplies a live scoped 16-byte subslice.
        The intrinsic reads exactly those 16 bytes with no alignment
        requirement. No pointer escapes. Assertions are diagnostic; the
        safe caller establishes the length bound in release too. +/
    private ubyte16 readVectorBlock(scope const(ubyte)[] block)
        @trusted pure nothrow @nogc
    {
        assert(block.length==16);
        return loadUnaligned(cast(const(ubyte16)*)block.ptr);
    }
}
private void convertApprovedRow(scope const(ubyte)[] row,
    scope float[] destination) @safe pure nothrow @nogc
{
    assert(row.length==destination.length);
    size_t x;
    static if(vectorEnabled){
        while(row.length-x>=16){
            const packed=readVectorBlock(row[x..x+16]);
            const ubyte16 zero=0;
            const lowWords=__simd(XMM.PUNPCKLBW,packed,zero);
            const highWords=__simd(XMM.PUNPCKHBW,packed,zero);
            const float4 a=cast(float4)__simd(XMM.CVTDQ2PS,__simd(XMM.PUNPCKLWD,lowWords,zero));
            const float4 b=cast(float4)__simd(XMM.CVTDQ2PS,__simd(XMM.PUNPCKHWD,lowWords,zero));
            const float4 c=cast(float4)__simd(XMM.CVTDQ2PS,__simd(XMM.PUNPCKLWD,highWords,zero));
            const float4 d=cast(float4)__simd(XMM.CVTDQ2PS,__simd(XMM.PUNPCKHWD,highWords,zero));
            destination[x..x+4]=a.array[];destination[x+4..x+8]=b.array[];
            destination[x+8..x+12]=c.array[];destination[x+12..x+16]=d.array[];
            x+=16;
        }
    }
    foreach(p;x..row.length)destination[p]=cast(float)row[p];
}
