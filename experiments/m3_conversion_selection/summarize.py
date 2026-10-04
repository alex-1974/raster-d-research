#!/usr/bin/env python3
"""Deterministic process-median summary; never a timing pass/fail threshold."""
import gzip
import csv
import io
import json
import statistics
from collections import defaultdict
from pathlib import Path
import sys


def summarize(root):
    if not __debug__:
        raise RuntimeError("replay requires Python assertions")
    matrix={tuple(v) for v in json.loads((root/'matrix.json').read_text())}
    profile=json.loads((root/'profile.json').read_text())
    forms=profile['forms']; count=len(forms)
    expected=json.loads((root/'host.json').read_text())['processes']
    fingerprints={}
    out=io.StringIO()
    writer=csv.writer(out,lineterminator='\n')
    writer.writerow(['compiler','width','height','layout','form','processes',
                     'ns_per_call','process_spread_pct','original_over_form_median',
                     'original_over_form_min','original_over_form_max',
                     'form_over_cpp_median','form_over_cpp_min','form_over_cpp_max',
                     'unconditional_over_form_median','unconditional_over_form_min','unconditional_over_form_max'])
    for compiler in profile['compilers']:
        files=sorted([*root.glob(f'{compiler}-timing-*.tsv'),*root.glob(f'{compiler}-timing-*.tsv.gz')])
        assert files, "missing compiler family"
        assert len(files)==expected
        samples=defaultdict(dict)
        for file in files:
            seen=set()
            raw=gzip.decompress(file.read_bytes()).decode() if file.suffix=='.gz' else file.read_text()
            for line in raw.splitlines():
                tag,process,w,h,layout,round_,position,form,iterations,elapsed,hash_=line.split('\t')
                process,w,h,round_,position,form,iterations,elapsed=map(int,[process,w,h,round_,position,form,iterations,elapsed])
                assert file.name.removesuffix('.gz')==f'{compiler}-timing-{process}.tsv'
                assert tag=='TIME' and elapsed>0 and iterations==max(8,min(4096,profile['samples_per_block']//(w*h)))
                assert 0<=process<expected and 0<=round_<9 and 0<=position<count
                assert form==(position+round_+process)%count
                key=(w,h,layout)
                assert fingerprints.setdefault(key,hash_)==hash_
                identity=(key,form,round_)
                assert identity not in seen
                seen.add(identity)
                samples[(key,form)].setdefault(process,[]).append(elapsed/iterations)
            assert {identity[0] for identity in seen}==matrix
            assert len(seen)==len(matrix)*count*9
        assert len(samples)==len(matrix)*count
        medians={}
        for key,by_process in samples.items():
            assert len(by_process)==expected and all(len(v)==9 for v in by_process.values())
            medians[key]={p:statistics.median(v) for p,v in by_process.items()}
        for (key,form),by_process in sorted(medians.items()):
            values=list(by_process.values());median=statistics.median(values)
            ratios=[medians[(key,0)][p]/v for p,v in by_process.items()]
            cpp_ratios=[v/medians[(key,3)][p] for p,v in by_process.items()] if count==4 else []
            selected_ratios=[medians[(key,2)][p]/v for p,v in by_process.items()]
            writer.writerow([compiler,*key,forms[form],expected,
                             f'{median:.3f}',f'{100*(max(values)-min(values))/median:.3f}',
                             f'{statistics.median(ratios):.6f}',f'{min(ratios):.6f}',f'{max(ratios):.6f}',*( [f'{statistics.median(cpp_ratios):.6f}',f'{min(cpp_ratios):.6f}',f'{max(cpp_ratios):.6f}'] if cpp_ratios else ['','','']),
                             f'{statistics.median(selected_ratios):.6f}',f'{min(selected_ratios):.6f}',f'{max(selected_ratios):.6f}'])
    assert set(fingerprints)==matrix
    return out.getvalue()

if __name__=='__main__':
    print(summarize(Path(sys.argv[1])),end='')
