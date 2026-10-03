#!/usr/bin/env python3
"""Verify recursively retained files and lossless original collector identity."""
import gzip
import hashlib
from pathlib import Path
import sys

root=Path(sys.argv[1])
for manifest,raw in [('SHA256SUMS',False),('RAW-SHA256SUMS',True)]:
    entries={}; mapped=set()
    for line in (root/manifest).read_text().splitlines():
        digest,name=line.split('  ',1);relative=Path(name)
        if relative.is_absolute() or '..' in relative.parts or name in entries:
            raise RuntimeError('invalid manifest name')
        path=root/relative
        if raw and path.name=='SHA256SUMS' and (path.parent/'RAW-SHA256SUMS').exists():
            path=path.parent/'RAW-SHA256SUMS'
        if raw and not path.exists():
            path=Path(str(path)+'.gz'); content=gzip.decompress(path.read_bytes())
        else:content=path.read_bytes()
        if hashlib.sha256(content).hexdigest()!=digest:
            raise RuntimeError('checksum mismatch: '+name)
        entries[name]=digest;mapped.add(str(path.relative_to(root)))
    actual={str(p.relative_to(root)) for p in root.rglob('*') if p.is_file() and p!=root/'SHA256SUMS'}
    if raw:
        actual={n for n in actual if Path(n).name!='SHA256SUMS' and n!='RAW-SHA256SUMS'}
        if mapped!=actual:raise RuntimeError('unexpected or missing original file')
    elif set(entries)!=actual:raise RuntimeError('unexpected or missing retained file')
    print('PASS',manifest,len(entries))
