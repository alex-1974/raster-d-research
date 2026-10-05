#!/usr/bin/env python3
"""Generate current-Production versus exact-SSE2 full-public conversion."""
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent
PRODUCTION = ROOT.parents[2] / "raster-d"
PIN = "24d948255df014c683d79c5508f13248806062dc"

DISPATCH = PRODUCTION / "source/raster/internal/conversion_dispatch.d"
PUBLIC = PRODUCTION / "source/raster/conversion.d"
FIXTURE = PRODUCTION / "tests/integration/raster_copy_conversion/source/probe.d"
GENERATED = ROOT / "generated"

# Retained verbatim from PR33 selected64.d's qualified exact vector kernel.
VECTOR_SOURCE = r'''version (RasterForcePortable) private enum researchVectorEnabled=false;
else version (DigitalMars) {
    version (X86_64) private enum researchVectorEnabled=true;
    else private enum researchVectorEnabled=false;
} else private enum researchVectorEnabled=false;
static if(researchVectorEnabled){
    import core.simd : ubyte16,float4,__simd,XMM,loadUnaligned;
    /++ Safety: sole caller supplies a live scoped 16-byte subslice.
        The intrinsic reads exactly those 16 bytes with no alignment
        requirement. No pointer escapes. Assertions are diagnostic; the
        safe caller establishes the length bound in release too. +/
    private ubyte16 readResearchVectorBlock(scope const(ubyte)[] block)
        @trusted pure nothrow @nogc
    {
        assert(block.length==16);
        return loadUnaligned(cast(const(ubyte16)*)block.ptr);
    }
    /++ Safety: sole caller supplies a live writable four-float subslice.
        The intrinsic writes exactly its 16 bytes, unaligned, and exposes
        no pointer or reference. Scalar tails remain safe indexed writes. +/
    private void writeResearchVectorBlock(scope float[] block,float4 result)
        @trusted pure nothrow @nogc
    {
        assert(block.length==4);
        import core.simd : storeUnaligned;
        storeUnaligned(cast(float4*)block.ptr,result);
    }
}
private void convertResearchVectorRow(scope const(ubyte)[] row,
    scope float[] destination) @safe pure nothrow @nogc
{
    assert(row.length==destination.length);
    size_t x;
    static if(researchVectorEnabled){
        while(row.length-x>=16){
            const packed=readResearchVectorBlock(row[x..x+16]);
            const ubyte16 zero=0;
            const lowWords=__simd(XMM.PUNPCKLBW,packed,zero);
            const highWords=__simd(XMM.PUNPCKHBW,packed,zero);
            const float4 a=cast(float4)__simd(XMM.CVTDQ2PS,__simd(XMM.PUNPCKLWD,lowWords,zero));
            const float4 b=cast(float4)__simd(XMM.CVTDQ2PS,__simd(XMM.PUNPCKHWD,lowWords,zero));
            const float4 c=cast(float4)__simd(XMM.CVTDQ2PS,__simd(XMM.PUNPCKLWD,highWords,zero));
            const float4 d=cast(float4)__simd(XMM.CVTDQ2PS,__simd(XMM.PUNPCKHWD,highWords,zero));
            writeResearchVectorBlock(destination[x..x+4],a);writeResearchVectorBlock(destination[x+4..x+8],b);
            writeResearchVectorBlock(destination[x+8..x+12],c);writeResearchVectorBlock(destination[x+12..x+16],d);
            x+=16;
        }
    }
    foreach(p;x..row.length)destination[p]=cast(float)row[p];
}
'''


def git_head(path):
    return subprocess.check_output(
        ["git", "-C", str(path), "rev-parse", "HEAD"], text=True
    ).strip()


def make_dispatch(source):
    source = source.replace(
        "module raster.internal.conversion_dispatch;",
        """module raster.variant_vector_refresh_dispatch;

private ubyte researchExecutionForm;

void setResearchConversionExecutionForm(ubyte form)
@safe nothrow @nogc
{
    assert(form <= 1);
    researchExecutionForm = form;
}""",
        1,
    )

    marker = "private void executeApprovedRows(S, D)(\n"
    start = source.index(marker)
    source = source[:start] + VECTOR_SOURCE + "\n\n" + source[start:]

    old = r'''            version (DigitalMars)
            {
                version (X86_64)
                {
                    if (width >= 64)
                    {
                        convertApprovedUbyteToFloatDmdRow(
                            row,
                            destination
                        );
                        continue;
                    }
                }
            }'''
    new = r'''            version (DigitalMars)
            {
                version (X86_64)
                {
                    if (width >= 64)
                    {
                        if (researchExecutionForm == 1)
                        {
                            convertResearchVectorRow(
                                row,
                                destination
                            );
                        }
                        else
                        {
                            convertApprovedUbyteToFloatDmdRow(
                                row,
                                destination
                            );
                        }
                        continue;
                    }
                }
            }'''
    if source.count(old) != 1:
        raise ValueError("current DMD Production route changed")
    return source.replace(old, new, 1)


