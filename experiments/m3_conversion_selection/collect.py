#!/usr/bin/env python3
"""Qualify separate consumer/block binaries and retain all four raw audits."""
import argparse
import csv
import gzip
import hashlib
import io
import json
from pathlib import Path
import subprocess
import sys
from summarize import summarize

ROOT=Path(__file__).resolve().parent
MODES=['prior-short','prior-long','sweep-short','sweep-long']


def replay(root):
    out=io.StringIO(); writer=csv.writer(out,lineterminator='\n')
    fingerprints={}
    for index,mode in enumerate(MODES):
        child=root/mode
        profile=json.loads((child/'profile.json').read_text())
        assert profile['profile']+'-'+profile['block']==mode
        result=summarize(child)
        assert result==(child/'summary.csv').read_text()
        rows=list(csv.reader(io.StringIO(result)))
        if index==0:writer.writerow(['consumer','block',*rows[0]])
        for row in rows[1:]:writer.writerow([profile['profile'],profile['block'],*row])
        for file in child.glob('*-timing-*.tsv*'):
            data=gzip.decompress(file.read_bytes()).decode() if file.suffix=='.gz' else file.read_text()
            for line in data.splitlines():
                fields=line.split('\t');key=tuple(fields[2:5])
                assert fingerprints.setdefault(key,fields[-1])==fields[-1]
    assert len(fingerprints)==438
    return out.getvalue()


def main():
    if not __debug__:raise RuntimeError('qualification requires Python assertions')
    parser=argparse.ArgumentParser()
    parser.add_argument('output',type=Path)
    parser.add_argument('--compiler',choices=['dmd','ldc2','both'],default='both')
    parser.add_argument('--processes',type=int,default=6)
    parser.add_argument('--replay',action='store_true')
    args=parser.parse_args();root=args.output.resolve()
    if args.replay:
        print(replay(root),end='');return
    assert 1<=args.processes<=6
    root.mkdir(parents=True,exist_ok=False)
    inputs={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in ROOT.iterdir() if p.suffix in {'.py','.d','.cpp','.json'}}
    for mode in MODES:
        profile,block=mode.split('-')
        print('QUALIFY',mode,flush=True)
        command=[sys.executable,'-u',str(ROOT/'audit.py'),str(root/mode),'--profile',profile,'--block',block,'--compiler',args.compiler,'--processes',str(args.processes)]
        result=subprocess.run(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
        (root/(mode+'-run.txt')).write_bytes(result.stdout)
        if result.returncode:raise RuntimeError((mode,result.returncode,root/(mode+'-run.txt')))
        print(result.stdout.decode(),end='',flush=True)
    assert inputs=={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in ROOT.iterdir() if p.suffix in {'.py','.d','.cpp','.json'}}, 'inputs changed between modes'
    (root/'collection.json').write_text(json.dumps(dict(modes=MODES,processes=args.processes,compiler=args.compiler,inputs=inputs),indent=2)+'\n')
    (root/'summary.csv').write_text(replay(root))
    (root/'SHA256SUMS').write_text(''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+str(p.relative_to(root))+'\n' for p in sorted(root.rglob('*')) if p.is_file() and p!=root/'SHA256SUMS'))
    print('PASS four independently compiled consumer/block audits',flush=True)


if __name__=='__main__':main()
