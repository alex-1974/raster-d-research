#!/usr/bin/env python3
"""Mechanically pin complete modules; vary relation and execution independently."""
import hashlib,re,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parent;PROD=ROOT.parents[2]/'raster-d'
BASE='1671fb2e51a7b1e7311f78f575d9457e9f279fd4'
HASHES={'copy':'becd5a3e28334f970ede05f95213bb6e96fb147c66e5a90b044f1be06b4ee1e0','conversion':'55c86a892871aa102cf6444798982cca3740de3079769172d11bc63b832a1428'}
PUBLIC={'copy':'bfd9402eca1530e6f39316e6adb337f27799221d90cb9e79937621f0c0f05802','conversion':'837fe4ef749a059991311155acd7c3127022da636143782893e5d8c0077d8d00'}
BOUNDS='896da9b81f03fb0a5848043280c34597a3fcd5426cb8e3c0990045b760f07d0f'
PREFIX='raster.research.m3_copy_conversion_candidates.generated.'
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=PROD,text=True).strip()==BASE
assert subprocess.run(['git','diff','--quiet','HEAD'],cwd=PROD).returncode==0
out=ROOT/'source/raster/research/m3_copy_conversion_candidates/generated';out.mkdir(exist_ok=True)
def pinned(path,sha):
 raw=(PROD/path).read_bytes();assert hashlib.sha256(raw).hexdigest()==sha;return raw.decode()
b=pinned('source/raster/internal/validated_affine_relation.d',BOUNDS).replace('module raster.internal.validated_affine_relation;',f'module {PREFIX}bounds;',1)
b+='\n'+(ROOT/'bounds_extension.d.txt').read_text();(out/'bounds.d').write_text(b)
print('generated bounds total tests',len(re.findall(r'^unittest$',b,re.M)))
helpers=(ROOT/'row_kernels.d.txt').read_text()
for form in ['bounds','execute','combined']:
 for op,sha in HASHES.items():
  stem=form+'_'+op
  s=pinned(f'source/raster/internal/{op}_dispatch.d',sha).replace(f'module raster.internal.{op}_dispatch;',f'module {PREFIX}{stem}_dispatch;',1)
  if form in ['bounds','combined']:
   old='classifySameTypeAffine2DByteOverlap' if op=='copy' else 'classifyUbyteToFloatAffine2DByteOverlap'
   new='classifyValidatedSameTypeAffine2DByteOverlap' if op=='copy' else 'classifyCandidateUbyteToFloatRelation'
   # Only the operation-local private relation delegates to the new wrapper.
   # Direct original classifier imports remain for inherited controls.
   pattern=r'return '+old+r'\('
   s,n=re.subn(pattern,'return '+new+'(',s);assert n==1
   s=s.replace(f'module {PREFIX}{stem}_dispatch;',f'module {PREFIX}{stem}_dispatch;\nimport {PREFIX}bounds : {new};',1)
  if form in ['execute','combined']:
   function='copyApprovedAffine2D' if op=='copy' else 'convertApprovedUbyteToFloatAffine2D'
   pos=s.index('void '+function);body=s.index('{',pos)
   injected='''
    ptrdiff_t sr,sx,dr,dx;
    const a=source.tryExecutionPlaneStrides(sourcePlaneIndex,sr,sx);
    const b=target.tryExecutionPlaneStrides(targetPlaneIndex,dr,dx);
    assert(a && b);
    if(sx==1 && dx==1)
    {
        executeRows(source.executionRegionBase(sourcePlaneIndex),sr,
            target.executionRegionBase(targetPlaneIndex),dr,source.width,source.height);
        return;
    }
'''
   s=s[:body+1]+injected+s[body+1:]
   if op=='conversion':
    pattern=r'const converted =\s*scalarConvertUbyteToFloatContiguous1D\(\s*asMirContiguousFlat\(\s*source,\s*sourcePlaneIndex\s*\),\s*asMirTargetContiguousFlat\(\s*contiguousDestination\s*\)\s*\);\s*assert\(converted\);'
    replacement='executeRows(sourceBase,sourceRowStrideElements,\n                        destinationBase,destinationRowStrideElements,source.width,source.height);'
    s,n=re.subn(pattern,replacement,s);assert n==1
   s+='\n'+helpers
  (out/f'{stem}_dispatch.d').write_text('// Generated from '+BASE+' SHA256 '+sha+'\n'+s)
  p=pinned(f'source/raster/{op}.d',PUBLIC[op]).replace(f'module raster.{op};',f'module {PREFIX}{stem};',1)
  p=p.replace(f'import raster.internal.{op}_dispatch :',f'import {PREFIX}{stem}_dispatch :',1)
  enum='RasterCopyError' if op=='copy' else 'UbyteToFloatConversionError'
  p,n=re.subn(r'enum '+enum+r' : ubyte\n\{.*?\n\}',f'import raster.{op} : {enum};',p,count=1,flags=re.S);assert n==1
  name='tryCopyRasterPlane' if op=='copy' else 'tryConvertUbyteToFloatPlane'
  p=p.replace(name,'tryCandidate')
  (out/f'{stem}.d').write_text('// Generated from '+BASE+' SHA256 '+PUBLIC[op]+'\n'+p)
  print('generated',form,op,'inherited public/internal tests',len(re.findall(r'^unittest$',p+'\n'+s,re.M)))