def make_public(source):
    source = source.replace(
        "module raster.conversion;",
        "module raster.variant_vector_refresh;",
        1,
    )
    source = source.replace(
        "import raster.internal.conversion_dispatch :",
        "import raster.variant_vector_refresh_dispatch :",
        1,
    )
    source, count = re.subn(
        r"enum UbyteToFloatConversionError : ubyte\n\{.*?\n\}",
        "import raster.conversion : UbyteToFloatConversionError;",
        source,
        count=1,
        flags=re.S,
    )
    if count != 1:
        raise ValueError("public error enum changed")
    return source


def make_fixture(source):
    source = source.replace(
        "module raster.tests.copy_conversion_contract;",
        "module raster.tests.vector_refresh_contract;",
        1,
    )
    source = source.replace(
        "import std.stdio : writeln;",
        """import core.time : MonoTime;
import std.algorithm.sorting : sort;
import std.conv : to;
import std.stdio : writeln, writefln;
import raster.variant_vector_refresh :
    researchConvert = tryConvertUbyteToFloatPlane;
import raster.variant_vector_refresh_dispatch :
    setResearchConversionExecutionForm;""",
        1,
    )

    old_call = "ok=tryConvertUbyteToFloatPlane(s,si,d,di,e);error=cast(uint)e;"
    new_call = """setResearchConversionExecutionForm(cast(ubyte) path);
        ok=researchConvert(s,si,d,di,e);error=cast(uint)e;"""
    if source.count(old_call) != 1:
        raise ValueError("fixture public conversion call changed")
    source = source.replace(old_call, new_call, 1)

    source = source.replace(
        'case "negative-source":sr=-sr;break;',
        'case "negative-source":sr=-sr;break;\n'
        '        case "negative-target":dr=-dr;break;',
        1,
    )
    source = source.replace(
        "private void verifyCase(S,D)(size_t w,size_t h,string layout)",
        "private void verifyCase(S,D)(size_t w,size_t h,string layout,uint path=0)",
        1,
    )
    old = 'if(publicCall(0,source,0,target,0)!=0)throw new Exception("public operation failure");'
    if source.count(old) != 1:
        raise ValueError("fixture verify call changed")
    source = source.replace(
        old,
        'if(publicCall(path,source,0,target,0)!=0)throw new Exception("public operation failure");',
        1,
    )

    source = source.replace(
        "contracts!(ubyte,float)(0);sharedBacking(0);",
        "foreach(path;0..2){contracts!(ubyte,float)(path);sharedBacking(path);sharedCanonicalConversion(path);}",
        1,
    )
    source = source.replace("    sharedCanonicalConversion(0);\n", "", 1)
    source = source.replace(
        'enum layouts=["contiguous","padded","negative-source","negative-both",',
        'enum layouts=["contiguous","padded","negative-source","negative-target","negative-both",',
        1,
    )
    old = "verifyCase!(ubyte,float)(size[0],size[1],layout);"
    if source.count(old) != 1:
        raise ValueError("fixture conversion matrix changed")
    source = source.replace(
        old,
        "foreach(path;0..2)verifyCase!(ubyte,float)(size[0],size[1],layout,path);",
        1,
    )

    anchor = "void main(){run();}"
    if source.count(anchor) != 1:
        raise ValueError("fixture main anchor changed")
    source = source.replace(anchor, "void runVerification(){run();}", 1)
    source = source.replace("unittest{run();}", "")

    timing = r'''

private enum size_t timingWarmups = 5;
private enum size_t timingSamples = 11;

private long timingMedian(long[timingSamples] values)
{
    sort(values[]);
    return values[timingSamples / 2];
}

private long timedPublic(
    ubyte form,
    size_t iterations,
    scope RasterView!ubyte source,
    scope ref WritableRasterView!float target)
{
    setResearchConversionExecutionForm(form);
    UbyteToFloatConversionError error;
    const start = MonoTime.currTime;
    foreach (_; 0 .. iterations)
    {
        if (!researchConvert(source, 0, target, 0, error) || error != 0)
            assert(0, "timing public conversion failed");
    }
    return (MonoTime.currTime - start).total!"nsecs";
}

private void timingCase(
    size_t w,
    size_t h,
    string layout,
    size_t targetSamples,
    uint process)
{
    ptrdiff_t sr = cast(ptrdiff_t)(w + 32);
    ptrdiff_t sx = 1;
    ptrdiff_t dr = sr;
    ptrdiff_t dx = 1;

    switch (layout)
    {
        case "contiguous": sr = dr = cast(ptrdiff_t)w; break;
        case "padded": break;
        case "negative-source": sr = -sr; break;
        case "negative-target": dr = -dr; break;
        case "negative-both": sr = -sr; dr = -dr; break;
        case "repeated-source": sr = 0; break;
        case "universal":
            sx = dx = 2;
            sr = dr = cast(ptrdiff_t)(2 * w + 32);
            break;
        default: assert(0, "unknown timing layout");
    }

    const sg = geometry(w, h, sr, sx);
    const dg = geometry(w, h, dr, dx);
    auto input = new ubyte[sg.length];
    auto output = new float[dg.length];

    input[] = sample!ubyte(29);
    output[] = sample!float(17);
    foreach (y; 0 .. h)
        foreach (x; 0 .. w)
            input[index(sg, x, y)] = sample!ubyte(y * w + x);

    const PlaneDescriptor[1] sd =
        [PlaneDescriptor(input.ptr + sg.offset, sr, sx)];
    const PlaneDescriptor[1] dd =
        [PlaneDescriptor(output.ptr + dg.offset, dr, dx)];
    const ResourceEntry[1] rs =
        [ResourceEntry(
            output.ptr,
            output.length * float.sizeof,
            null,
            null,
            ResourceAccess.readWrite)];

    scope auto source =
        makeRasterViewAssumeValidated!ubyte(sd[], Region2D(0, 0, w, h));
    scope auto target =
        writable!float(rs[], dd[], Region2D(0, 0, w, h));

    foreach (form; 0 .. 2)
    {
        setResearchConversionExecutionForm(cast(ubyte)form);
        UbyteToFloatConversionError error;
        assert(researchConvert(source, 0, target, 0, error));
        assert(error == UbyteToFloatConversionError.none);
        foreach (y; 0 .. h)
            foreach (x; 0 .. w)
                assert(
                    output[index(dg, x, y)]
                    == cast(float)input[index(sg, x, y)]);
    }

    size_t iterations = targetSamples / (w * h);
    if (iterations == 0) iterations = 1;
    if (iterations > 32768) iterations = 32768;

    foreach (_; 0 .. timingWarmups)
    {
        timedPublic(0, iterations, source, target);
        timedPublic(1, iterations, source, target);
    }

    long[timingSamples] productionSamples;
    long[timingSamples] vectorSamples;

    foreach (round; 0 .. timingSamples)
    {
        if (((round + process) & 1) == 0)
        {
            productionSamples[round] =
                timedPublic(0, iterations, source, target);
            vectorSamples[round] =
                timedPublic(1, iterations, source, target);
        }
        else
        {
            vectorSamples[round] =
                timedPublic(1, iterations, source, target);
            productionSamples[round] =
                timedPublic(0, iterations, source, target);
        }
    }

    const productionMedian = timingMedian(productionSamples);
    const vectorMedian = timingMedian(vectorSamples);
    writefln(
        "m3_vector_refresh process=%s width=%s height=%s layout=%s iterations=%s production_ns=%s vector_ns=%s production_over_vector=%.6f source_fp=%016x target_fp=%016x",
        process,
        w,
        h,
        layout,
        iterations,
        productionMedian,
        vectorMedian,
        cast(double)productionMedian / cast(double)vectorMedian,
        fingerprint!ubyte(input),
        fingerprint!float(output));
}

private void runTiming(bool longBlock, uint process)
{
    const targetSamples = longBlock ? 8_388_608UL : 262_144UL;
    const size_t[2][] shapes =
    [
        [31UL, 17UL],
        [63UL, 17UL],
        [64UL, 17UL],
        [65UL, 17UL],
        [96UL, 17UL],
        [256UL, 128UL],
        [2048UL, 512UL],
    ];
    const layouts =
    [
        "contiguous",
        "padded",
        "negative-source",
        "negative-target",
        "negative-both",
        "repeated-source",
        "universal",
    ];

    foreach (shape; shapes)
        foreach (layout; layouts)
            timingCase(shape[0], shape[1], layout, targetSamples, process);
}

void main(string[] args)
{
    if (args.length == 1)
    {
        runVerification();
        return;
    }
    if (args.length != 3)
        assert(0, "usage: binary [--timing-short|--timing-long PROCESS]");

    const process = args[2].to!uint;
    assert(process < 6);
    if (args[1] == "--timing-short")
        runTiming(false, process);
    else if (args[1] == "--timing-long")
        runTiming(true, process);
    else
        assert(0, "unknown timing mode");
}
'''
    source += timing
    return source


def main():
    if git_head(PRODUCTION) != PIN:
        raise SystemExit(
            f"Production pin mismatch: expected {PIN}, got {git_head(PRODUCTION)}"
        )

    GENERATED.mkdir(parents=True, exist_ok=True)
    raster = GENERATED / "raster"
    raster.mkdir(exist_ok=True)

    (raster / "variant_vector_refresh_dispatch.d").write_text(
        make_dispatch(DISPATCH.read_text())
    )
    (raster / "variant_vector_refresh.d").write_text(
        make_public(PUBLIC.read_text())
    )
    (GENERATED / "app.d").write_text(
        make_fixture(FIXTURE.read_text())
    )

    print("PASS generated vector refresh from Production", PIN)
    print("PASS form0=current Production; form1=SSE2 only for DMD x86-64 width>=64")


if __name__ == "__main__":
    main()
