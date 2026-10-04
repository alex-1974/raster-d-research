#!/usr/bin/env python3
"""Check indexed source isolation and reuse the qualified linker smoke checks."""
import gzip
import hashlib
import importlib.util
import sys
import tempfile
from pathlib import Path
from collect import BOUNDARY, NEW_LOOP, OLD_LOOP, load_boundary


def main():
    boundary = load_boundary()
    sys.modules['collect'] = boundary
    spec = importlib.util.spec_from_file_location('boundary_setup', BOUNDARY / 'check_setup.py')
    setup = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(setup)
    setup.main()
    audit = boundary.load_parent()
    sources = {name: (audit.PRODUCTION / name).read_text() for name in audit.PINS}
    with tempfile.TemporaryDirectory(prefix='raster-indexed-source-') as temp:
        root = Path(temp)
        audit.generate(root, sources, 'prior', 'short')
        source = (root / 'raster/variant_selected64_dispatch.d').read_text()
        after = boundary.preserve_boundary(source)
        assert after.count(NEW_LOOP) == 1 and after.count(OLD_LOOP) == 1
        start = source.index('private void executeApprovedRows(S, D)(')
        opening = source.index('{', start)
        depth, end = 1, opening + 1
        while depth:
            depth += (source[end] == '{') - (source[end] == '}')
            end += 1
        declaration = source[start:end]
        assert ('} else {\n' + declaration + '\n}') in after
        assert after.count('@trusted') == source.count('@trusted')
    # A previously qualified unchanged scalar body must fail the new code gate.
    evidence = boundary.PARENT / 'evidence/2026-10-04-xps/prior-short/dmd-linked-assembly.txt.gz'
    full = gzip.decompress(evidence.read_bytes()).decode()
    try:
        boundary.linked_control(full, 'native')
    except ValueError:
        pass
    else:
        raise ValueError('old inlined candidate accepted')
    old = (Path(__file__).resolve().parent / 'old-boundary-negative.txt').read_text()
    try:
        boundary.linked_control(old, 'native')
    except ValueError as error:
        if 'unchanged scalar code' not in str(error):
            raise
    else:
        raise ValueError('old preserved scalar machine code accepted')
    print('PASS unchanged preserved scalar machine code rejected')
    print('PASS one DMD counted loop; exact inactive declaration; unchanged trust; inherited linker controls')


if __name__ == '__main__':
    main()
