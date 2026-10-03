#!/usr/bin/env python3
"""Expose unchanged private diagnostics from complete pinned production modules."""
import hashlib,re,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parent
PROD=ROOT.parents[2]/'raster-d'
BASE='1671fb2e51a7b1e7311f78f575d9457e9f279fd4'
HASHES={'copy':'becd5a3e28334f970ede05f95213bb6e96fb147c66e5a90b044f1be06b4ee1e0','conversion':'55c86a892871aa102cf6444798982cca3740de3079769172d11bc63b832a1428'}
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=PROD,text=True).strip()==BASE
assert subprocess.run(['git','diff','--quiet','HEAD'],cwd=PROD).returncode==0
for op,sha in {'copy':'bfd9402eca1530e6f39316e6adb337f27799221d90cb9e79937621f0c0f05802','conversion':'837fe4ef749a059991311155acd7c3127022da636143782893e5d8c0077d8d00'}.items():
 assert hashlib.sha256((PROD/f'source/raster/{op}.d').read_bytes()).hexdigest()==sha
out=ROOT/'source/raster/research/m3_copy_conversion/generated';out.mkdir(exist_ok=True)
for op,sha in HASHES.items():
 raw=(PROD/f'source/raster/internal/{op}_dispatch.d').read_bytes();assert hashlib.sha256(raw).hexdigest()==sha
 s=raw.decode().replace(f'module raster.internal.{op}_dispatch;',f'module raster.research.m3_copy_conversion.generated.{op};',1)
 if op=='copy':
  helper='copyApprovedAffine2D';rel='classifySameTypeAffinePhysicalRelation';template='(T)';src='T';dst='T'
 else:
  helper='convertApprovedUbyteToFloatAffine2D';rel='classifyUbyteToFloatAffinePhysicalRelation';template='';src='ubyte';dst='float'
 s+=f'''
// Diagnostic entry points only: fixtures prove equal non-empty shapes, valid
// plane 0, injective destination and physically disjoint samples before use.
// These wrappers expose unchanged private production functions, not new kernels.
void approved{template}(scope RasterView!{src} source,
    scope ref WritableRasterView!{dst} target) @safe nothrow @nogc
{{ {helper}(source,0,target,0); }}
AffineByteOverlapRelation exactRelation{template}(scope RasterView!{src} source,
    scope ref WritableRasterView!{dst} target) @safe nothrow @nogc
{{
    ptrdiff_t sr,sx,dr,dx;
    const a=source.tryExecutionPlaneStrides(0,sr,sx);
    const b=target.tryExecutionPlaneStrides(0,dr,dx);
    assert(a && b && !source.empty);
    return {rel}(source.executionRegionBase(0),sr,sx,
        target.executionRegionBase(0),dr,dx,source.width,source.height);
}}
'''
 (out/f'{op}.d').write_text('// Generated from '+BASE+' SHA256 '+sha+'\n'+s)
 print('generated',op,'inherited tests',len(re.findall(r'^unittest$',s,re.M)))
