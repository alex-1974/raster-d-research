#!/usr/bin/env python3
"""Test safe joint iteration of remaining source and destination row slices."""
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent
INDEXED = ROOT.with_name('m3_conversion_indexed')
BOUNDARY = ROOT.with_name('m3_conversion_boundary')
INDEXED_HASH = 'be0e77145fb726ad0a629f23d3d6920f38333016bbe29e39cbaf237c2ac2b9bc'
INDEXED_BODY = '1e12d663df492a5320df276f34039af51cd4c52b8cc9a5c63e9a23712473ec4d'
OLD_LOOP = 'foreach (x, value; row)\n                destination[x] = cast(float)value;'
NEW_LOOP = '''scope auto remainingSource = row;
            scope auto remainingDestination = destination;
            while (remainingSource.length != 0 && remainingDestination.length != 0)
            {
                remainingDestination[0] = cast(float)remainingSource[0];
                remainingSource = remainingSource[1 .. $];
                remainingDestination = remainingDestination[1 .. $];
            }'''


def load_indexed():
    path = INDEXED / 'collect.py'
    if hashlib.sha256(path.read_bytes()).hexdigest() != INDEXED_HASH:
        raise ValueError('qualified indexed adapter changed')
    spec = importlib.util.spec_from_file_location('qualified_indexed', path)
    indexed = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(indexed)
    indexed.ROOT = ROOT
    indexed.NEW_LOOP = NEW_LOOP
    original_load = indexed.load_boundary

    def load_paired():
        boundary = original_load()
        original_control = boundary.linked_control

        def control(assembly, position):
            result = original_control(assembly, position)
            if result['scalar_body_sha256'] == INDEXED_BODY:
                raise ValueError('paired slices produced unchanged indexed scalar code')
            return result

        boundary.linked_control = control
        return boundary

    indexed.load_boundary = load_paired
    return indexed


def load_boundary():
    return load_indexed().load_boundary()


def main():
    indexed = load_indexed()
    root = Path(sys.argv[1]).resolve()
    if '--replay' in sys.argv:
        metadata = json.loads((root / 'collection.json').read_text())
        if metadata.get('indexed_adapter_inputs') != {'collect.py': INDEXED_HASH}:
            raise ValueError('paired collection indexed provenance missing or changed')
    indexed.main()
    if '--replay' not in sys.argv:
        boundary = indexed.load_boundary()
        metadata = json.loads((root / 'collection.json').read_text())
        metadata['indexed_adapter_inputs'] = {'collect.py': INDEXED_HASH}
        metadata['scope'] = 'focused 72-workload sweep; DMD paired remaining slices with preserved boundary'
        (root / 'collection.json').write_text(json.dumps(metadata, indent=2) + '\n')
        (root / 'SHA256SUMS').write_text(boundary.manifest(root))


if __name__ == '__main__':
    main()
