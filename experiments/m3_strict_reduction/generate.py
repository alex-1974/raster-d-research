#!/usr/bin/env python3
"""Pin both complete consumer modules and vary only approved execution."""
import hashlib,re,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parent
PRODUCTION=ROOT.parents[2]/'raster-d'
BASELINE='1671fb2e51a7b1e7311f78f575d9457e9f279fd4'
if subprocess.check_output(['git','rev-parse','HEAD'],cwd=PRODUCTION,text=True).strip()!=BASELINE or subprocess.run(['git','diff','--quiet','HEAD'],cwd=PRODUCTION).returncode:
    raise SystemExit('Production must be clean at '+BASELINE)
raw={}
for path,digest in [('source/raster/reduction.d','7f5826d679dd3e648dec513f72b4562bf19a9e0b868ca35f8afb44545fbd19e5'),('source/raster/internal/reduction_dispatch.d','70327b685a4e302222dab71b03e7d58181f1d4a3e5dc39b70a33179ff79dbc5d')]:
    data=(PRODUCTION/path).read_bytes(); assert hashlib.sha256(data).hexdigest()==digest
    raw[path]=data.decode()
out=ROOT/'source/raster/research/m3_strict_reduction/generated';out.mkdir(parents=True,exist_ok=True)
for form in ['pointer','slice']:
    module='raster.research.m3_strict_reduction.generated.'+form
    public=raw['source/raster/reduction.d'].replace('module raster.reduction;','module '+module+';').replace('import raster.internal.reduction_dispatch :','import '+module+'_dispatch :').replace('trySumFloatToDouble(', 'tryCandidate(')
    internal=raw['source/raster/internal/reduction_dispatch.d'].replace('module raster.internal.reduction_dispatch;','module '+module+'_dispatch;')
    marker='    final switch (traits.layout2D)'
    assert internal.count(marker)==1
    internal=internal.replace(marker,"""    if (traits.layout2D != PlaneExecutionLayout2D.universal)
    {
        ptrdiff_t sr,sx;
        const ok=view.tryExecutionPlaneStrides(planeIndex,sr,sx);
        assert(ok && sx==1);
        return execute(view.executionRegionBase(planeIndex),sr,view.width,view.height);
    }

"""+marker,1)
    proof="""
// Caller validates plane traits and non-empty retained backing, sample stride
// one and representable signed row/index addresses. No pointer/slice escapes.
// One double accumulator is carried across every row: no reassociation, per-row
// subtotal, lane split, numeric conversion or source mutation is introduced.
"""
    if form=='pointer':
        kernel="""
private double execute(scope const(float)* base,ptrdiff_t stride,size_t width,
    size_t height) @trusted nothrow @nogc
{
    double total=0.0;
    foreach (y; 0 .. height)
    {
        const row=base+cast(ptrdiff_t)y*stride;
        foreach (x; 0 .. width) total += cast(double)row[x];
    }
    return total;
}
"""
    else:
        kernel="""
private const(float)[] readRow(return scope const(float)* base,size_t y,
    ptrdiff_t stride,size_t width) @trusted nothrow @nogc
{ return (base+cast(ptrdiff_t)y*stride)[0 .. width]; }
private double execute(scope const(float)* base,ptrdiff_t stride,size_t width,
    size_t height) @safe nothrow @nogc
{
    double total=0.0;
    foreach (y; 0 .. height)
    {
        scope const row=readRow(base,y,stride,width);
        foreach (value; row) total += cast(double)value;
    }
    return total;
}
"""
    (out/(form+'.d')).write_text('// Pinned '+BASELINE+'\n'+public)
    (out/(form+'_dispatch.d')).write_text('// Pinned '+BASELINE+'\n'+internal+proof+kernel)
    print('generated',form,'inherited tests',len(re.findall(r'^unittest$',public+internal,re.M)))
