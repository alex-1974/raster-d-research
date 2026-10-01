#!/usr/bin/env python3
"""Validate raw timings and fingerprints before reporting paired speedups."""
import argparse
import ast
import re
import statistics
from pathlib import Path

parser=argparse.ArgumentParser()
parser.add_argument('directory',type=Path)
parser.add_argument('--environment',choices=['container','xps'],default='container')
args=parser.parse_args()
records={}
for compiler in ['dmd','ldc']:
    records[compiler]=[]
    for run in range(1,4):
        path=args.directory/f'{compiler}-run-{run}.txt'
        text=path.read_text()
        assert text.count('special-float PASS')==1
        assert 'm3_fill_executor PASS cases=70' in text
        assert text.count('contracts PASS type=')==3
        cases={}
        for line in text.splitlines():
            if not line.startswith('case '): continue
            key=line[5:line.index(' public_raw=')]
            raw=[]
            for form in ['public','pointer','slice']:
                values=ast.literal_eval(re.search(rf'{form}_raw=(\[[^]]+\])',line)[1])
                ns=int(re.search(rf'{form}_ns=(\d+)',line)[1])
                assert len(values)==9 and all(v>=0 for v in values)
                if 'w=2048 h=512' in key: assert all(v>0 for v in values)
                assert statistics.median(values)==ns
                raw.append(ns)
            fingerprint=re.search(r'hash=([0-9a-f]+)',line)[1]
            assert key not in cases
            cases[key]=(raw,fingerprint)
        assert len(cases)==70,(path,len(cases))
        records[compiler].append(cases)
reference=records['dmd'][0]
for runs in records.values():
    for cases in runs:
        assert cases.keys()==reference.keys()
        assert all(cases[k][1]==reference[k][1] for k in reference),'cross-process/compiler hash mismatch'
print(f'# Generic fill executor — {args.environment} evidence\n')
print('Baseline: `d4763ff0b95999743ea43d0b1dcca44fc68773d1`.\n')
print('All six independent processes pass 70 cases and special-float bit checks; all hashes match across processes and compilers. Invalid-plane/empty checks pass for float, ubyte and POD. Each case has two warmups and nine timed calls per path, with cyclic order and full output/padding checks outside timing.\n')
print('Large (2048x512) baseline/candidate median ratios across three processes, including contiguous, padded, negative, repeated and overlapping Canonical rows:\n')
print('| Type | Compiler | Pointer speedup range | Slice speedup range | Max public / pointer / slice median spread |')
print('| --- | --- | --- | --- | --- |')
for typ in ['float','ubyte']:
    for compiler,runs in records.items():
        keys=[k for k in reference if k.startswith(f'type={typ} ') and 'w=2048 h=512' in k and k.split('layout=')[1] in ['contiguous','padded','negative-row','repeated-row','overlap-row','overlap-negative']]
        ratios=[[],[]]; spreads=[[],[],[]]
        for key in keys:
            for run in runs:
                median,_=run[key]
                for form in [1,2]: ratios[form-1].append(median[0]/median[form])
            for form in range(3):
                medians=[r[key][0][form] for r in runs]
                spreads[form].append((max(medians)/min(medians)-1)*100)
        fmt=lambda v:f'{min(v):.3f}–{max(v):.3f}x'
        print(f'| {typ} | {compiler} | {fmt(ratios[0])} | {fmt(ratios[1])} | '+ ' / '.join(f'{max(s):.2f}%' for s in spreads)+' |')
if args.environment=='container':
    print('\nContainer/VM timing is diagnostic evidence, not XPS or AArch64 qualification. Small workloads and Universal fallback have no tight timing threshold. Pointer versus slice selection and production admission require a separate review of stable reference-machine evidence.\n')
else:
    print('\nXPS timing is reference-machine evidence, not a portable timing promise or AArch64 qualification. Small workloads and Universal fallback have no tight timing threshold. Preserve process spread when reviewing source-form selection.\n')
print('Tiny cases can be below clock resolution: zero raw samples are retained and zero-median ratios are omitted. All large-case samples must be positive.\n')
print('## Per-case paired ratios\n')
print('| Case | Compiler | Pointer range | Slice range |')
print('| --- | --- | --- | --- |')
for key in reference:
    for compiler,runs in records.items():
        def paired(form):
            if any(r[key][0][form]==0 for r in runs): return 'below clock resolution'
            ratios=[r[key][0][0]/r[key][0][form] for r in runs]
            return f'{min(ratios):.3f}–{max(ratios):.3f}x'
        print(f'| {key} | {compiler} | {paired(1)} | {paired(2)} |')
