// Appended to the fixture's setup/public-call definitions, not the timed driver.
private void vectorSharedBacking(uint path)
{
    foreach(width;[16UL,17UL,31UL,63UL,64UL,65UL]){
        float[512] storage;auto bytes=(cast(ubyte*)storage.ptr)[0..storage.sizeof];
        foreach(i;0..bytes.length)bytes[i]=cast(ubyte)(i*37+11);auto expected=bytes.dup;
        foreach(y;0..4)foreach(x;0..width){
            union U{float value;ubyte[4] representation;}U v;v.value=cast(float)bytes[512*y+x];
            foreach(k;0..4)expected[512*y+128+4*x+k]=v.representation[k];
        }
        const PlaneDescriptor[1] sd=[PlaneDescriptor(bytes.ptr,512,1)],dd=[PlaneDescriptor(storage.ptr+32,128,1)];
        const ResourceEntry[1] rs=[ResourceEntry(storage.ptr,storage.sizeof,null,null,ResourceAccess.readWrite)];
        scope auto source=makeRasterViewAssumeValidated!ubyte(sd[],Region2D(0,0,width,4));
        scope auto target=writable!float(rs[],dd[],Region2D(0,0,width,4));
        if(publicCall(path,source,0,target,0)!=0 || bytes!=expected)
            throw new Exception("vector-active shared backing mismatch");
    }
}
void main(){foreach(path;0..3)vectorSharedBacking(path);writeln("PASS 18 selection-active shared-backing cases, overlapping envelopes, disjoint samples");}
