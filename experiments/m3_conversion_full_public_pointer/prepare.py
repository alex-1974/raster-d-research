#!/usr/bin/env python3
"""Generate the shared-entry full-public candidate from pinned Production."""
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent
RESEARCH = ROOT.parents[1]
PRODUCTION = ROOT.parents[2] / "raster-d"
PIN = "10549e045bfa5a99afe6552b0fb41b76fe203fa5"

DISPATCH = PRODUCTION / "source/raster/internal/conversion_dispatch.d"
PUBLIC = PRODUCTION / "source/raster/conversion.d"
FIXTURE = PRODUCTION / "tests/integration/raster_copy_conversion/source/probe.d"
GENERATED = ROOT / "generated"


def git_head(path):
    return subprocess.check_output(
        ["git", "-C", str(path), "rev-parse", "HEAD"], text=True
    ).strip()


def make_dispatch(source):
    source = source.replace(
        "module raster.internal.conversion_dispatch;",
        """module raster.variant_full_public_pointer_dispatch;

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
    body_start = source.index("{", start)
    # This exact attribute sequence belongs to executeApprovedRows at the pin.
    attrs = source.rfind("@safe pure nothrow @nogc", start, body_start)
    if attrs < 0:
        raise ValueError("executeApprovedRows attributes changed")
    source = source[:attrs] + "@safe nothrow @nogc" + source[attrs + len("@safe pure nothrow @nogc"):]

    helper = r'''
/++
    Research-only pointer/count row body.

    Safety: the caller passes the same already-approved equal-length row slices
    used by the current Production conversion loop. Pointers remain local and
    every access is indexed only within row.length.
+/
private void convertResearchPointerRow(
    scope const(ubyte)[] row,
    scope float[] destination
)
@trusted pure nothrow @nogc
{
    assert(row.length == destination.length);
    scope const(ubyte)* sourcePointer = row.ptr;
    scope float* destinationPointer = destination.ptr;
    foreach (i; 0 .. row.length)
        destinationPointer[i] = cast(float) sourcePointer[i];
}

'''
    source = source[:start] + helper + source[start:]

    old = r'''    foreach (y; 0 .. height)
    {
        scope const row =
            readApprovedRow(source, sourceRowStride, y, width);
        scope auto destination =
            writeApprovedRow(target, targetRowStride, y, width);

        static if (is(S == D))
            destination[] = row[];
        else
        {
            static assert(is(S == ubyte) && is(D == float));
            foreach (x, value; row)
                destination[x] = cast(float)value;
        }
    }'''
    new = r'''    version (DigitalMars)
    {
        version (X86_64)
            const useResearchPointer =
                researchExecutionForm == 1 && width >= 64;
        else
            enum useResearchPointer = false;
    }
    else
        enum useResearchPointer = false;

    foreach (y; 0 .. height)
    {
        scope const row =
            readApprovedRow(source, sourceRowStride, y, width);
        scope auto destination =
            writeApprovedRow(target, targetRowStride, y, width);

        static if (is(S == D))
            destination[] = row[];
        else
        {
            static assert(is(S == ubyte) && is(D == float));

            if (useResearchPointer)
                convertResearchPointerRow(row, destination);
            else
            {
                foreach (x, value; row)
                    destination[x] = cast(float)value;
            }
        }
    }'''
    if source.count(old) != 1:
        raise ValueError("approved row body changed")
    return source.replace(old, new, 1)


def make_public(source):
    source = source.replace(
        "module raster.conversion;",
        "module raster.variant_full_public_pointer;",
        1,
    )
    source = source.replace(
        "import raster.internal.conversion_dispatch :",
        "import raster.variant_full_public_pointer_dispatch :",
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
        "module raster.tests.full_public_pointer_contract;",
        1,
    )
    source = source.replace(
        "import std.stdio : writeln;",
        """import core.time : MonoTime;
import std.algorithm.sorting : sort;
import std.conv : to;
import std.stdio : writeln, writefln;
import raster.variant_full_public_pointer :
    researchConvert = tryConvertUbyteToFloatPlane;
import raster.variant_full_public_pointer_dispatch :
    setResearchConversionExecutionForm;""",
        1,
    )
    old_call = "ok=tryConvertUbyteToFloatPlane(s,si,d,di,e);error=cast(uint)e;"
    new_call = """setResearchConversionExecutionForm(cast(ubyte) path);
        ok=researchConvert(s,si,d,di,e);error=cast(uint)e;"""
    if source.count(old_call) != 1:
        raise ValueError("fixture conversion call changed")
    source = source.replace(old_call, new_call, 1)

    source = source.replace(
        "private void verifyCase(S,D)(size_t w,size_t h,string layout)",
        "private void verifyCase(S,D)(size_t w,size_t h,string layout,uint path=0)",
        1,
    )
    old = "if(publicCall(0,source,0,target,0)!=0)throw new Exception(\"public operation failure\");"
    if source.count(old) != 1:
        raise ValueError("fixture verify call changed")
    source = source.replace(
        old,
        "if(publicCall(path,source,0,target,0)!=0)throw new Exception(\"public operation failure\");",
        1,
    )

    old = "contracts!(ubyte,float)(0);sharedBacking(0);"
    if source.count(old) != 1:
        raise ValueError("fixture conversion contract anchor changed")
    source = source.replace(
        old,
        "foreach(path;0..2){contracts!(ubyte,float)(path);sharedBacking(path);sharedCanonicalConversion(path);}",
        1,
    )
    source = source.replace("    sharedCanonicalConversion(0);\n", "", 1)
    old = "verifyCase!(ubyte,float)(size[0],size[1],layout);"
    if source.count(old) != 1:
        raise ValueError("fixture conversion matrix anchor changed")
    source = source.replace(
        old,
        "foreach(path;0..2)verifyCase!(ubyte,float)(size[0],size[1],layout,path);",
        1,
    )

    boundary = r'''
    foreach (width; [63UL, 64UL, 65UL])
        foreach (layout; ["contiguous","padded","negative-source",
                          "negative-both","universal","repeated-source"])
            foreach (path; 0 .. 2)
                verifyCase!(ubyte,float)(width, 3, layout, path);
    writeln("PASS shared-entry boundary: 36 width-63/64/65 public cases");
'''
    anchor = "void main(){run();}"
    if source.count(anchor) != 1:
        raise ValueError("fixture main anchor changed")
    source = source.replace(
        anchor,
        "void runVerification(){run();" + boundary + "}",
        1,
    )
    source = source.replace("unittest{run();}", "")

    timing = r'''

private enum size_t timingWarmups = 4;
private enum size_t timingSamples = 9;

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
        case "contiguous":
            sr = dr = cast(ptrdiff_t)w;
            break;
        case "padded":
            break;
        case "negative-source":
            sr = -sr;
            break;
        case "negative-both":
            sr = -sr;
            dr = -dr;
            break;
        case "repeated-source":
            sr = 0;
            break;
        case "universal":
            sx = dx = 2;
            sr = dr = cast(ptrdiff_t)(2 * w + 32);
            break;
        default:
            assert(0, "unknown timing layout");
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
    if (iterations == 0)
        iterations = 1;
    if (iterations > 32768)
        iterations = 32768;

    foreach (_; 0 .. timingWarmups)
    {
        timedPublic(0, iterations, source, target);
        timedPublic(1, iterations, source, target);
    }

    long[timingSamples] currentSamples;
    long[timingSamples] pointerSamples;

    foreach (round; 0 .. timingSamples)
    {
        if (((round + process) & 1) == 0)
        {
            currentSamples[round] =
                timedPublic(0, iterations, source, target);
            pointerSamples[round] =
                timedPublic(1, iterations, source, target);
        }
        else
        {
            pointerSamples[round] =
                timedPublic(1, iterations, source, target);
            currentSamples[round] =
                timedPublic(0, iterations, source, target);
        }
    }

    const currentMedian = timingMedian(currentSamples);
    const pointerMedian = timingMedian(pointerSamples);
    writefln(
        "m3_full_public process=%s width=%s height=%s layout=%s iterations=%s current_ns=%s pointer_ns=%s current_over_pointer=%.6f source_fp=%016x target_fp=%016x",
        process,
        w,
        h,
        layout,
        iterations,
        currentMedian,
        pointerMedian,
        cast(double)currentMedian / cast(double)pointerMedian,
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
        "negative-both",
        "repeated-source",
        "universal",
    ];

    foreach (shape; shapes)
        foreach (layout; layouts)
            timingCase(
                shape[0],
                shape[1],
                layout,
                targetSamples,
                process);
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

    dispatch = make_dispatch(DISPATCH.read_text())
    public = make_public(PUBLIC.read_text())
    fixture = make_fixture(FIXTURE.read_text())

    (raster / "variant_full_public_pointer_dispatch.d").write_text(dispatch)
    (raster / "variant_full_public_pointer.d").write_text(public)
    (GENERATED / "app.d").write_text(fixture)

    print("PASS generated candidate from Production", PIN)
    print("PASS one public Research entry; selector changes only approved row execution")


if __name__ == "__main__":
    main()
