#!/usr/bin/env python3
"""Validate all raw medians, contracts, case identities and backing hashes."""
import argparse,ast,re,statistics
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('directory',type=Path);p.add_argument('--environment',choices=['container','xps'],default='container');a=p.parse_args()
forms=['public','approved','cpp','relation'];records={}
for compiler in ['dmd','ldc']:
 records[compiler]=[]
 for n in range(1,4):
  s=(a.directory/f'{compiler}-run-{n}.txt').read_text()
  assert 'contracts PASS four-operations invalid/shape/noninjective/overlap/empty/no-write shared-disjoint' in s
  assert 'semantic PASS cases=32' in s and 'm3_copy_conversion PASS cases=96' in s
  cases={}
  for line in s.splitlines():
   if not line.startswith('case '):continue
   key=line[5:line.index(' public_raw=')];med=[]
   for f in forms:
    raw=ast.literal_eval(re.search(f+r'_raw=(\[[^]]+\])',line)[1]);assert len(raw)==12 and all(v>=0 for v in raw)
    median=int(re.search(f+r'_ns=(\d+)',line)[1]);assert median==int(statistics.median(raw));med.append(median)
    if 'w=2048 h=512' in key and f!='relation':assert min(raw)>0
   hashes=tuple(re.search(f+r'=([0-9a-f]+)',line)[1] for f in ['source','result'])
   assert key not in cases;cases[key]=(med,hashes)
  assert len(cases)==96;records[compiler].append(cases)
reference=records['dmd'][0]
for runs in records.values():
 for run in runs:
  assert run.keys()==reference.keys() and all(run[k][1]==reference[k][1] for k in reference)
print(f'# Public copy / exact conversion — {a.environment} baseline\n')
print('Pinned production: `1671fb2e51a7b1e7311f78f575d9457e9f279fd4`. All six processes pass 96 timed cases, 32 additional semantic cases and public error/no-write/shared-disjoint controls. All output/source fingerprints match across compilers/processes.\n')
print('Public is end-to-end. Approved is unchanged private semantic traversal with prior approval supplied by fixtures (even flat copy does not use memcpy here). C++ is execution-only, using per-row memcpy for unit-stride copy and scalar-source exact conversion, without D validation/classification; an external C ABI call is added. Relation is the unchanged exact affine classifier alone plus stride/base retrieval, not the complete public validation. Ratios diagnose opportunities; these are not equivalent complete-library comparisons or promoted candidates. Costs are not subtracted to infer causality.\n')
print('Twelve cyclic rounds rotate all four paths through each position three times. Two warmups; destination reset and complete source/output/padding checks outside every timer. Large positive execution samples are required; tiny zero medians are retained and ratios omitted. Frequency/thermal controls are unchanged. AArch64 unqualified. No production selection without XPS and a validation-preserving candidate.\n')
print('| Case | Compiler | Public/Approved | Public/C++ | Public ns (three medians) | Relation ns (three medians) | Public process spread |')
print('| --- | --- | --- | --- | --- | --- | --- |')
for k in reference:
 for c,runs in records.items():
  def ratio(f):
   if any(run[k][0][f]==0 for run in runs):return 'below clock resolution'
   vals=[run[k][0][0]/run[k][0][f] for run in runs];return f'{min(vals):.3f}–{max(vals):.3f}x'
  vals=[run[k][0][0] for run in runs];spread=f'{(max(vals)/min(vals)-1)*100:.2f}%' if min(vals)>0 else 'below clock resolution'
  print('| '+k+' | '+c+' | '+ratio(1)+' | '+ratio(2)+' | '+str(vals)+' | '+str([run[k][0][3] for run in runs])+' | '+spread+' |')
