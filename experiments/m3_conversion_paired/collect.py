#!/usr/bin/env python3
"""Test a bounded pointer/count DMD row kernel with the qualified boundary harness."""
import gzip
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parent
INDEXED = ROOT.with_name('m3_conversion_indexed')
INDEXED_HASH = 'be0e77145fb726ad0a629f23d3d6920f38333016bbe29e39cbaf237c2ac2b9bc'
INDEXED_BODY = '1e12d663df492a5320df276f34039af51cd4c52b8cc9a5c63e9a23712473ec4d'
HYBRID_BODY = 'ead375777e4af6042cdce7bc46053d9e8adbc2c1858a157a1a10ded3ba9deed2'
OLD_LOOP = 'foreach (x, value; row)\n                destination[x] = cast(float)value;'
NEW_LOOP = '''if (width < 64)
            {
                foreach (x, value; row)
                    destination[x] = cast(float)value;
            }
            else
            {
                convertPairedPointerRow(row, destination);
            }'''
POINTER_HELPER = '''private void convertPairedPointerRow(
    scope const(ubyte)[] row, scope float[] destination)
    @trusted pure nothrow @nogc
{
    assert(row.length == destination.length);
    scope const(ubyte)* sourcePointer = row.ptr;
    scope float* destinationPointer = destination.ptr;
    foreach (i; 0 .. row.length)
        destinationPointer[i] = cast(float)sourcePointer[i];
}'''


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
    raise ValueError('function return not found: ' + symbol)


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

    def load_pointer():
        boundary = original_load()
        original_preserve = boundary.preserve_boundary
        original_control = boundary.linked_control
        helper_stats = {}

        def preserve(source):
            candidate = original_preserve(source)
            marker = 'static if (vectorEnabled) {\npragma(inline, false)\n'
            if candidate.count(marker) != 1:
                raise ValueError('DMD vector alternative marker changed')
            if candidate.count(POINTER_HELPER) != 0:
                raise ValueError('pointer helper already present')
            return candidate.replace(marker, 'static if (vectorEnabled) {\npragma(inline, false)\n' + POINTER_HELPER + '\n\npragma(inline, false)\n', 1)

        def control(assembly, position):
            result = original_control(assembly, position)
            if result['scalar_body_sha256'] in (INDEXED_BODY, HYBRID_BODY):
                raise ValueError('pointer loop produced unchanged prior scalar code')
            blocks = [b for b in re.split(r'(?=^[0-9a-f]+ <)', assembly, flags=re.M) if b]
            scalar = next(b for b in blocks if '<' + boundary.SCALAR + '>:' in b.splitlines()[0])
            calls = [line for line in scalar.splitlines() if 'call' in line and 'convertPairedPointerRow' in line]
            helper = [b for b in blocks if 'convertPairedPointerRow' in b.splitlines()[0]]
            expected = 'both'
            if '--compiler' in sys.argv:
                value = sys.argv[sys.argv.index('--compiler') + 1]
                expected = 'dmd' if value.startswith('dmd') else ('ldc2' if value.startswith('ldc') else value)
            if expected == 'ldc2' or (expected == 'both' and not calls and not helper):
                if calls or helper:
                    raise ValueError('portable compiler unexpectedly uses DMD pointer helper')
                return result
            if len(calls) != 1 or len(helper) != 1:
                raise ValueError('DMD pointer helper call or emitted helper missing')
            symbol = helper[0].splitlines()[0].split('<', 1)[1].split('>:', 1)[0]
            helper_stats[position] = scalar_body_digest(assembly, symbol)
            return result

        boundary.preserve_boundary = preserve
        boundary.linked_control = control
        replay = boundary.replay

        def replay_pointer(root):
            result = replay(root)
            metadata = json.loads((root / 'collection.json').read_text())
            digests = set()
            for item in metadata['cohorts']:
                if item['compiler'] == 'dmd':
                    for mode in boundary.MODES:
                        full = gzip.decompress((root / item['cohort'] / mode / 'full-linked-assembly.txt.gz').read_bytes()).decode()
                        blocks = [b for b in re.split(r'(?=^[0-9a-f]+ <)', full, flags=re.M) if b]
                        scalar = next(b for b in blocks if '<' + boundary.SCALAR + '>:' in b.splitlines()[0])
                        calls = [line for line in scalar.splitlines() if 'call' in line and 'convertPairedPointerRow' in line]
                        helper = [b for b in blocks if 'convertPairedPointerRow' in b.splitlines()[0]]
                        if len(calls) != 1 or len(helper) != 1:
                            raise ValueError('replay missing unique DMD pointer helper call')
                        symbol = helper[0].splitlines()[0].split('<', 1)[1].split('>:', 1)[0]
                        digests.add(scalar_body_digest(full, symbol))
            if any(item['compiler'] == 'dmd' for item in metadata['cohorts']) and len(digests) != 1:
                raise ValueError('pointer helper machine code differs across modes or positions')
            return result

        boundary.replay = replay_pointer
        return boundary

    indexed.load_boundary = load_pointer
    return indexed


def load_boundary():
    return load_indexed().load_boundary()


def main():
    indexed = load_indexed()
    root = Path(sys.argv[1]).resolve()
    if '--replay' in sys.argv:
        metadata = json.loads((root / 'collection.json').read_text())
        if metadata.get('indexed_adapter_inputs') != {'collect.py': INDEXED_HASH}:
            raise ValueError('pointer collection indexed provenance missing or changed')
    indexed.main()
    if '--replay' not in sys.argv:
        boundary = indexed.load_boundary()
        metadata = json.loads((root / 'collection.json').read_text())
        metadata['indexed_adapter_inputs'] = {'collect.py': INDEXED_HASH}
        metadata['scope'] = 'focused 72-workload sweep; DMD foreach below width 64, bounded pointer/count helper from 64'
        (root / 'collection.json').write_text(json.dumps(metadata, indent=2) + '\n')
        (root / 'SHA256SUMS').write_text(boundary.manifest(root))


if __name__ == '__main__':
    main()
