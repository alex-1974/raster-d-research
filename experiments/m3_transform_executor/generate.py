#!/usr/bin/env python3
"""Pin production; vary only post-validation execution, preserving inherited tests."""
import hashlib
import re
import subprocess
from pathlib import Path
ROOT = Path(__file__).resolve().parent
PRODUCTION = ROOT.parents[2] / 'raster-d'
BASELINE = 'b263477bdbbe0dc3e8c469ac3867eda345ba364c'
SHA256 = '1cea3d33bc3d2e36999c9b70a87bc241c3f08c19f9187fce0b2c63533e27111d'
head = subprocess.check_output(['git','rev-parse','HEAD'],cwd=PRODUCTION,text=True).strip()
if head != BASELINE or subprocess.run(['git','diff','--quiet','HEAD'],cwd=PRODUCTION).returncode:
    raise SystemExit('Production must be a clean checkout at '+BASELINE)
raw = (PRODUCTION/'source/raster/transform.d').read_bytes()
if hashlib.sha256(raw).hexdigest() != SHA256:
    raise SystemExit('Production differs from pinned '+BASELINE)
out = ROOT/'source/raster/research/m3_transform_executor/generated'
out.mkdir(parents=True, exist_ok=True)
for form in ['pointer', 'slice']:
    text = raw.decode().replace('module raster.transform;',
        'module raster.research.m3_transform_executor.generated.'+form+';',1)
    text, count = re.subn(r'enum RasterTransformError : ubyte\n\{.*?\n\}',
        'import raster.transform : RasterTransformError;',text,count=1,flags=re.S)
    assert count == 1
    text = text.replace('tryTransformRasterPlane', 'tryCandidate')
    marker = '\n\n    foreach (y; 0 .. source.height)'
    assert text.count(marker) == 1
    dispatch = '''

    if (sourceSampleStrideElements == 1 && destinationSampleStrideElements == 1)
    {
        execute!transform(sourceBase, sourceRowStrideElements,
            source.width, source.height, destinationBase, destinationRowStrideElements);
        return true;
    }
'''
    text = text.replace(marker,dispatch+marker,1)
    common = '''
// Preconditions: caller has validated both views, shape, injectivity and exact
// physical disjointness; both sample strides are one. All row/sample addresses
// and coordinate products are within retained validated backing. No pointer or
// slice escapes this invocation. Transform returns a value under the unchanged
// production attribute contract.
'''
    if form == 'pointer':
        kernel = '''
private void execute(alias transform,T)(scope const(T)* source, ptrdiff_t sr,
    size_t width, size_t height, scope T* destination, ptrdiff_t dr)
@trusted pure nothrow @nogc
{
    foreach (y; 0 .. height)
    {
        const row = source + cast(ptrdiff_t)y*sr;
        auto target = destination + cast(ptrdiff_t)y*dr;
        foreach (x; 0 .. width)
            target[x] = invokePointTransform!transform(row[x]);
    }
}
'''
    else:
        kernel = '''
// Only row pointer arithmetic and bounded slice construction require trust.
private const(T)[] readRow(T)(return scope const(T)* base, size_t y,
    ptrdiff_t stride, size_t width) @trusted pure nothrow @nogc
{ return (base + cast(ptrdiff_t)y*stride)[0 .. width]; }
private T[] writeRow(T)(return scope T* base, size_t y,
    ptrdiff_t stride, size_t width) @trusted pure nothrow @nogc
{ return (base + cast(ptrdiff_t)y*stride)[0 .. width]; }
private void execute(alias transform,T)(scope const(T)* source, ptrdiff_t sr,
    size_t width, size_t height, scope T* destination, ptrdiff_t dr)
@safe pure nothrow @nogc
{
    foreach (y; 0 .. height)
    {
        scope const row = readRow(source,y,sr,width);
        scope auto target = writeRow(destination,y,dr,width);
        foreach (x; 0 .. width)
            target[x] = invokePointTransform!transform(row[x]);
    }
}
'''
    (out/(form+'.d')).write_text('// Generated from '+BASELINE+'; SHA256 '+SHA256+'\n'+text+common+kernel)
    print('generated',form,'inherited unittest blocks=',len(re.findall(r'^unittest$',text,re.M)))
