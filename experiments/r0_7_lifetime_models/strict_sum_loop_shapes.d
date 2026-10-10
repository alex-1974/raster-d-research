// Research-only controlled strict-sum loop shapes; no production API.
module strict_sum_loop_shapes;
import core.time : MonoTime;
import std.stdio : writeln;

enum size_t W=256, H=128, PITCH=320, RW=32, RH=24, OPS=4000, TRIALS=7;
private __gshared ulong observed;

// A signed-stride, already-validated research descriptor.
// The caller must prove that every addressed element lies in the backing.
struct Desc(T) {
    const(T)* base;
    ptrdiff_t rowStride;
    ptrdiff_t sampleStride;
    size_t width;
    size_t height;
}
enum Variant { guarded, cachedDimensions, indexed, alternateAdd, checkedHelper }
struct Outcome { bool ok; ulong value; }

// Deliberately separately callable, so linked codegen can establish whether
// this source form leaves a hot-loop call. No allocator, exception or GC.
@safe nothrow @nogc
bool addWithOutput(ulong lhs, ulong rhs, out ulong result) {
    if (rhs > ulong.max - lhs) {
        result = 0;
        return false;
    }
    result = lhs + rhs;
    return true;
}

@system Outcome strictSum(Variant variant, T)(Desc!T d) {
    if (d.width==0 || d.height==0) return Outcome(true, 0);
    ulong total;
    static if (variant==Variant.cachedDimensions) {
        // Only change: cache all geometry/stride fields before traversal.
        const w=d.width, h=d.height;
        const rs=d.rowStride, ss=d.sampleStride;
        auto row=d.base;
        foreach(y;0..h) {
            auto p=row;
            foreach(x;0..w) {
                const v=cast(ulong)*p;
                if(v>ulong.max-total) return Outcome(false,0);
                total+=v;
                if(x+1<w) p+=ss;
            }
            if(y+1<h) row+=rs;
        }
    } else static if(variant==Variant.indexed) {
        // Only change from guarded: use an indexed row access rather
        // than an incrementing per-sample pointer.
        auto row=d.base;
        foreach(y;0..d.height) {
            foreach(x;0..d.width) {
                const v=cast(ulong)row[cast(ptrdiff_t)x*d.sampleStride];
                if(v>ulong.max-total) return Outcome(false,0);
                total+=v;
            }
            if(y+1<d.height) row+=d.rowStride;
        }
    } else {
        auto row=d.base;
        foreach(y;0..d.height) {
            auto p=row;
            foreach(x;0..d.width) {
                const v=cast(ulong)*p;
                static if(variant==Variant.checkedHelper) {
                    ulong next;
                    if(!addWithOutput(total,v,next)) return Outcome(false,0);
                    total=next;
                } else static if(variant==Variant.alternateAdd) {
                    // Equivalent overflow criterion via wrapped addition.
                    const next=total+v;
                    if(next<total) return Outcome(false,0);
                    total=next;
                } else {
                    if(v>ulong.max-total) return Outcome(false,0);
                    total+=v;
                }
                if(x+1<d.width) p+=d.sampleStride;
            }
            if(y+1<d.height) row+=d.rowStride;
        }
    }
    return Outcome(true,total);
}

@system Outcome run(T)(Variant v, Desc!T d) {
    final switch(v) {
        case Variant.guarded: return strictSum!(Variant.guarded)(d);
        case Variant.cachedDimensions: return strictSum!(Variant.cachedDimensions)(d);
        case Variant.indexed: return strictSum!(Variant.indexed)(d);
        case Variant.alternateAdd: return strictSum!(Variant.alternateAdd)(d);
        case Variant.checkedHelper: return strictSum!(Variant.checkedHelper)(d);
    }
}

@system void validate(T)(Desc!T d) {
    const reference=strictSum!(Variant.guarded)(d);
    foreach(v;[Variant.cachedDimensions,Variant.indexed,Variant.alternateAdd,Variant.checkedHelper])
        if(run(v,d)!=reference)
            throw new Exception("strict sum variant mismatch");
}

@system void main() {
    auto data=new ubyte[PITCH*H];
    foreach(i;0..data.length) data[i]=cast(ubyte)((i*37+11)&255);
    // Every valid ROI origin, including the last row and column.
    foreach(y;0..H-RH+1) foreach(x;0..W-RW+1)
        validate(Desc!ubyte(data.ptr+y*PITCH+x,PITCH,1,RW,RH));
    // Different positive sample stride, negative row and sample strides,
    // zero-sized shapes, and actual ulong overflow.
    validate(Desc!ubyte(data.ptr, PITCH,2,16,16));
    validate(Desc!ubyte(data.ptr+(RH-1)*PITCH, -cast(ptrdiff_t)PITCH,1,RW,RH));
    validate(Desc!ubyte(data.ptr+RW-1,PITCH,-1,RW,RH));
    validate(Desc!ubyte(null,ptrdiff_t.min,ptrdiff_t.min,0,9));
    validate(Desc!ubyte(null,ptrdiff_t.min,ptrdiff_t.min,9,0));
    ulong[3] overflow=[ulong.max,1,0];
    auto overflowD=Desc!ulong(overflow.ptr,3,1,3,1);
    validate(overflowD);
    if(strictSum!(Variant.guarded)(overflowD).ok)
        throw new Exception("overflow not detected");
    ulong[3] exact=[1,2,3];
    validate(Desc!ulong(exact.ptr,3,1,3,1));
    writeln("trial,case,ns_per_operation,checksum");
    foreach(t;0..TRIALS) foreach(slot;0..5) {
        const v=cast(Variant)((t+slot)%5);
        ulong checksum;
        auto start=MonoTime.currTime;
        foreach(i;0..OPS) {
            auto d=Desc!ubyte(data.ptr+7*PITCH+1+i%13,PITCH,1,RW,RH);
            const result=run(v,d);
            if(!result.ok) throw new Exception("unexpected overflow");
            checksum+=result.value;
        }
        observed=checksum;
        auto elapsed=MonoTime.currTime-start;
        const label=v==Variant.guarded?"guarded_pointer":
                    v==Variant.cachedDimensions?"cached_dimensions":
                    v==Variant.indexed?"indexed_pointer":
                    v==Variant.alternateAdd?"alternate_checked_add":"checked_helper";
        writeln(t,",",label,",",cast(double)elapsed.total!"nsecs"/OPS,",",checksum);
    }
}
