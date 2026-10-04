#!/usr/bin/env python3
"""Qualify a DMD scalar boundary and four linker-controlled placements."""
import argparse
import csv
import gzip
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent
PARENT = ROOT.with_name('m3_conversion_selection')
MODES = ('prior-short', 'prior-long', 'sweep-short', 'sweep-long')
SCALAR = '_D6raster27variant_selected64_dispatch__T19executeApprovedRowsThTfZQBaFNaNbNiNfMPxhlMPflmmZv'


def load_parent():
    # Existing compiler/public/trust/oracle gates are reused unchanged.
    sys.path.insert(0, str(PARENT))
    spec = importlib.util.spec_from_file_location('selection_audit', PARENT / 'audit.py')
    audit = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(audit)
    return audit


def preserve_boundary(source):
    marker = 'private void executeApprovedRows(S, D)('
    if source.count(marker) != 1:
        raise ValueError('scalar template marker changed')
    start = source.index(marker)
    opening = source.index('{', start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    declaration = source[start:end]
    replacement = ('static if (vectorEnabled) {\npragma(inline, false)\n'
                   + declaration + '\n} else {\n' + declaration + '\n}')
    return source[:start] + replacement + source[end:]


def linker_script(position, symbol=SCALAR):
    # One fixed-size page keeps subsequent .text placement independent of the
    # requested offset. SUBALIGN affects instruction bytes only, not data.
    if position not in (0, 8, 16, 24):
        raise ValueError('invalid position')
    return ('SECTIONS {\n .m3_scalar_hot ALIGN(4096) : SUBALIGN(1) {\n'
            f'  . += {position};\n  KEEP(*(.text.{symbol}))\n'
            '  . = ALIGN(4096);\n }\n}\nINSERT BEFORE .text;\n')


def linked_control(assembly, position):
    blocks = [b for b in re.split(r'(?=^[0-9a-f]+ <)', assembly, flags=re.M) if b]
    matches = [b for b in blocks if f'<{SCALAR}>:' in b.splitlines()[0]]
    if len(matches) != 1:
        raise ValueError('missing/ambiguous scalar boundary')
    address = int(matches[0].split()[0], 16)
    if position != 'native' and address % 32 != int(position):
        raise ValueError(('linker did not implement requested position', address, position))
    callers = {}
    for name in ('convertUbyteToFloatRasterPlane', 'convertApprovedUbyteToFloatAffine2D'):
        functions = [b for b in blocks if name in b.splitlines()[0]
                     and 'variant_selected64_dispatch' in b.splitlines()[0]]
        if len(functions) != 1:
            raise ValueError('missing approved caller: ' + name)
        calls = [line.strip() for line in functions[0].splitlines()
                 if 'call' in line and f'<{SCALAR}>' in line]
        if len(calls) != 1:
            raise ValueError('scalar boundary not preserved at ' + name)
        callers[name] = {'entry': functions[0].split()[0], 'scalar_calls': calls}
    page = address // 4096 * 4096
    text_entries = {b.splitlines()[0].split('<', 1)[1].split('>:', 1)[0]: b.split()[0]
                    for b in blocks if b.splitlines()[0].endswith('>:')
                    and not page <= int(b.split()[0], 16) < page + 4096}
    return {'requested_position': position, 'scalar_entry': hex(address),
            'scalar_entry_mod32': address % 32, 'callers': callers,
            'other_function_entries': text_entries}


def collect_mode(audit, overlay, output, compiler, position, mode, processes):
    original_generate = audit.generate
    original_run = audit.run
    original_root = audit.ROOT
    profile, block = mode.split('-')

    def generate(directory, sources, selected_profile, selected_block):
        # Both sweep block lengths deliberately use the focused 72-workload
        # matrix: 63/64/65 at three heights and the eighteen prior anchors.
        original_generate(directory, sources, selected_profile,
                          'long' if selected_profile == 'sweep' else selected_block)
        if selected_profile == 'sweep' and selected_block == 'short':
            path = directory / 'timing.d'
            path.write_text(path.read_text().replace('8388608UL', '262144UL'))
        path = directory / 'raster/variant_selected64_dispatch.d'
        path.write_text(preserve_boundary(path.read_text()))

    def run(command, log, cwd=None, succeeds=True):
        actual = list(command)
        timing_build = log.name == 'dmd-timing-build.txt'
        if timing_build and position != 'native':
            script = log.parent / 'placement.ld'
            script.write_text(linker_script(int(position)))
            actual.insert(1, '-L-T' + str(script))
        if timing_build:
            (log.parent / 'actual-timing-link-command.json').write_text(json.dumps(actual, indent=2) + '\n')
        result = original_run(actual, log, cwd, succeeds)
        if timing_build:
            binary = Path(next(arg[4:] for arg in actual if arg.startswith('-of=')))
            assembly = subprocess.check_output(['objdump', '-dr', str(binary)], text=True)
            control = linked_control(assembly, position)
            control['binary_sha256'] = hashlib.sha256(binary.read_bytes()).hexdigest()
            control['full_assembly_sha256'] = hashlib.sha256(assembly.encode()).hexdigest()
            (log.parent / 'placement.json').write_text(json.dumps(control, indent=2, sort_keys=True) + '\n')
            # Retain the complete consumer and original wrappers as well as
            # every dispatcher/kernel; the parent excerpt omitted publicCall.
            (log.parent / 'full-linked-assembly.txt.gz').write_bytes(
                gzip.compress(assembly.encode(), compresslevel=9, mtime=0))
        return result

    audit.generate, audit.run, audit.ROOT = generate, run, overlay
    old_argv = sys.argv
    sys.argv = ['audit.py', str(output), '--profile', profile, '--block', block,
                '--compiler', compiler, '--processes', str(processes)]
    try:
        audit.main()
    finally:
        audit.generate, audit.run, audit.ROOT, sys.argv = original_generate, original_run, original_root, old_argv


def manifest(root):
    return ''.join(hashlib.sha256(p.read_bytes()).hexdigest() + '  '
                   + str(p.relative_to(root)) + '\n'
                   for p in sorted(root.rglob('*')) if p.is_file() and p != root / 'SHA256SUMS')


def replay(root):
    metadata = json.loads((root / 'collection.json').read_text())
    declared = ([{'cohort': 'dmd-' + p, 'compiler': 'dmd', 'position': p}
                 for p in metadata['positions']] if metadata['compiler'] != 'ldc2' else [])
    if metadata['compiler'] != 'dmd':
        declared += [{'cohort': 'ldc2-native', 'compiler': 'ldc2', 'position': 'native'}]
    if metadata['cohorts'] != declared or not 1 <= metadata['processes'] <= 6:
        raise ValueError('missing or unexpected cohort')
    audit = load_parent()
    result = io.StringIO()
    writer = csv.writer(result, lineterminator='\n')
    fingerprints = {}
    entries = {}
    generated = {}
    for index, item in enumerate(metadata['cohorts']):
        cohort = item['cohort']
        for mode in MODES:
            child = root / cohort / mode
            profile = json.loads((child / 'profile.json').read_text())
            if profile['compilers'] != [item['compiler']] or profile['profile'] + '-' + profile['block'] != mode:
                raise ValueError('compiler/mode identity mismatch')
            if json.loads((child / 'host.json').read_text())['processes'] != metadata['processes']:
                raise ValueError('process cohort mismatch')
            expected_forms = ['original', 'selected64', 'vector16store'] + (['cpp-approved-execution'] if mode.startswith('sweep') else [])
            if profile['forms'] != expected_forms or profile['samples_per_block'] != (262144 if mode.endswith('short') else 8388608):
                raise ValueError('forms or block budget changed')
            source_map = json.loads((child / 'generated.json').read_text())
            if generated.setdefault(mode, source_map) != source_map:
                raise ValueError('generated inputs changed between cohorts')
            summary = audit.summarize(child)
            if summary != (child / 'summary.csv').read_text():
                raise ValueError('child replay mismatch')
            rows = list(csv.reader(io.StringIO(summary)))
            if index == 0 and mode == MODES[0]:
                writer.writerow(['cohort', 'mode', *rows[0]])
            for row in rows[1:]:
                writer.writerow([cohort, mode, *row])
            for path in child.glob('*-timing-*.tsv'):
                for line in path.read_text().splitlines():
                    fields = line.split('\t')
                    key = tuple(fields[2:5])
                    if fingerprints.setdefault(key, fields[-1]) != fields[-1]:
                        raise ValueError('cross-cohort backing fingerprint changed')
            if item['compiler'] == 'dmd':
                placement = json.loads((child / 'placement.json').read_text())
                full = gzip.decompress((child / 'full-linked-assembly.txt.gz').read_bytes()).decode()
                regenerated = linked_control(full, item['position'])
                if any(placement[key] != value for key, value in regenerated.items()):
                    raise ValueError('linked control replay mismatch')
                if hashlib.sha256(full.encode()).hexdigest() != placement['full_assembly_sha256']:
                    raise ValueError('full linked assembly identity changed')
                if item['position'] != 'native':
                    if placement['scalar_entry_mod32'] != int(item['position']):
                        raise ValueError('position mismatch')
                    # Other linked function addresses must remain fixed across
                    # the four controlled replicas within this consumer mode.
                    current = placement['other_function_entries']
                    if entries.setdefault(mode, current) != current:
                        raise ValueError('uncontrolled function-placement change: ' + mode)
    if len(fingerprints) != 72:
        raise ValueError('focused matrix incomplete')
    return result.getvalue()


def main():
    if not __debug__:
        raise RuntimeError('qualification requires Python assertions')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    parser.add_argument('--compiler', choices=['dmd', 'ldc2', 'both'], default='both')
    parser.add_argument('--positions', default='native,0,8,16,24')
    parser.add_argument('--processes', type=int, default=6)
    parser.add_argument('--replay', action='store_true')
    args = parser.parse_args()
    if args.replay:
        print(replay(args.output), end='')
        return
    positions = args.positions.split(',')
    if len(set(positions)) != len(positions) or not set(positions) <= {'native', '0', '8', '16', '24'}:
        raise ValueError('invalid position cohort')
    if not 1 <= args.processes <= 6:
        raise ValueError('invalid process count')
    families = ['dmd', 'ldc2'] if args.compiler == 'both' else [args.compiler]
    for family in families:
        version = subprocess.check_output([family, '--version'], text=True)
        if family == 'dmd' and 'v2.111.0' not in version:
            raise ValueError('required DMD 2.111.0')
        if family == 'ldc2' and ('compiler (1.41.0)' not in version or 'DMD v2.111.0' not in version):
            raise ValueError('required LDC 1.41.0/frontend 2.111.0')
    if 'DUB version 1.40.0,' not in subprocess.check_output(['dub', '--version'], text=True):
        raise ValueError('required DUB 1.40.0')
    root = args.output.resolve()
    root.mkdir(parents=True, exist_ok=False)
    audit = load_parent()
    parent_hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in PARENT.iterdir()
                     if p.is_file() and p.suffix in {'.py', '.d', '.cpp', '.json'}}
    qualified = json.loads((PARENT / 'evidence/2026-10-03-container/collection.json').read_text())['inputs']
    if parent_hashes != qualified:
        raise ValueError('qualified parent sources changed')
    cohorts = [{'cohort': 'dmd-' + p, 'compiler': 'dmd', 'position': p}
               for p in positions] if args.compiler != 'ldc2' else []
    if args.compiler != 'dmd':
        cohorts += [{'cohort': 'ldc2-native', 'compiler': 'ldc2', 'position': 'native'}]
    with tempfile.TemporaryDirectory(prefix='raster-boundary-overlay-') as temp:
        overlay = Path(temp)
        for name in parent_hashes:
            shutil.copyfile(PARENT / name, overlay / name)
        matrix = json.loads((overlay / 'matrices.json').read_text())
        matrix['sweep-short'] = matrix['sweep-long']
        (overlay / 'matrices.json').write_text(json.dumps(matrix, indent=2) + '\n')
        for item in cohorts:
            for mode in MODES:
                print('QUALIFY', item['cohort'], mode, flush=True)
                collect_mode(audit, overlay, root / item['cohort'] / mode,
                             item['compiler'], item['position'], mode, args.processes)
    if parent_hashes != {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in PARENT.iterdir()
                        if p.is_file() and p.suffix in {'.py', '.d', '.cpp', '.json'}}:
        raise ValueError('parent experiment changed during collection')
    (root / 'collection.json').write_text(json.dumps({
        'cohorts': cohorts, 'compiler': args.compiler, 'positions': positions,
        'processes': args.processes, 'parent_inputs': parent_hashes,
        'driver_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'scope': 'focused 72-workload sweep; public selection with DMD scalar boundary',
    }, indent=2) + '\n')
    (root / 'summary.csv').write_text(replay(root))
    (root / 'SHA256SUMS').write_text(manifest(root))
    print('PASS all declared boundary/position cohorts; no timing acceptance threshold', flush=True)


if __name__ == '__main__':
    main()
