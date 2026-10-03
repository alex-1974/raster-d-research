#!/usr/bin/env python3
"""Deterministic process-median summary; never a timing pass/fail threshold."""
import csv
import io
import json
import statistics
from collections import defaultdict
from pathlib import Path
import sys


def summarize(root):
    expected=json.loads((root/'host.json').read_text())['processes']
    fingerprints={}
    out=io.StringIO()
    writer=csv.writer(out,lineterminator='\n')
    writer.writerow(['compiler','width','height','layout','form','processes',
                     'ns_per_call','process_spread_pct','original_over_form_median',
                     'original_over_form_min','original_over_form_max'])
    for compiler in ['dmd','ldc2']:
        files=sorted(root.glob(f'{compiler}-timing-*.tsv'))
        if not files:continue
        assert len(files)==expected
        samples=defaultdict(dict)
        for file in files:
            seen=set()
            for line in file.read_text().splitlines():
                tag,process,w,h,layout,round_,position,form,iterations,elapsed,hash_=line.split('\t')
                process,w,h,round_,position,form,iterations,elapsed=map(int,[process,w,h,round_,position,form,iterations,elapsed])
                assert tag=='TIME' and elapsed>0 and iterations>0
                assert 0<=process<expected and 0<=round_<9 and 0<=position<3
                assert form==(position+round_+process)%3
                key=(w,h,layout)
                assert fingerprints.setdefault(key,hash_)==hash_
                identity=(key,form,round_)
                assert identity not in seen
                seen.add(identity)
                samples[(key,form)].setdefault(process,[]).append(elapsed/iterations)
            assert len(seen)==486
        assert len(samples)==54
        medians={}
        for key,by_process in samples.items():
            assert len(by_process)==expected and all(len(v)==9 for v in by_process.values())
            medians[key]={p:statistics.median(v) for p,v in by_process.items()}
        for (key,form),by_process in sorted(medians.items()):
            values=list(by_process.values());median=statistics.median(values)
            ratios=[medians[(key,0)][p]/v for p,v in by_process.items()]
            writer.writerow([compiler,*key,['original','pointer','pointer32'][form],expected,
                             f'{median:.3f}',f'{100*(max(values)-min(values))/median:.3f}',
                             f'{statistics.median(ratios):.6f}',f'{min(ratios):.6f}',f'{max(ratios):.6f}'])
    assert len(fingerprints)==18
    return out.getvalue()

if __name__=='__main__':
    print(summarize(Path(sys.argv[1])),end='')
