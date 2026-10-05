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
        "module app;",
        1,
    )
    source = source.replace(
        "import std.stdio : writeln;",
        """import std.stdio : writeln;
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
    source = source.replace(anchor, "void main(){run();" + boundary + "}", 1)
    source = source.replace("unittest{run();}", "")
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
