#!/usr/bin/env python3
"""Verify retained gzip encoding and byte-exact original collector files."""
import gzip
import hashlib
from pathlib import Path
import sys

root=Path(sys.argv[1])
for manifest,raw in [('SHA256SUMS',False),('RAW-SHA256SUMS',True)]:
    entries={}
    for line in (root/manifest).read_text().splitlines():
        digest,name=line.split('  ',1)
        if name!=Path(name).name or name in entries:
            raise RuntimeError('invalid manifest name')
        path=root/name
        content=gzip.decompress((root/(name+'.gz')).read_bytes()) if raw and not path.exists() else path.read_bytes()
        if hashlib.sha256(content).hexdigest()!=digest:
            raise RuntimeError('checksum mismatch: '+name)
        entries[name]=digest
    if not raw and set(entries)!={p.name for p in root.iterdir() if p.is_file() and p.name!='SHA256SUMS'}:
        raise RuntimeError('unexpected or missing retained file')
    if raw and {name+'.gz' if not (root/name).exists() else name for name in entries}!={p.name for p in root.iterdir() if p.is_file() and p.name not in {'SHA256SUMS','RAW-SHA256SUMS'}}:
        raise RuntimeError('unexpected or missing original file')
    print('PASS',manifest,len(entries))
