#!/usr/bin/env python3
"""Check exact semantics/hashes/counts before reporting paired median ratios."""
import argparse,ast,re,statistics
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('directory',type=Path)
p.add_argument('--environment',choices=['container','xps'],default='container')
a=p.parse_args();records={}
forms=['public','pointer','slice','cpp']
for compiler in ['dmd','ldc']:
    records[compiler]=[]
    for run in range(1,4):
        text=(a.directory/f'{compiler}-run-{run}.txt').read_text()
        assert 'contracts PASS invalid/empty/out-zero/cancellation' in text
        assert 'semantic PASS cases=56' in text
        assert 'm3_strict_reduction PASS cases=42' in text
        cases={}
        for line in text.splitlines():
            if not line.startswith('case '):continue
            key=line[5:line.index(' public_raw=')]; medians=[]
            for form in forms:
                raw=ast.literal_eval(re.search(form+r'_raw=(\[[^]]+\])',line)[1])
                assert len(raw)==12 and all(v>=0 for v in raw)
                if 'w=2048 h=512' in key: assert all(v>0 for v in raw)
                median=int(re.search(form+r'_ns=(\d+)',line)[1])
                assert median==int(statistics.median(raw))
                medians.append(median)
            result=re.search(r'result=([0-9a-f]+)',line)[1]
            fingerprint=re.search(r'hash=([0-9a-f]+)',line)[1]
            assert key not in cases;cases[key]=(medians,result,fingerprint)
        assert len(cases)==42;records[compiler].append(cases)
reference=records['dmd'][0]
for runs in records.values():
    for cases in runs:
        assert cases.keys()==reference.keys()
        assert all(cases[k][1:]==reference[k][1:] for k in reference),'result/source mismatch'
print(f'# Strict row-major reduction — {a.environment} evidence\n')
print('Production baseline: `1671fb2e51a7b1e7311f78f575d9457e9f279fd4`.\n')
print('All six processes pass 42 timed cases, 56 semantic cases and invalid/empty/out-zero/cancellation contracts. All finite result bits and source fingerprints match. NaN semantics require class equality, not a platform-independent payload. Twelve rounds rotate four paths through every ordering position three times; each call is checked outside timing.\n')
print('C++ is an already-validated descriptor execution reference with plane failure/empty semantics; it avoids Mir/layout classification and adds an external C ABI call. Both differences are explicit; it is not evidence of a complete independent raster library. No fast-math, contraction or LTO is enabled.\n')
print('Large Canonical cases, contiguous/padded/negative/repeated rows, both corpora:\n')
print('| Compiler | Public/Pointer | Public/Slice | Public/C++ reference | Max public/pointer/slice/C++ spread |')
print('| --- | --- | --- | --- | --- |')
for compiler,runs in records.items():
    keys=[k for k in reference if 'w=2048 h=512' in k and k.split('layout=')[1].split()[0] in ['contiguous','padded','negative-row','repeated-row']]
    ratios=[[],[],[]];spreads=[[],[],[],[]]
    for key in keys:
        for run in runs:
            medians=run[key][0]
            for f in range(1,4):ratios[f-1].append(medians[0]/medians[f])
        for f in range(4):
            vals=[run[key][0][f] for run in runs]
            spreads[f].append((max(vals)/min(vals)-1)*100)
    fmt=lambda vals:f'{min(vals):.3f}–{max(vals):.3f}x'
    print('| '+compiler+' | '+' | '.join(fmt(v) for v in ratios)+' | '+' / '.join(f'{max(v):.2f}%' for v in spreads)+' |')
print('\nTimings do not justify reassociation or fixed-lane substitution. Container results are diagnostic; production selection requires XPS qualification. AArch64 is unqualified. Tiny zero-duration samples are retained and zero-median ratios omitted.\n')
print('| Case | Compiler | Public/Pointer | Public/Slice | Public/C++ |')
print('| --- | --- | --- | --- | --- |')
for key in reference:
    for compiler,runs in records.items():
        def ratio(f):
            if any(r[key][0][f]==0 for r in runs):return 'below clock resolution'
            vals=[r[key][0][0]/r[key][0][f] for r in runs]
            return f'{min(vals):.3f}–{max(vals):.3f}x'
        print('| '+key+' | '+compiler+' | '+' | '.join(ratio(f) for f in range(1,4))+' |')
