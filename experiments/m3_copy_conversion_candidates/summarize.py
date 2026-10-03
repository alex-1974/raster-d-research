#!/usr/bin/env python3
"""Validate all raw medians, contracts, case identities and backing hashes."""
import argparse,ast,re,statistics
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('directory',type=Path);p.add_argument('--environment',choices=['container','xps'],default='container');a=p.parse_args()
forms=['public','bounds','execute','combined','cpp'];records={}
for compiler in ['dmd','ldc']:
 records[compiler]=[]
 for n in range(1,4):
  s=(a.directory/f'{compiler}-run-{n}.txt').read_text()
  assert 'contracts PASS four-public-paths four-operations invalid/shape/noninjective/overlap/empty/no-write shared-disjoint' in s
  assert 'semantic PASS cases=32' in s and 'm3_copy_conversion_candidates PASS cases=96' in s
  cases={}
  for line in s.splitlines():
   if not line.startswith('case '):continue
   key=line[5:line.index(' public_raw=')];med=[]
   for f in forms:
    raw=ast.literal_eval(re.search(f+r'_raw=(\[[^]]+\])',line)[1]);assert len(raw)==15 and all(v>=0 for v in raw)
    median=int(re.search(f+r'_ns=(\d+)',line)[1]);assert median==int(statistics.median(raw));med.append(median)
    if 'w=2048 h=512' in key:assert min(raw)>0
   hashes=tuple(re.search(f+r'=([0-9a-f]+)',line)[1] for f in ['source','result'])
   assert key not in cases;cases[key]=(med,hashes)
  assert len(cases)==96;records[compiler].append(cases)
reference=records['dmd'][0]
for runs in records.values():
 for run in runs:
  assert run.keys()==reference.keys() and all(run[k][1]==reference[k][1] for k in reference)
print(f'# Full public copy/conversion candidates — {a.environment} evidence\n')
print('Production: `1671fb2e51a7b1e7311f78f575d9457e9f279fd4`. All six processes pass 96 timed cases, 32 extra semantic cases and public controls for all four public paths. Source/output hashes match across compilers/processes.\n')
print('Bounds, Execute and Combined are complete pinned public consumers, changing only conservative relation rejection and/or unit-sample-stride row execution (plus already-approved flat conversion). Original Universal execution, errors, injectivity, overlap and arithmetic-failure fallback remain. C++ is execution-only and omits validation while adding a separate C ABI call; it is not a complete-library comparison. No reassociation/precision change, compiler switch, explicit SIMD or threading.\n')
print('Fifteen cyclic rounds rotate five paths through every order position three times. Two warmups; reset and full backing checks are outside each timer. All large samples are positive; tiny zero medians retain data and omit ratios. VM is diagnostic, XPS is required for promotion; AArch64 unqualified.\n')
print('| Case | Compiler | Public/Bounds | Public/Execute | Public/Combined | Combined/C++ | Public/Combined process spread |')
print('| --- | --- | --- | --- | --- | --- | --- |')
for k in reference:
 for c,runs in records.items():
  def ratio(a,b):
   if any(run[k][0][b]==0 for run in runs):return 'below clock resolution'
   vals=[run[k][0][a]/run[k][0][b] for run in runs];return f'{min(vals):.3f}–{max(vals):.3f}x'
  def spread(f):
   vals=[run[k][0][f] for run in runs]
   return f'{(max(vals)/min(vals)-1)*100:.2f}%' if min(vals)>0 else 'below clock resolution'
  print('| '+k+' | '+c+' | '+' | '.join([ratio(0,1),ratio(0,2),ratio(0,3),ratio(3,4)])+' | '+spread(0)+' / '+spread(3)+' |')
