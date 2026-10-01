#!/usr/bin/env python3
"""Preserve the public wrapper and all eight tests; vary only approved execution."""
import hashlib
import re
import subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parent
PRODUCTION=ROOT.parents[2]/'raster-d'
BASELINE='d4763ff0b95999743ea43d0b1dcca44fc68773d1'
if subprocess.check_output(['git','rev-parse','HEAD'],cwd=PRODUCTION,text=True).strip()!=BASELINE or subprocess.run(['git','diff','--quiet','HEAD'],cwd=PRODUCTION).returncode:
    raise SystemExit('Production must be clean at '+BASELINE)
raw={}
for path,digest in [('source/raster/fill.d','fd6262553b694ac4aafda2b7f989d4bbc6a0d7db773c4946ea715f0d211e4916'),('source/raster/internal/fill_dispatch.d','9e5df8c3e81ba7bb548843a8fff9ca5c1ee49ea39e4b30f944184d35bfd1d320')]:
    data=(PRODUCTION/path).read_bytes()
    assert hashlib.sha256(data).hexdigest()==digest
    raw[path]=data.decode()
out=ROOT/'source/raster/research/m3_fill_executor/generated'
out.mkdir(parents=True,exist_ok=True)
for form in ['pointer','slice']:
    module='raster.research.m3_fill_executor.generated.'+form
    public=raw['source/raster/fill.d'].replace('module raster.fill;','module '+module+';').replace('import raster.internal.fill_dispatch :','import '+module+'_dispatch :').replace('tryFillRasterPlane(', 'tryCandidate(')
    internal=raw['source/raster/internal/fill_dispatch.d'].replace('module raster.internal.fill_dispatch;','module '+module+'_dispatch;')
    marker='    foreach (y; 0 .. destination.height)'
    assert internal.count(marker)==1
    internal=internal.replace(marker,"""    if (sampleStrideElements == 1)
    {
        execute(destination.executionRegionBase(planeIndex),rowStrideElements,
            destination.width,destination.height,value);
        return true;
    }

"""+marker,1)
    proof="""
// Caller has validated writable backing and non-empty geometry; sample stride
// is one. Reachable row offsets and bounded indices are valid. Repeated or
// overlapping rows are permitted: each logical write assigns the identical
// sample value. No injectivity/noalias/ownership assertion is introduced.
// Operand pointers/slices do not escape; Universal execution is unchanged.
"""
    if form=='pointer':
        kernel="""
private void execute(T)(scope T* base,ptrdiff_t stride,
    size_t width,size_t height,T value) @trusted nothrow @nogc
{
    foreach (y; 0 .. height)
    {
        auto row = base + cast(ptrdiff_t)y*stride;
        foreach (x; 0 .. width) row[x] = value;
    }
}
"""
    else:
        kernel="""
private T[] writeRow(T)(return scope T* base,size_t y,ptrdiff_t stride,
    size_t width) @trusted nothrow @nogc
{ return (base + cast(ptrdiff_t)y*stride)[0 .. width]; }
private void execute(T)(scope T* base,ptrdiff_t stride,
    size_t width,size_t height,T value) @safe nothrow @nogc
{
    foreach (y; 0 .. height)
    {
        scope auto row = writeRow(base,y,stride,width);
        row[] = value;
    }
}
"""
    (out/(form+'.d')).write_text('// Pinned '+BASELINE+'\n'+public)
    (out/(form+'_dispatch.d')).write_text('// Pinned '+BASELINE+'\n'+internal+proof+kernel)
    print('generated',form,'inherited tests',len(re.findall(r'^unittest$',public,re.M)))
