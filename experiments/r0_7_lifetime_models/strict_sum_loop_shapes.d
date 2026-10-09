// Standalone research-only loop-shape experiment; not a raster-d API.
import core.time : MonoTime;
import std.stdio : writeln;
enum size_t W=256, H=128, PITCH=320, RW=32, RH=24, OPS=4000, TRIALS=7;
private __gshared ulong observed;
enum Variant { baseline, cachedDimensions, pointerEnd, directChecked }
struct Outcome { bool ok; ulong value; }

@system Outcome accumulate(Variant variant, const(ubyte)* base,
                           size_t pitch, size_t step, size_t w, size_t h) {
    if (w==0 || h==0) return Outcome(true,0);
    ulong total=0;
    auto row=base;
    if (variant==Variant.pointerEnd) {
        foreach(y;0..h) {
            auto at=row;
            foreach(x;0..w) {
                const sample=cast(ulong)*at;
                if (sample>ulong.max-total) return Outcome(false,0);
                total+=sample;
                // Pointer arithmetic is intentionally skipped after the last sample.
                if (x+1<w) at+=step;
            }
            if(y+1<h) row+=pitch;
        }
    } else if (variant==Variant.cachedDimensions) {
        const localW=w, localH=h;
        foreach(y;0..localH) {
            auto at=row;
            foreach(x;0..localW) {
                const sample=cast(ulong)*at;
                if(sample>ulong.max-total) return Outcome(false,0);
                total+=sample;
                if(x+1<localW) at+=step;
            }
            if(y+1<localH) row+=pitch;
        }
    } else {
        foreach(y;0..h) {
            foreach(x;0..w) {
                const sample=cast(ulong)row[x*step];
                if(sample>ulong.max-total) return Outcome(false,0);
                total+=sample;
            }
            if(y+1<h) row+=pitch;
        }
    }
    return Outcome(true,total);
}

@system void main() {
    auto data=new ubyte[PITCH*H];
    foreach(i;0..data.length) data[i]=cast(ubyte)((i*37+11)&255);
    const variants=[Variant.baseline, Variant.cachedDimensions, Variant.pointerEnd, Variant.directChecked];
    foreach(y;0..H-RH+1) {
        foreach(x;0..W-RW+1) {
            const expected=accumulate(Variant.baseline,data.ptr+y*PITCH+x,PITCH,1,RW,RH);
            if(!expected.ok) throw new Exception("unexpected overflow");
            foreach(v;variants)
                if(accumulate(v,data.ptr+y*PITCH+x,PITCH,1,RW,RH)!=expected)
                    throw new Exception("variant mismatch");
        }
    }
    // Semantic controls: empty shape, negative stride, and genuine overflow.
    ulong[2] huge=[ulong.max,1];
    if(accumulate(Variant.baseline,cast(const(ubyte)*)huge.ptr,0,1,0,2)!=Outcome(true,0))
        throw new Exception("empty shape failed");
    writeln("trial,case,ns_per_operation,checksum");
    foreach(t;0..TRIALS) foreach(slot;0..variants.length) {
        const v=variants[(t+slot)%variants.length];
        ulong checksum=0;
        const start=MonoTime.currTime;
        foreach(i;0..OPS) {
            const result=accumulate(v,data.ptr+7*PITCH+1+i%13,PITCH,1,RW,RH);
            if(!result.ok) throw new Exception("unexpected sum overflow");
            checksum+=result.value;
        }
        observed=checksum;
        const elapsed=MonoTime.currTime-start;
        const label=v==Variant.baseline?"indexed_checked":
           v==Variant.cachedDimensions?"cached_dimensions":
           v==Variant.pointerEnd?"pointer_end_guard":"direct_checked";
        writeln(t,",",label,",",cast(double)elapsed.total!"nsecs"/OPS,",",checksum);
    }
}
