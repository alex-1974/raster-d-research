#!/usr/bin/env python3
"""Generate exact executor helpers behind concrete float/ubyte diagnostic entries."""
import sys
from pathlib import Path
root=Path(__file__).resolve().parent
out=Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
for form in ['pointer','slice']:
    text=(root/f'source/raster/research/m3_transform_executor/generated/{form}.d').read_text()
    helpers=text[text.index('// Preconditions:'):]
    prefix='''module codegen;
float transform(float x) @safe pure nothrow @nogc { return x*1.25f+0.375f; }
ubyte transform(ubyte x) @safe pure nothrow @nogc { return cast(ubyte)((x*37+11)%251); }
T invokePointTransform(alias f,T)(T x) @safe pure nothrow @nogc { return f(x); }
'''
    suffix=''
    for typ in ['float','ubyte']:
        suffix+=f'''
void probe{typ.title()}(scope const({typ})* source, ptrdiff_t sr,
    size_t w,size_t h,scope {typ}* dest,ptrdiff_t dr) @safe pure nothrow @nogc
{{ execute!transform(source,sr,w,h,dest,dr); }}
'''
    (out/(form+'.d')).write_text(prefix+helpers+suffix)
