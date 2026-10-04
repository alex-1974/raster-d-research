#!/usr/bin/env python3
"""Test a counted scalar row loop with the qualified boundary/placement harness."""
import gzip
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parent
BOUNDARY = ROOT.with_name('m3_conversion_boundary')
BOUNDARY_HASH = 'b540e5c32fe36485062bf2d04f84f8f35eaefff0ff465e30ad05431dccfa26a1'
OLD_BODY = '24a5864323554d66c835571f9e775c2e6cef13d2986e370f422f7925cb5fa867'
OLD_LOOP = 'foreach (x, value; row)\n                destination[x] = cast(float)value;'
NEW_LOOP = 'foreach (x; 0 .. row.length)\n                destination[x] = cast(float)row[x];'


def scalar_body_digest(assembly, symbol):
    blocks = [b for b in re.split(r'(?=^[0-9a-f]+ <)', assembly, flags=re.M) if b]
    block = next(b for b in blocks if f'<{symbol}>:' in b.splitlines()[0])
    chunks = []
    for line in block.splitlines()[1:]:
        match = re.match(r'\s*[0-9a-f]+:\s*((?:[0-9a-f]{2} )+)\s*(.+)', line)
        if match:
            chunks.append(bytes.fromhex(match[1]))
            if match[2].strip() == 'ret':
                return hashlib.sha256(b''.join(chunks)).hexdigest()
    raise ValueError('scalar return not found')


def load_boundary():
    path = BOUNDARY / 'collect.py'
    if hashlib.sha256(path.read_bytes()).hexdigest() != BOUNDARY_HASH:
        raise ValueError('qualified boundary harness changed')
    spec = importlib.util.spec_from_file_location('qualified_boundary', path)
    boundary = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(boundary)
    preserve = boundary.preserve_boundary
    linked = boundary.linked_control
    replay = boundary.replay

    def adapt(source):
        wrapped = preserve(source)
        if wrapped.count(OLD_LOOP) != 2:
            raise ValueError('scalar source marker changed')
        # The first copy belongs to vectorEnabled's DMD branch. The else
        # declaration remains byte-identical for LDC/forced portable targets.
        candidate = wrapped.replace(OLD_LOOP, NEW_LOOP, 1)
        if candidate.count(NEW_LOOP) != 1 or candidate.count(OLD_LOOP) != 1:
            raise ValueError('compiler alternative changed')
        return candidate

    def control(assembly, position):
        result = linked(assembly, position)
        digest = scalar_body_digest(assembly, boundary.SCALAR)
        if digest == OLD_BODY:
            raise ValueError('counted source loop produced unchanged scalar code')
        result['scalar_body_sha256'] = digest
        return result

    def replay_indexed(root):
        result = replay(root)
        metadata = json.loads((root / 'collection.json').read_text())
        digests = set()
        for item in metadata['cohorts']:
            if item['compiler'] == 'dmd':
                for mode in boundary.MODES:
                    full = gzip.decompress((root / item['cohort'] / mode / 'full-linked-assembly.txt.gz').read_bytes()).decode()
                    digests.add(scalar_body_digest(full, boundary.SCALAR))
        if len(digests) > 1:
            raise ValueError('scalar code differs across modes or positions')
        return result

    boundary.ROOT = ROOT
    boundary.preserve_boundary = adapt
    boundary.linked_control = control
    boundary.replay = replay_indexed
    return boundary


def main():
    boundary = load_boundary()
    if '--replay' in sys.argv:
        metadata = json.loads((Path(sys.argv[1]) / 'collection.json').read_text())
        if metadata.get('boundary_inputs') != {'collect.py': BOUNDARY_HASH}:
            raise ValueError('indexed collection boundary provenance missing or changed')
    boundary.main()
    if '--replay' not in sys.argv:
        root = Path(sys.argv[1]).resolve()
        metadata = json.loads((root / 'collection.json').read_text())
        metadata['boundary_inputs'] = {'collect.py': BOUNDARY_HASH}
        metadata['scope'] = 'focused 72-workload sweep; DMD counted scalar loop with preserved boundary'
        (root / 'collection.json').write_text(json.dumps(metadata, indent=2) + '\n')
        (root / 'SHA256SUMS').write_text(boundary.manifest(root))


if __name__ == '__main__':
    main()
